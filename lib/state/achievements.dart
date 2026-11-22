import 'package:flutter/foundation.dart';

import '../data/build_flavor.dart';
import '../data/courses.dart' show allCourses;
import '../logic/unlocks.dart';
import '../models/puzzle.dart';
import 'progress_store.dart';

/// How far a badge series has come. Bronze to gold are the series steps,
/// platinum is the one badge for everything, rainbow is private (PAP-27).
enum BadgeTier { bronze, silver, gold, platinum, rainbow }

/// Progress toward a badge, for the badge screen (PAP-48). [current] never passes [target].
class BadgeProgress {
  BadgeProgress(int current, this.target) : current = current > target ? target : current;

  final int current;
  final int target;
}

/// A badge earned by playing.
class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.isEarned, {
    this.tier = BadgeTier.bronze,
    String? mochiTitle,
    this.series,
    this.progress,
    this.unit,
    this.retired = false,
  }) : _mochiTitle = mochiTitle;

  final String id;
  final String title;
  final String description;
  final bool Function(ProgressFacts f) isEarned;
  final BadgeTier tier;

  /// The title Mochi gives while this is the highest badge of its series. Defaults to [title].
  final String? _mochiTitle;
  String get mochiTitle => _mochiTitle ?? title;

  /// Whether this badge has its own nameplate title (at most 14 letters).
  bool get givesTitle => _mochiTitle != null;

  /// Series this badge is a step of, or null for a single badge.
  final String? series;

  /// Progress toward the badge, or null when there is nothing to count.
  final BadgeProgress? Function(ProgressFacts f)? progress;

  /// What [progress] counts, for short captions such as "Gold at 40 finished pictures". Null for single badges.
  final String? unit;

  /// A badge no longer offered: shown only where already earned, never counted for platinum or the percentage.
  final bool retired;
}

/// Facts about one course, for the Course master series.
class CourseFacts {
  int finished = 0;
  int threeStar = 0;
  int extremeThreeStar = 0;
}

/// What the achievements look at, gathered once from the saved progress.
class ProgressFacts {
  ProgressFacts(List<Course> courses, ProgressStore store)
      : bestStreak = store.bestStreak,
        bestCombo = store.bestCombo,
        timeAttackWins = Difficulty.values.fold(0, (n, d) => n + store.timeAttack(d).wins),
        daysPlayed = store.daysPlayed,
        secrets = store.secrets {
    for (final c in courses) {
      var courseDone = 0;
      final cf = perCourse[c.id] = CourseFacts();
      for (final level in c.levels) {
        final extreme = level.difficulty == Difficulty.extreme;
        for (final p in level.puzzles) {
          final paint = store.record(PlayMode.paint.key(p.id));
          final sort = store.record(PlayMode.sort.key(p.id));
          final three = (paint?.bestStars ?? 0) == 3 || (sort?.bestStars ?? 0) == 3;
          if (paint != null || sort != null) {
            finished++;
            courseDone++;
            cf.finished++;
            if (level.difficulty.index >= Difficulty.hard.index) hardFinished++;
            if (extreme) extremeFinished++;
            if (c.special) specialCoursesTouched.add(c.id);
          }
          if (paint != null && sort != null) bothModes++;
          if (sort != null) sortFinished++;
          if ((sort?.bestStars ?? 0) == 3) cleanSorts++;
          if (three) {
            threeStars++;
            cf.threeStar++;
          }
          if (extreme) {
            extremeTotal++;
            if (three) cf.extremeThreeStar++;
          }
          total++;
        }
      }
      if (courseDone == c.puzzles.length) coursesDone++;
      if (c.special) specialCourses++;
    }
  }

