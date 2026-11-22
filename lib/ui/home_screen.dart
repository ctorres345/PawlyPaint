import 'package:flutter/material.dart';

import '../data/rewards.dart';
import '../data/tutorial.dart';
import '../logic/unlocks.dart';
import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'badges_screen.dart';
import 'cat_mascot.dart';
import 'coach.dart';
import 'course_screen.dart';
import 'gallery_screen.dart';
import 'game_screen.dart';
import 'gem_style.dart';
import 'music_sheet.dart';
import 'settings_screen.dart';
import 'sort_screen.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';
import 'time_attack_screen.dart';
import 'unlock_ui.dart';
import 'unlocks_screen.dart';

/// Home C from the PAP-19 canvas: top bar with the nameplate, today's picture
/// and Time Attack, the courses, Keep painting, the unlock strip and the dock.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Tells Home when another screen opens over it. Register it in the app's `navigatorObservers`.
final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<Course> get courses => widget.courses;

  /// Courses that were open at the last build, to spot one that just opened.
  Set<String>? _open;
  final Set<String> _justOpened = {};
  bool _caughtUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) homeRouteObserver.subscribe(this, route);
    if (_caughtUp) return;
    _caughtUp = true;
    // One summary for everything open and never celebrated, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final store = ProgressScope.of(context);
      final ids = catchUpIds(store.unlockState(courses));
      if (ids.isNotEmpty) await showCatchUp(context, store, ids);
      // Badges she already qualified for when they reached the app (an update adds a course or a badge):
      // one note now, not a pile on the next completion sheet.
      // A read-only save can't remember the note was shown, so it would repeat on every launch.
      if (!mounted || store.isReadOnly) return;
      final badges = takeNewAchievements(courses, store);
      if (badges.isEmpty) return;
      final summary = _summary = showEarnedBadgesSummary(context, badges, onOpen: () => _go(DockItem.badges));
      // Once it has left by itself, closing it again would hide some other note.
      summary.closed.whenComplete(() {
        if (identical(_summary, summary)) _summary = null;
      });
    });
  }

  Future<void> _openTimeAttack(ProgressStore store) async {
    final nav = Navigator.of(context);
    if (!store.introduced.contains(UnlockTables.modeTimeAttack)) {
      await showMochiDialog(
        context,
        title: 'Time Attack!',
        message: 'Race the clock: finish a picture before time runs out. Every second counts, so be speedy!',
        button: "I'm ready",
      );
      await store.markIntroduced(UnlockTables.modeTimeAttack);
    }
    if (!mounted) return;
    await nav.push(MaterialPageRoute(builder: (_) => TimeAttackScreen(courses: courses)));
  }

  /// The badge summary while it is up. It is about Home, so it closes when another screen opens.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _summary;

  @override
  void didPushNext() {
    _summary?.close();
    _summary = null;
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _go(DockItem item) {
    final nav = Navigator.of(context);
    switch (item) {
      case DockItem.home:
        return;
      case DockItem.gallery:
        nav.push(MaterialPageRoute(builder: (_) => GalleryScreen(courses: courses)));
      case DockItem.unlocks:
        openUnlocks(nav);
      case DockItem.badges:
        nav.push(MaterialPageRoute(builder: (_) => BadgesScreen(courses: courses)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final unlocks = store.unlockState(courses);
    final openNow = {
      for (final c in courses)
        if (unlocks.isCourseOpen(c.id)) c.id,
    };
    _justOpened.addAll(openNow.difference(_open ?? openNow));
    _open = openNow;
    final totalStars = courses.fold(0, (s, c) => s + store.starsIn(c.puzzles));
    final maxStars = courses.fold(0, (s, c) => s + ProgressStore.maxStarsIn(c.puzzles));
    final dailyId = store.dailyPuzzleId(DateTime.now(), [for (final c in courses) ...c.puzzles]);
    final inProgress = keepPainting(store, courses, unlocks, dailyId: dailyId);
    final now = nowPainting(inProgress, store, courses, unlocks);
    final settings = SettingsScope.maybeOf(context);
    const gap = SizedBox(height: 10);
    const sectionGap = SizedBox(height: 18);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PawPattern()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  name: settings?.playerName ?? AppSettings.defaultPlayerName,
                  title: currentTitleChoice(courses, store, chosen: settings?.playerTitle),
                  onNameplate: () => _go(DockItem.badges),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 184 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      if (store.isReadOnly) ...[const _ReadOnlyBanner(), const SizedBox(height: 16)],
                      const SizedBox(height: 4),
                      // Room for the next card's tag, which sits on its top edge.
                      if (store.freshPaintPending) ...[
                        _FreshPaintCard(onClose: store.dismissFreshPaint),
                        const SizedBox(height: 26)
                      ],
                      SizedBox(
                        height: 176,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 12, child: _DailyCard(courses: courses, store: store, unlocks: unlocks)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 10,
                              child: _TimeAttackCard(
                                store: store,
                                open: unlocks.isModeOpen(UnlockTables.modeTimeAttack),
                                onRace: () => _openTimeAttack(store),
                              ),
                            ),
                          ],
                        ),
                      ),
                      sectionGap,
                      StickerHeader(
                        title: const StickerTitle(art: 'icons/gem_paw.png', text: 'Courses', artSize: 30),
                        trailing: MiniChip(
                          icon: Icons.star_rounded,
                          label: '$totalStars / $maxStars',
                          semanticLabel: '$totalStars of $maxStars stars',
                        ),
                      ),
                      gap,
                      if (now != null) ...[_NowPaintingCard(course: now, store: store), gap],
                      _CourseShelf(
                        courses: [
                          for (final c in courses)
                            if (c != now) c,
                        ],
                        store: store,
                        unlocks: unlocks,
                        justOpened: _justOpened,
                      ),
                      if (inProgress.isNotEmpty) ...[
                        sectionGap,
                        StickerHeader(
                          title: const StickerTitle(art: 'icons/brush.png', text: 'Keep painting', artSize: 30),
                          trailing: MiniChip(label: '${inProgress.length} in progress'),
                        ),
                        const SizedBox(height: 18),
                        _KeepPaintingRow(
                          items: inProgress.take(3).toList(),
                          store: store,
                          dailyId: dailyId,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 96 + MediaQuery.paddingOf(context).bottom,
            child: _UnlockStrip(unlocks: unlocks),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: PawDock(
              onSelect: _go,
              dots: {if (unlocks.newRewards.isNotEmpty) DockItem.unlocks},
            ),
          ),
        ],
      ),
    );
  }
}