  int total = 0;
  int finished = 0;
  int hardFinished = 0;
  int extremeFinished = 0;
  int extremeTotal = 0;
  int coursesDone = 0;
  int threeStars = 0;
  int sortFinished = 0;
  int cleanSorts = 0;
  int bothModes = 0;
  int specialCourses = 0;
  final Set<String> specialCoursesTouched = {};
  final Map<String, CourseFacts> perCourse = {};
  final int bestStreak;
  final int bestCombo;
  final int timeAttackWins;

  /// Different days a picture was finished (the store's `daysPlayed`).
  final int daysPlayed;

  /// The store's secrets, for feature badges such as Dressed up or Night owl.
  final Set<String> secrets;

  /// For the platinum badge: other badges earned and in all. Filled by [progressFacts].
  int platinumCurrent = 0;
  int platinumTarget = 0;
}

class _Registered {
  const _Registered(this.badge, this.sideloadOnly);
  final Achievement badge;
  final bool sideloadOnly;
}

final _registered = <_Registered>[];

/// Adds a badge from a feature (PAP-16, 43, 45) or the private rainbow tier (PAP-27).
/// It is counted for platinum and the percentage, unless its tier is rainbow.
/// Throws when [a]'s id is already taken.
void registerBadge(Achievement a, {bool sideloadOnly = false}) {
  if (a.tier == BadgeTier.platinum || a.retired) {
    throw StateError('Badge "${a.id}": only the built-in engine makes platinum or retired badges');
  }
  final taken = achievementsFor(store: false, courses: allCourses).any((b) => b.id == a.id);
  if (taken || _retiredBadges.any((b) => b.id == a.id)) {
    throw StateError('Badge "${a.id}" is already registered');
  }
  _registered.add(_Registered(a, sideloadOnly));
}

@visibleForTesting
void resetRegisteredBadges() => _registered.clear();

final _retiredBadges = <Achievement>[
  Achievement('streak7', 'Week of sparkle', 'Keep a 7-day daily streak', (f) => f.bestStreak >= 7,
      series: 'Days played', retired: true),
];

int _pct(double pct, int pictureCount) => (pct * pictureCount).round().clamp(1, pictureCount < 1 ? 1 : pictureCount);

/// What each series counts. Course master steps pass their own.
const _seriesUnits = {
  'Perfectionist': 'three-star pictures',
  'Gallery': 'finished pictures',
  'Days played': 'days',
  'Sort combo': 'in a row',
  'Time Attack': 'wins',
  'Extreme': 'Extreme pictures',
};

Achievement _step(
  String series,
  BadgeTier tier,
  String id,
  String title,
  String description,
  int target,
  int Function(ProgressFacts f) current, {
  String? mochiTitle,
  String? unit,
}) =>
    Achievement(
      id,
      title,
      description,
      (f) => current(f) >= target,
      tier: tier,
      series: series,
      mochiTitle: mochiTitle,
      progress: (f) => BadgeProgress(current(f), target),
      unit: unit ?? _seriesUnits[series],
    );

List<Achievement> _series(int n, int extremeTotal) {
  const b = BadgeTier.bronze, s = BadgeTier.silver, g = BadgeTier.gold;
  final starsB = UnlockTables.scaled(10, n);
  final starsS = _pct(0.30, n), starsG = _pct(0.75, n);
  final galB = _pct(0.25, n), galS = _pct(0.50, n);
  final extS = extremeTotal < 1 ? 0 : UnlockTables.scaled(10, n).clamp(1, extremeTotal);
  return [
    _step('Perfectionist', b, 'stars10', 'Perfectionist', 'Earn 3 stars on $starsB pictures', starsB,
        (f) => f.threeStars),
    _step('Perfectionist', s, 'stars.silver', 'Perfectionist silver', 'Earn 3 stars on $starsS pictures', starsS,
        (f) => f.threeStars),
    _step('Perfectionist', g, 'stars.gold', 'Perfectionist gold', 'Earn 3 stars on $starsG pictures', starsG,
        (f) => f.threeStars,
        mochiTitle: 'Sparkle Chef'),
    _step('Gallery', b, 'gallery.bronze', 'Gallery bronze', 'Finish $galB pictures', galB, (f) => f.finished),
    _step('Gallery', s, 'half', 'Halfway there', 'Finish $galS pictures', galS, (f) => f.finished),
    _step('Gallery', g, 'all', 'Full gallery', 'Finish every picture', n, (f) => f.finished, mochiTitle: 'Curator'),
    _step('Days played', b, 'streak3', 'Little habit', 'Play on 3 different days', 3, (f) => f.daysPlayed),
    _step('Days played', s, 'days.silver', 'Days played silver', 'Play on 10 different days', 10, (f) => f.daysPlayed),
    _step('Days played', g, 'days.gold', 'Days played gold', 'Play on 30 different days', 30, (f) => f.daysPlayed,
        mochiTitle: 'Loyal Regular'),
    _step('Sort combo', b, 'combo10', 'On a roll', 'Reach a 10 combo in Sort', 10, (f) => f.bestCombo),
    _step('Sort combo', s, 'combo.silver', 'Sort combo silver', 'Reach a 20 combo in Sort', 20, (f) => f.bestCombo),
    _step('Sort combo', g, 'combo.gold', 'Sort combo gold', 'Reach a 30 combo in Sort', 30, (f) => f.bestCombo,
        mochiTitle: 'Combo Cat'),
    _step('Time Attack', b, 'clock', 'Beat the clock', 'Win a Time Attack round', 1, (f) => f.timeAttackWins),
    _step(
        'Time Attack', s, 'clock.silver', 'Time Attack silver', 'Win 5 Time Attack rounds', 5, (f) => f.timeAttackWins),
    _step('Time Attack', g, 'clock.gold', 'Time Attack gold', 'Win 20 Time Attack rounds', 20, (f) => f.timeAttackWins,
        mochiTitle: 'Speedy Paws'),
    if (extremeTotal > 0) ...[
      _step('Extreme', b, 'extreme', 'Fearless', 'Finish an Extreme picture', 1, (f) => f.extremeFinished),
      _step('Extreme', s, 'extreme.silver', 'Extreme silver', 'Finish $extS Extreme pictures', extS,
          (f) => f.extremeFinished),
      _step('Extreme', g, 'extreme.gold', 'Extreme gold', 'Finish every Extreme picture', extremeTotal,
          (f) => f.extremeFinished,
          mochiTitle: 'Brave Painter'),
    ],
  ];
}

/// The series of every Course master badge starts with this, followed by the course id.
const courseMasterSeries = 'Course master: ';

/// The course id of a Course master [series], or null for any other series.
String? courseMasterOf(String? series) =>
    series != null && series.startsWith(courseMasterSeries) ? series.substring(courseMasterSeries.length) : null;

List<Achievement> _courseMasters(List<Course> courses) => [
      for (final c in courses)
        if (c.puzzles.isNotEmpty) ...[
          _step('$courseMasterSeries${c.id}', BadgeTier.bronze, 'course.${c.id}.bronze', '${c.title} finished',
              'Finish every picture in ${c.title}', c.puzzles.length, (f) => f.perCourse[c.id]?.finished ?? 0,
              unit: 'finished pictures'),
          _step('$courseMasterSeries${c.id}', BadgeTier.silver, 'course.${c.id}.silver', '${c.title} all 3★',
              'Earn 3 stars on every picture in ${c.title}', c.puzzles.length, (f) => f.perCourse[c.id]?.threeStar ?? 0,
              unit: 'three-star pictures'),
          if (c.levels.any((l) => l.difficulty == Difficulty.extreme && l.puzzles.isNotEmpty))
            _step(
                '$courseMasterSeries${c.id}',
                BadgeTier.gold,
                'course.${c.id}.gold',
                '${c.title} Extreme 3★',
                'Earn 3 stars on every Extreme picture in ${c.title}',
                c.levels.where((l) => l.difficulty == Difficulty.extreme).fold(0, (n, l) => n + l.puzzles.length),
                (f) => f.perCourse[c.id]?.extremeThreeStar ?? 0,
                mochiTitle: 'Course Champ',
                unit: 'Extreme three-star pictures'),
        ],
    ];