/// A picture she started and left: where it lives and how far she got.
class InProgress {
  const InProgress(this.course, this.level, this.puzzle, this.game);

  final Course course;
  final Level level;
  final Puzzle puzzle;
  final SavedGame game;

  double get progress => puzzle.cellCount == 0 ? 0 : game.placedCount / puzzle.cellCount;
}

/// Every started Paint picture she can open, newest save first; saves without
/// a time keep course order after them (PAP-20 Keep painting). A picture in a
/// locked course or level (say, an old daily) is left out, except [dailyId],
/// today's picture, which opens as the daily.
List<InProgress> keepPainting(ProgressStore store, List<Course> courses, UnlockState unlocks, {String? dailyId}) {
  final list = <InProgress>[
    for (final c in courses)
      for (final (li, l) in c.levels.indexed)
        for (final p in l.puzzles)
          if (store.savedFor(p) case final g? when g.placedCount > 0 && !store.isDone(p.id))
            if (p.id == dailyId || (unlocks.isCourseOpen(c.id) && store.isLevelUnlocked(c, li, PlayMode.paint)))
              InProgress(c, l, p, g),
  ];
  final order = {for (var i = 0; i < list.length; i++) list[i]: i};
  list.sort((a, b) {
    final ta = a.game.savedAt, tb = b.game.savedAt;
    if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
    if (ta != null && tb == null) return -1;
    if (ta == null && tb != null) return 1;
    return order[a]!.compareTo(order[b]!);
  });
  return list;
}