List<Achievement> _singles({required bool store}) => [
      Achievement('first', 'First sparkle', 'Finish your first picture', (f) => f.finished >= 1,
          mochiTitle: 'Sparkle Kitten', progress: (f) => BadgeProgress(f.finished, 1)),
      Achievement('hard', 'Big canvas', 'Finish a Hard picture', (f) => f.hardFinished >= 1,
          progress: (f) => BadgeProgress(f.hardFinished, 1)),
      Achievement('both', 'Two ways', 'Finish the same picture in Paint and Sort', (f) => f.bothModes >= 1,
          progress: (f) => BadgeProgress(f.bothModes, 1)),
      Achievement('sort5', 'Tidy hands', 'Finish 5 pictures in Sort', (f) => f.sortFinished >= 5,
          progress: (f) => BadgeProgress(f.sortFinished, 5)),
      Achievement('cleansort', 'Steady tray', 'Earn 3 stars in Sort', (f) => f.cleanSorts >= 1,
          tier: BadgeTier.silver, progress: (f) => BadgeProgress(f.cleanSorts, 1)),
      Achievement('course', 'Collector', 'Finish every picture in a course', (f) => f.coursesDone >= 1,
          progress: (f) => BadgeProgress(f.coursesDone, 1)),
      if (!store)
        Achievement('fan', 'Fan favorite', 'Finish a picture in each special collection',
            (f) => f.specialCourses > 0 && f.specialCoursesTouched.length == f.specialCourses,
            tier: BadgeTier.silver, progress: (f) => BadgeProgress(f.specialCoursesTouched.length, f.specialCourses)),
    ];

final _platinum = Achievement(
  'platinum',
  'Pawly Master',
  'Earn every other badge',
  (f) => f.platinumTarget > 0 && f.platinumCurrent >= f.platinumTarget,
  tier: BadgeTier.platinum,
  progress: (f) => BadgeProgress(f.platinumCurrent, f.platinumTarget),
);

/// The badges a build offers for [courses], without retired ones. The store build
/// has no special collections, so it leaves out the badges that ask for them.
/// Scaled thresholds follow the build's picture count, so pass its full course list.
List<Achievement> achievementsFor({required bool store, required List<Course> courses}) {
  final n = courses.fold(0, (sum, c) => sum + c.puzzles.length);
  final extreme = courses.fold(
      0,
      (sum, c) =>
          sum + c.levels.where((l) => l.difficulty == Difficulty.extreme).fold(0, (m, l) => m + l.puzzles.length));
  return [
    ..._singles(store: store),
    ..._series(n, extreme),
    ..._courseMasters(courses),
    for (final r in _registered)
      if (!(store && r.sideloadOnly)) r.badge,
    _platinum,
  ];
}

/// The build's badges for [courses]. A course list without special collections is a store list
/// whatever the flavor, so the badges that ask for them are left out.
List<Achievement> _listFor(List<Course> courses) =>
    achievementsFor(store: isStoreBuild || !courses.any((c) => c.special), courses: courses);

/// The badges this build offers for [allCourses].
List<Achievement> get achievements => _listFor(allCourses);

/// Badges to show: the build's list plus any retired badge already earned.
List<Achievement> achievementsShown(List<Course> courses, ProgressStore store) => [
      ..._listFor(courses),
      for (final a in _retiredBadges)
        if (store.hasSeenBadge(a.id)) a,
    ];

/// Whether [a] counts toward [completionPercent] and platinum.
bool countsTowardCompletion(Achievement a) => a.tier != BadgeTier.rainbow && !a.retired;