/// The course for the "Now painting" card: the latest picture she left, else
/// the first open course with pictures left, else the first course.
Course? nowPainting(List<InProgress> inProgress, ProgressStore store, List<Course> courses, UnlockState unlocks) {
  // Today's picture can come from a locked course; the card must not open one.
  final latest = inProgress.where((i) => unlocks.isCourseOpen(i.course.id)).firstOrNull;
  if (latest != null) return latest.course;
  final open = courses.where((c) => unlocks.isCourseOpen(c.id));
  return open.where((c) => store.completedIn(c.puzzles) < c.puzzles.length).firstOrNull ?? open.firstOrNull;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.title, required this.onNameplate});

  final String name;

  /// Her chosen or best title, with the tier that colors the medal.
  final TitleChoice title;
  final VoidCallback onNameplate;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mode = dark ? 'dark' : 'light';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Semantics(
              header: true,
              label: 'PawlyPaint',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/art/brand/mark_$mode.png', width: 34, height: 32, fit: BoxFit.contain),
                  // The wordmark needs about 90 pt; on narrow phones the mark stands alone.
                  if (box.maxWidth >= 372) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Image.asset('assets/art/brand/wordmark_$mode.png', width: 82, height: 15),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Nameplate(name: name, title: title.title, tier: title.tier, onTap: onNameplate),
            const SizedBox(width: 2),
            const MusicButton(sticker: true),
            SquareButton(
              icon: Icons.settings_rounded,
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

/// A save from a newer build is shown but never written over.
class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.soft,
          borderRadius: BorderRadius.circular(PawRadius.tile),
          border: Border.all(color: t.outline, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.info_rounded, color: t.onSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This progress comes from a newer PawlyPaint, so changes are not saved. '
                'Update the app to keep your progress safe.',
                style: TextStyle(color: t.onSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says why her progress is empty after the Fresh paint reset, until she closes it (PAP-78).
class _FreshPaintCard extends StatelessWidget {
  const _FreshPaintCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    // The message and the close button are read as two items.
    return HeroCard(
      color: t.soft,
      tag: TagPill(icon: Icons.auto_awesome_rounded, label: 'Fresh paint!', color: t.accent, foreground: t.onAccent),
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: 'Fresh paint! New pictures, fresh start',
              excludeSemantics: true,
              child: Text(
                'New pictures, fresh start',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: t.ink),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            container: true,
            child: SquareButton(icon: Icons.close_rounded, tooltip: 'Dismiss', onPressed: onClose),
          ),
        ],
      ),
    );
  }
}

/// Today's surprise picture and the daily streak.
class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.courses, required this.store, required this.unlocks});

  final List<Course> courses;
  final ProgressStore store;
  final UnlockState unlocks;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final today = DateTime.now();
    final all = [for (final c in courses) ...c.puzzles];
    final id = store.dailyPuzzleId(today, all);
    final puzzle = all.firstWhere((p) => p.id == id);
    final done = store.dailyDoneToday(today);
    final streak = store.streak(today);
    if (!unlocks.isModeOpen(UnlockTables.modeDaily)) {
      return _LockedHero(
        icon: Icons.calendar_today_rounded,
        title: "Today's picture",
        condition: unlockCondition(UnlockTables.modeDaily),
      );
    }
    void play() => _pickDailyMode(context, store, puzzle, sortOpen: unlocks.isModeOpen(UnlockTables.modeSort));
    return Semantics(
      container: true,
      label: done ? "Today's picture is done. Streak: $streak days" : "Today's surprise picture. Streak: $streak days",
      child: HeroCard(
        color: t.soft,
        tag: TagPill(
          icon: Icons.calendar_today_rounded,
          label: "Today's picture",
          color: t.accent,
          foreground: t.onAccent,
        ),
        onTap: play,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final thumb = (box.maxWidth * .46).clamp(44.0, 66.0);
                  return Row(
                    children: [
                      _TiltedThumb(puzzle: puzzle, done: done, placed: store.savedFor(puzzle)?.placed, size: thumb),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MiniChip(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: t.streak,
                            label: streak == 1 ? '1 day' : '$streak days',
                            semanticLabel: '$streak day streak',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: done ? 'Done' : 'Paint',
              icon: done ? Icons.check_rounded : Icons.brush_rounded,
              color: t.accent,
              foreground: t.onAccent,
              onPressed: play,
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's picture as a tilted photo with a sparkle.
class _TiltedThumb extends StatelessWidget {
  const _TiltedThumb({required this.puzzle, required this.done, required this.placed, required this.size});

  final Puzzle puzzle;
  final bool done;
  final String? placed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Transform.rotate(
      angle: -0.07,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.outline, width: 2),
              boxShadow: lip(t, 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: PuzzleThumbPainter(puzzle, complete: done, placed: placed)),
                    if (!done) Center(child: Icon(Icons.card_giftcard_rounded, color: t.accent, size: size * .45)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: -12, right: -12, child: Icon(Icons.auto_awesome_rounded, size: 22, color: t.star)),
        ],
      ),
    );
  }
}

class _TimeAttackCard extends StatelessWidget {
  const _TimeAttackCard({required this.store, required this.open, required this.onRace});

  final ProgressStore store;
  final bool open;
  final VoidCallback onRace;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    if (!open) {
      return _LockedHero(
        icon: Icons.bolt_rounded,
        title: 'Time Attack',
        condition: unlockCondition(UnlockTables.modeTimeAttack),
      );
    }
    final best = Difficulty.values.map((d) => store.timeAttack(d)).where((r) => r.wins > 0).fold(0, (m, r) {
      return r.bestLeft > m ? r.bestLeft : m;
    });
    final bestText = best > 0 ? '${best ~/ 60}:${(best % 60).toString().padLeft(2, '0')}' : '--';
    return Semantics(
      container: true,
      label: best > 0 ? 'Time Attack. Best: $bestText left' : 'Time Attack',
      child: HeroCard(
        color: t.courseTint(CourseTint.purple),
        tag: TagPill(icon: Icons.bolt_rounded, label: 'Time Attack', color: t.surface, foreground: t.ink),
        onTap: onRace,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Transform.rotate(angle: .17, child: const Art('mochi/stopwatch.png', size: 52)),
                  const SizedBox(width: 8),
                  // Shrinks on narrow phones and big text instead of overflowing.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Best', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.ink)),
                            Text(bestText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: 'Race',
              icon: Icons.play_arrow_rounded,
              color: t.star,
              foreground: fixedInk,
              onPressed: onRace,
            ),
          ],
        ),
      ),
    );
  }
}