/// Facts for [courses], with the platinum counts filled in.
ProgressFacts progressFacts(List<Course> courses, ProgressStore store) => badgeSnapshot(courses, store).facts;

/// [progressFacts] and [earnedAchievements] from one pass over her progress.
({ProgressFacts facts, Set<String> earned}) badgeSnapshot(List<Course> courses, ProgressStore store) {
  final facts = ProgressFacts(courses, store);
  return (facts: facts, earned: _earnedFrom(_listFor(courses), facts, store));
}

Set<String> _earnedFrom(List<Achievement> list, ProgressFacts facts, ProgressStore store) {
  final earned = <String>{
    for (final a in list)
      if (a.tier != BadgeTier.platinum && (a.isEarned(facts) || store.hasSeenBadge(a.id))) a.id,
    for (final a in _retiredBadges)
      if (store.hasSeenBadge(a.id)) a.id,
  };
  final others = [
    for (final a in list)
      if (a.tier != BadgeTier.platinum && countsTowardCompletion(a)) a
  ];
  facts.platinumTarget = others.length;
  facts.platinumCurrent = others.where((a) => earned.contains(a.id)).length;
  for (final a in list) {
    if (a.tier == BadgeTier.platinum && (a.isEarned(facts) || store.hasSeenBadge(a.id))) earned.add(a.id);
  }
  return earned;
}

/// IDs of every badge earned so far. A badge stays earned once celebrated,
/// even when the build grows or its rule is retired.
Set<String> earnedAchievements(List<Course> courses, ProgressStore store) => badgeSnapshot(courses, store).earned;

/// The title on her nameplate before her first Mochi title.
const starterTitle = 'New Painter';

/// One title she can wear on her nameplate (the PAP-48 picker).
@immutable
class TitleChoice {
  const TitleChoice(this.title, this.badge, {required this.earned});

  final String title;

  /// The badge that gives it, or null for [starterTitle].
  final Achievement? badge;

  final bool earned;

  BadgeTier? get tier => badge?.tier;
}

/// The titles for the picker: [starterTitle] first, then one per Mochi title in badge order, earned ones first.
/// A title that several badges give (Course Champ) is earned when any of them is.
/// A rainbow title is listed only once earned, so the private badge stays a secret.
List<TitleChoice> titleChoices(List<Achievement> shown, Set<String> earned) {
  final byTitle = <String, TitleChoice>{};
  for (final a in shown) {
    if (!a.givesTitle) continue;
    final has = earned.contains(a.id);
    if (a.tier == BadgeTier.rainbow && !has) continue;
    final prev = byTitle[a.mochiTitle];
    if (prev == null || (!prev.earned && has)) byTitle[a.mochiTitle] = TitleChoice(a.mochiTitle, a, earned: has);
  }
  // Earned titles first, so the ones she can wear sit together above the locked ones.
  final list = byTitle.values.toList();
  return [
    const TitleChoice(starterTitle, null, earned: true),
    ...list.where((c) => c.earned),
    ...list.where((c) => !c.earned),
  ];
}

/// The title her nameplate wears: [chosen] when it is one she has earned, else the Mochi title of her
/// highest-tier earned badge that [Achievement.givesTitle] (never rainbow), else [starterTitle].
///
/// Pass [earned] and [shown] when the caller already has them, to skip a second pass.
TitleChoice currentTitleChoice(
  List<Course> courses,
  ProgressStore store, {
  String? chosen,
  Set<String>? earned,
  List<Achievement>? shown,
}) {
  earned ??= earnedAchievements(courses, store);
  shown ??= achievementsShown(courses, store);
  final choices = titleChoices(shown, earned);
  if (chosen != null) {
    final pick = choices.where((c) => c.earned && c.title == chosen).firstOrNull;
    if (pick != null) return pick;
  }
  TitleChoice? best;
  for (final c in choices) {
    final tier = c.tier;
    if (!c.earned || tier == null || tier == BadgeTier.rainbow) continue;
    if (best == null || tier.index > best.tier!.index) best = c;
  }
  return best ?? choices.first;
}