/// A hero card that is not open yet: dashed, with what it needs.
class _LockedHero extends StatelessWidget {
  const _LockedHero({required this.icon, required this.title, required this.condition});

  final IconData icon;
  final String title;
  final String condition;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      button: true,
      label: '$title, locked. $condition',
      excludeSemantics: true,
      child: LockedSurface(
        child: InkWell(
          onTap: () => showLockedHint(context, condition),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 20, color: t.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, color: t.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // The card has a fixed height; a tap shows the whole condition.
                Flexible(
                  child: Text(
                    condition,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPaintingCard extends StatelessWidget {
  const _NowPaintingCard({required this.course, required this.store});

  final Course course;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final stars = store.starsIn(course.puzzles);
    final max = ProgressStore.maxStarsIn(course.puzzles);
    return Semantics(
      button: true,
      label: 'Now painting: ${course.title}, $stars of $max stars',
      excludeSemantics: true,
      child: HeroCard(
        color: t.courseTint(courseTintOf(course)),
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseScreen(course: course))),
        child: Row(
          children: [
            Art(courseArt(course), size: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Now painting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.onSoft)),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.ink),
                  ),
                  const SizedBox(height: 6),
                  PawBar(value: max == 0 ? 0 : stars / max, track: t.surface, height: 7),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 15, color: t.star),
                      const SizedBox(width: 2),
                      Text('$stars/$max', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 28, color: t.accent),
          ],
        ),
      ),
    );
  }
}

/// Every other course as a round sticker in one sideways row.
class _CourseShelf extends StatelessWidget {
  const _CourseShelf({required this.courses, required this.store, required this.unlocks, required this.justOpened});

  final List<Course> courses;
  final ProgressStore store;
  final UnlockState unlocks;
  final Set<String> justOpened;

  @override
  Widget build(BuildContext context) {
    // Art and gaps, plus two caption lines that grow with the text size.
    final captions = MediaQuery.textScalerOf(context).scale(32);
    return SizedBox(
      height: 86 + captions,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 2),
        itemCount: courses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) => _ShelfCourse(
          course: courses[i],
          store: store,
          unlocks: unlocks,
          celebrate: justOpened.contains(courses[i].id),
        ),
      ),
    );
  }
}

class _ShelfCourse extends StatelessWidget {
  const _ShelfCourse({required this.course, required this.store, required this.unlocks, required this.celebrate});

  final Course course;
  final ProgressStore store;
  final UnlockState unlocks;

  /// True when the course opened while she was playing: it pops in once.
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final open = unlocks.isCourseOpen(course.id);
    final String caption;
    final String label;
    final VoidCallback onTap;
    if (open) {
      final stars = store.starsIn(course.puzzles);
      final max = ProgressStore.maxStarsIn(course.puzzles);
      caption = '$stars/$max';
      label = '${course.title}, $stars of $max stars';
      onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseScreen(course: course)));
    } else {
      final need = UnlockTables.courseStars[course.id] ?? 0;
      final have = unlocks.gateStars.clamp(0, need);
      final condition = '${unlockCondition(UnlockTables.courseId(course.id), starsLeft: need - have)} ${course.title}';
      caption = '★ $have/$need';
      label = '${course.title}, locked. $have of $need stars. $condition';
      onTap = () => showLockedHint(context, condition);
    }
    final item = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(PawRadius.tile),
        onTap: onTap,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.courseTint(courseTintOf(course)),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.outline, width: 3),
                      boxShadow: lip(t, 3),
                    ),
                    child: Art(courseArt(course), size: 52, gray: !open),
                  ),
                  if (!open)
                    Positioned(
                      right: -6,
                      bottom: -8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.outline, width: 2),
                        ),
                        child: Icon(Icons.lock_rounded, size: 15, color: t.ink),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                course.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.ink),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: celebrate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
      ),
      child: item,
    );
  }
}