/// One row of the Badges screen: the steps of a series in tier order, or a single badge.
@immutable
class BadgeRowView {
  const BadgeRowView(this.steps, this.earned);

  /// At least one. A single badge, or a retired one, is a row of its own.
  final List<Achievement> steps;
  final Set<String> earned;

  bool get isSeries => steps.length > 1;

  int get _topAt => steps.lastIndexWhere((a) => earned.contains(a.id));

  /// The highest step earned, or null before the first.
  Achievement? get top {
    final at = _topAt;
    return at < 0 ? null : steps[at];
  }

  /// The lowest step not yet earned, or null when the row is complete. A higher step can be earned first
  /// (Course master gold needs only the Extreme pictures), so this is not always the step after [top].
  Achievement? get next => steps.where((a) => !earned.contains(a.id)).firstOrNull;
}

/// The Badges screen's rows for [shown], in list order. Platinum and rainbow badges are left out:
/// the screen shows them in their own slots at the top.
List<BadgeRowView> badgeRows(List<Achievement> shown, Set<String> earned) {
  final groups = <String, List<Achievement>>{};
  for (final a in shown) {
    if (a.tier == BadgeTier.platinum || a.tier == BadgeTier.rainbow) continue;
    final key = a.series == null || a.retired ? 'badge:${a.id}' : 'series:${a.series}';
    (groups[key] ??= []).add(a);
  }
  return [
    for (final steps in groups.values) BadgeRowView(steps..sort((a, b) => a.tier.index.compareTo(b.tier.index)), earned)
  ];
}

/// Progress toward [a], or null when it has nothing to count. Get [facts] from [progressFacts].
BadgeProgress? badgeProgress(Achievement a, ProgressFacts facts) => a.progress?.call(facts);

/// Share of the build's badges earned, 0 to 100. Rainbow and retired badges don't count.
/// Pass [earned] when the caller already has it, to skip a second pass.
int completionPercent(List<Course> courses, ProgressStore store, {Set<String>? earned}) {
  final list = _listFor(courses).where(countsTowardCompletion).toList();
  if (list.isEmpty) return 0;
  final have = earned ?? earnedAchievements(courses, store);
  final done = list.where((a) => have.contains(a.id)).length;
  return (done * 100 ~/ list.length).clamp(0, 100);
}

/// Badges earned but not yet celebrated; marks them as celebrated.
List<Achievement> takeNewAchievements(List<Course> courses, ProgressStore store) {
  final earned = earnedAchievements(courses, store);
  final fresh = [
    for (final a in _listFor(courses))
      if (earned.contains(a.id) && !store.hasSeenBadge(a.id)) a
  ];
  if (fresh.isNotEmpty) store.markBadgesSeen(fresh.map((a) => a.id));
  return fresh;
}

/// Sentinel in the seen set: the tiered engine has taken a first look at this save.
const engineSentinel = 'engine.tiers';

/// The first launch with the tiered engine marks badges already earned as seen, quietly,
/// so no pile of new badges shows after a picture. Does nothing after that.
/// Call it after every [registerBadge] of startup: a badge registered later is not covered.
Future<void> baselineBadges(List<Course> courses, ProgressStore store) {
  if (store.hasSeenBadge(engineSentinel)) return Future.value();
  final facts = ProgressFacts(courses, store);
  final list = _listFor(courses);
  final earned = _earnedFrom(list, facts, store);
  return store.markBadgesSeen([
    ...earned,
    for (final a in _retiredBadges)
      if (a.isEarned(facts)) a.id,
    // Little habit used to be a 3-day daily streak. Whoever earned it that way keeps it.
    if (facts.bestStreak >= 3) 'streak3',
    engineSentinel,
  ]);
}