/// Up to three pictures she left half done.
class _KeepPaintingRow extends StatelessWidget {
  const _KeepPaintingRow({required this.items, required this.store, required this.dailyId});

  final List<InProgress> items;
  final ProgressStore store;

  /// Today's picture: resuming it here still counts for the streak.
  final String dailyId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 20) / 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(
                width: w,
                child: _KeepPaintingCard(item: items[i], store: store, daily: items[i].puzzle.id == dailyId),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KeepPaintingCard extends StatelessWidget {
  const _KeepPaintingCard({required this.item, required this.store, required this.daily});

  final InProgress item;
  final ProgressStore store;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final pct = (item.progress * 100).round();
    final level = item.level.difficulty.label;
    return Semantics(
      button: true,
      label: '${item.puzzle.title}, ${item.course.title}, $level, $pct percent painted',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(PawRadius.tile), boxShadow: lip(t)),
            child: Material(
              color: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PawRadius.tile),
                side: BorderSide(color: t.outline, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GameScreen(puzzle: item.puzzle, store: store, daily: daily)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, box) {
                          final side = box.maxWidth.clamp(0.0, 78.0);
                          return Container(
                            width: side,
                            height: side,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.outline, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CustomPaint(painter: PuzzleThumbPainter(item.puzzle, placed: item.game.placed)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      PawBar(value: item.progress),
                      const SizedBox(height: 5),
                      Text(
                        item.course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: -8, top: -10, child: Art(difficultyArt(item.level.difficulty), size: 30)),
        ],
      ),
    );
  }
}

/// Asks whether to play today's picture in Paint or Sort mode.
void _pickDailyMode(BuildContext context, ProgressStore store, Puzzle puzzle, {required bool sortOpen}) {
  void play(PlayMode mode) => openWithTutorial(
        context,
        mode: mode,
        store: store,
        tutorial: () => mode == PlayMode.sort
            ? SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true)
            : GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
        open: () => mode == PlayMode.sort
            ? SortScreen(puzzle: puzzle, store: store, daily: true)
            : GameScreen(puzzle: puzzle, store: store, daily: true),
      );
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('How do you want to play today?', style: Theme.of(sheet).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.brush_rounded),
            title: const Text('Paint'),
            subtitle: const Text('Fill numbered spots with matching drills'),
            onTap: () {
              Navigator.pop(sheet);
              play(PlayMode.paint);
            },
          ),
          ListTile(
            leading: Icon(sortOpen ? Icons.swap_horiz_rounded : Icons.lock_rounded),
            title: const Text('Sort'),
            subtitle: Text(
              sortOpen ? 'Unscramble the picture using the tray' : unlockCondition(UnlockTables.modeSort),
            ),
            onTap: () {
              Navigator.pop(sheet);
              if (sortOpen) {
                play(PlayMode.sort);
              } else {
                showLockedHint(context, unlockCondition(UnlockTables.modeSort));
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The next 3-star reward and how close it is; opens Unlocks (PAP-38).
class _UnlockStrip extends StatelessWidget {
  const _UnlockStrip({required this.unlocks});

  final UnlockState unlocks;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final next = unlocks.nextReward;
    final reward = UnlockTables.rewardById(next?.id);
    final line = reward == null
        ? 'Every reward is yours!'
        : '${next!.remaining} more 3-star ${picturesWord(next.remaining)}: ${rewardInfo(reward).name}';
    final value = reward == null ? 1.0 : unlocks.threeStars / unlocks.threshold(reward);
    return Semantics(
      button: true,
      label: 'Unlocks. $line',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(PawRadius.pill), boxShadow: lip(t, 3)),
        child: Material(
          color: t.surface,
          shape: StadiumBorder(side: BorderSide(color: t.outline, width: 2)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openUnlocks(Navigator.of(context)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(
                children: [
                  const Art('mochi/avatar.png', size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink),
                        ),
                        const SizedBox(height: 4),
                        PawBar(value: value),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: t.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
