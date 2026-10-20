import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/courses.dart' show allCourses, unlockAfter;
import '../models/puzzle.dart';

/// Best result for a finished picture.
class PuzzleRecord {
  const PuzzleRecord({required this.bestScore, required this.bestStars, required this.bestSeconds});

  final int bestScore;
  final int bestStars;
  final int bestSeconds;

  Map<String, Object> toJson() => {'score': bestScore, 'stars': bestStars, 'seconds': bestSeconds};

  static PuzzleRecord fromJson(Map<String, dynamic> j) => PuzzleRecord(
        bestScore: j['score'] as int,
        bestStars: j['stars'] as int,
        bestSeconds: j['seconds'] as int,
      );
}

/// Best results for one Time Attack difficulty.
class TimeAttackRecord {
  const TimeAttackRecord({this.bestScore = 0, this.wins = 0, this.plays = 0, this.bestCombo = 0, this.bestLeft = 0});

  final int bestScore;
  final int wins;
  final int plays;
  final int bestCombo;

  /// Most seconds left on the clock at a win.
  final int bestLeft;

  Map<String, Object> toJson() =>
      {'score': bestScore, 'wins': wins, 'plays': plays, 'combo': bestCombo, 'left': bestLeft};

  static TimeAttackRecord fromJson(Map<String, dynamic> j) => TimeAttackRecord(
        bestScore: j['score'] as int? ?? 0,
        wins: j['wins'] as int? ?? 0,
        plays: j['plays'] as int? ?? 0,
        bestCombo: j['combo'] as int? ?? 0,
        bestLeft: j['left'] as int? ?? 0,
      );
}

/// A picture left half done, so it can be resumed later.
class SavedGame {
  const SavedGame({
    required this.signature,
    required this.placed,
    required this.score,
    required this.combo,
    required this.mistakes,
    required this.seconds,
    this.excusedMistakes = false,
  });

  /// [Puzzle.signature] of the picture this was saved from.
  final int signature;

  /// One character per cell: '1' placed, '0' empty.
  final String placed;
  final int score;
  final int combo;
  final int mistakes;
  final int seconds;

  /// Whether Relaxed mode let a wrong tap go uncounted on this board.
  final bool excusedMistakes;

  int get placedCount => '1'.allMatches(placed).length;

  Map<String, Object> toJson() => {
        'signature': signature,
        'placed': placed,
        'score': score,
        'combo': combo,
        'mistakes': mistakes,
        'seconds': seconds,
        'relaxed': excusedMistakes,
      };

  static SavedGame fromJson(Map<String, dynamic> j) => SavedGame(
        signature: j['signature'] as int,
        placed: j['placed'] as String,
        score: j['score'] as int,
        combo: j['combo'] as int,
        mistakes: j['mistakes'] as int,
        seconds: j['seconds'] as int,
        excusedMistakes: j['relaxed'] == true,
      );
}

/// The two ways to play a picture. Each keeps its own records and stars.
enum PlayMode {
  paint('Paint'),
  sort('Sort');

  const PlayMode(this.label);

  final String label;

  /// Key under which this mode's record and saved game for [puzzleId] live.
  String key(String puzzleId) => this == paint ? puzzleId : 'sort:$puzzleId';
}

/// Day key like 2026-10-19, in local time.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Daily-picture streak after finishing today's picture: it grows when the
/// last one was finished yesterday, stays when already counted today, and
/// otherwise starts over at 1.
int nextStreak({required int streak, required String? lastDone, required DateTime today}) {
  final todayKey = dayKey(today);
  if (lastDone == todayKey) return streak;
  final yesterday = dayKey(DateTime(today.year, today.month, today.day - 1));
  return lastDone == yesterday ? streak + 1 : 1;
}

/// Counts [p] toward the daily streak, but only if it is still today's
/// picture (the app may have stayed open past midnight).
Future<void> recordDailyIfToday(ProgressStore store, Puzzle p) async {
  final today = DateTime.now();
  if (store.dailyPuzzleId(today, [for (final c in allCourses) ...c.puzzles]) == p.id) await store.recordDaily(today);
}

/// Records, saved games and unlock rules, persisted on the device.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._records, this._saved, [Map<String, Map<String, dynamic>>? sortSaved])
      : _sortSaved = sortSaved ?? {};

  static const _key = 'progress_v1';
  static const _backupKey = 'progress_v1_backup';
  static const _version = 1;

  static void _parseEach(Object? map, void Function(String, Map<String, dynamic>) add) {
    if (map is! Map<String, dynamic>) return;
    map.forEach((k, v) {
      try {
        add(k, v as Map<String, dynamic>);
      } catch (_) {
        // Skip the broken entry.
      }
    });
  }

  final SharedPreferences? _prefs;
  final Map<String, PuzzleRecord> _records;
  final Map<String, SavedGame> _saved;

  /// Sort-mode boards in progress, as the JSON the sort screen saved.
  final Map<String, Map<String, dynamic>> _sortSaved;

  static Future<ProgressStore> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Without storage the game still runs; progress just isn't kept.
      debugPrint('Progress storage unavailable: $e');
      return ProgressStore.memory();
    }
    final records = <String, PuzzleRecord>{};
    final saved = <String, SavedGame>{};
    final sortSaved = <String, Map<String, dynamic>>{};
    var seenTutorial = false, seenSortTutorial = false;
    Map<String, dynamic>? daily;
    final badges = <String>[];
    final timeAttack = <String, TimeAttackRecord>{};
    var bestCombo = 0;
    String? dailyTADate;
    var dailyTA = const TimeAttackRecord();
    final raw = prefs.getString(_key);
    if (raw != null) {
      Map<String, dynamic> j;
      try {
        j = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Keep the unreadable blob so it can be recovered by hand, then start fresh.
        await prefs.setString(_backupKey, raw);
        j = const {};
      }
      // Entries are parsed one by one, so one bad entry never loses the rest.
      _parseEach(j['records'], (k, v) => records[k] = PuzzleRecord.fromJson(v));
      _parseEach(j['saved'], (k, v) => saved[k] = SavedGame.fromJson(v));
      _parseEach(j['sortSaved'], (k, v) => sortSaved[k] = v);
      seenTutorial = j['seenTutorial'] == true;
      seenSortTutorial = j['seenSortTutorial2'] == true;
      daily = j['daily'] is Map<String, dynamic> ? j['daily'] as Map<String, dynamic> : null;
      if (j['badges'] is List) badges.addAll((j['badges'] as List).whereType<String>());
      _parseEach(j['timeAttack'], (k, v) => timeAttack[k] = TimeAttackRecord.fromJson(v));
      bestCombo = j['bestCombo'] is int ? j['bestCombo'] as int : 0;
      if (j['dailyTimeAttack'] case final Map<String, dynamic> d) {
        try {
          dailyTADate = d['date'] as String?;
          dailyTA = TimeAttackRecord.fromJson(d);
        } catch (_) {}
      }
    }
    return ProgressStore._(prefs, records, saved, sortSaved)
      .._seenTutorial = seenTutorial
      .._seenSortTutorial = seenSortTutorial
      .._dailyDate = daily?['date'] as String?
      .._dailyId = daily?['id'] as String?
      .._dailyDone = daily?['done'] as String?
      .._streak = (daily?['streak'] as int?) ?? 0
      .._bestStreak = (daily?['best'] as int?) ?? 0
      .._seenBadges.addAll(badges)
      .._timeAttack.addAll(timeAttack)
      .._bestCombo = bestCombo
      .._dailyTADate = dailyTADate
      .._dailyTA = dailyTA;
  }

  /// In-memory store for tests.
  factory ProgressStore.memory() => ProgressStore._(null, {}, {});

  PuzzleRecord? record(String id) => _records[id];
  SavedGame? saved(String id) => _saved[id];

  /// The saved game for [p], only if it was saved from this exact picture.
  SavedGame? savedFor(Puzzle p) {
    final g = _saved[p.id];
    return g != null && g.signature == p.signature && g.placed.length == p.cellCount ? g : null;
  }

  // ---- Daily picture ----------------------------------------------------

  String? _dailyDate;
  String? _dailyId;
  String? _dailyDone;
  int _streak = 0;
  int _bestStreak = 0;
  final Set<String> _seenBadges = {};

  int get bestStreak => _bestStreak;
  bool hasSeenBadge(String id) => _seenBadges.contains(id);

  Future<void> markBadgesSeen(Iterable<String> ids) {
    _seenBadges.addAll(ids);
    return _persist();
  }

  /// Today's surprise picture: chosen once per day, preferring pictures not
  /// painted yet, and kept for the rest of the day.
  String dailyPuzzleId(DateTime today, List<Puzzle> all) {
    final key = dayKey(today);
    if (_dailyDate == key && _dailyId != null && all.any((p) => p.id == _dailyId)) return _dailyId!;
    final fresh = all.where((p) => !isDone(p.id)).toList();
    final pool = fresh.isEmpty ? all : fresh;
    final pick = pool[math.Random(key.hashCode).nextInt(pool.length)];
    _dailyDate = key;
    _dailyId = pick.id;
    Future.microtask(_persist);
    return pick.id;
  }

  bool dailyDoneToday(DateTime today) => _dailyDone == dayKey(today);

  /// The streak as it stands today: still alive if the last daily picture
  /// was finished today or yesterday.
  int streak(DateTime today) {
    final yesterday = dayKey(DateTime(today.year, today.month, today.day - 1));
    return _dailyDone == dayKey(today) || _dailyDone == yesterday ? _streak : 0;
  }

  Future<void> recordDaily(DateTime today) {
    _streak = nextStreak(streak: _streak, lastDone: _dailyDone, today: today);
    _dailyDone = dayKey(today);
    if (_streak > _bestStreak) _bestStreak = _streak;
    notifyListeners();
    return _persist();
  }

  // ---- Combos and Time Attack ---------------------------------------------

  final Map<String, TimeAttackRecord> _timeAttack = {};
  int _bestCombo = 0;

  /// Longest Sort combo ever reached, in any picture or Time Attack run.
  int get bestCombo => _bestCombo;

  TimeAttackRecord timeAttack(Difficulty d) => _timeAttack[d.name] ?? const TimeAttackRecord();

  /// Easy and Medium are open; each harder clock opens after a win on the one before.
  bool isTimeAttackUnlocked(Difficulty d) =>
      d.index <= Difficulty.medium.index || timeAttack(Difficulty.values[d.index - 1]).wins > 0;

  /// Remembers a combo once a picture or run ends.
  Future<void> noteCombo(int combo) {
    if (combo <= _bestCombo) return Future.value();
    _bestCombo = combo;
    notifyListeners();
    return _persist();
  }

  /// Stores a finished Time Attack run and returns true for a new best score.
  Future<bool> recordTimeAttack(Difficulty d,
      {required bool won, required int score, required int combo, required int secondsLeft}) async {
    final old = timeAttack(d);
    final isBest = won && score > old.bestScore;
    _timeAttack[d.name] = TimeAttackRecord(
      bestScore: isBest ? score : old.bestScore,
      wins: old.wins + (won ? 1 : 0),
      plays: old.plays + 1,
      bestCombo: combo > old.bestCombo ? combo : old.bestCombo,
      bestLeft: won && secondsLeft > old.bestLeft ? secondsLeft : old.bestLeft,
    );
    if (combo > _bestCombo) _bestCombo = combo;
    notifyListeners();
    await _persist();
    return isBest;
  }

  String? _dailyTADate;
  TimeAttackRecord _dailyTA = const TimeAttackRecord();

  /// How today's Time Attack challenge has gone so far.
  TimeAttackRecord dailyTimeAttack(DateTime today) =>
      _dailyTADate == dayKey(today) ? _dailyTA : const TimeAttackRecord();

  /// Stores a run of today's challenge and returns true for a new best today.
  Future<bool> recordDailyTimeAttack(DateTime today,
      {required bool won, required int score, required int combo, required int secondsLeft}) async {
    final old = dailyTimeAttack(today);
    final isBest = won && score > old.bestScore;
    _dailyTADate = dayKey(today);
    _dailyTA = TimeAttackRecord(
      bestScore: isBest ? score : old.bestScore,
      wins: old.wins + (won ? 1 : 0),
      plays: old.plays + 1,
      bestCombo: combo > old.bestCombo ? combo : old.bestCombo,
      bestLeft: won && secondsLeft > old.bestLeft ? secondsLeft : old.bestLeft,
    );
    notifyListeners();
    await _persist();
    return isBest;
  }

  bool get seenSortTutorial => _seenSortTutorial;
  bool _seenSortTutorial = false;

  Future<void> markSortTutorialSeen() {
    _seenSortTutorial = true;
    return _persist();
  }

  bool get seenTutorial => _seenTutorial;
  bool _seenTutorial = false;

  Future<void> markTutorialSeen() {
    _seenTutorial = true;
    return _persist();
  }

  bool isCompleted(String id) => _records.containsKey(id);

  /// Finished in [mode], or in either mode when [mode] is null.
  bool isDone(String puzzleId, [PlayMode? mode]) =>
      (mode == null ? PlayMode.values : [mode]).any((m) => isCompleted(m.key(puzzleId)));

  /// Pictures finished in [mode], or in either mode when [mode] is null.
  int completedIn(List<Puzzle> puzzles, [PlayMode? mode]) => puzzles.where((p) => isDone(p.id, mode)).length;

  /// Best stars in [mode], or Paint and Sort stars added up when [mode] is null.
  int starsIn(List<Puzzle> puzzles, [PlayMode? mode]) => puzzles.fold(
        0,
        (sum, p) =>
            sum +
            (mode == null ? PlayMode.values : [mode]).fold(0, (s, m) => s + (_records[m.key(p.id)]?.bestStars ?? 0)),
      );

  /// Stars [starsIn] can reach for [puzzles].
  static int maxStarsIn(List<Puzzle> puzzles, [PlayMode? mode]) =>
      puzzles.length * 3 * (mode == null ? PlayMode.values.length : 1);

  /// Easy is always open; a harder level opens after [unlockAfter] finished
  /// pictures in the level before it (in [mode], or in either mode when null).
  bool isLevelUnlocked(Course c, int index, [PlayMode? mode]) =>
      index == 0 ||
      (mode == null ? PlayMode.values : [mode]).any((m) => completedIn(c.levels[index - 1].puzzles, m) >= unlockAfter);

  /// Inside a level, a picture opens when the one before it is finished
  /// (or once it has been finished or started).
  bool isPuzzleUnlocked(Level level, int index, [PlayMode mode = PlayMode.paint]) {
    final id = mode.key(level.puzzles[index].id);
    return index == 0 ||
        isCompleted(mode.key(level.puzzles[index - 1].id)) ||
        isCompleted(id) ||
        _saved.containsKey(id) ||
        _sortSaved.containsKey(id);
  }

  Map<String, dynamic>? sortSaved(String puzzleId) => _sortSaved[PlayMode.sort.key(puzzleId)];

  Future<void> saveSort(String puzzleId, Map<String, dynamic> state) {
    _sortSaved[PlayMode.sort.key(puzzleId)] = state;
    notifyListeners();
    return _persist();
  }

  Future<void> saveGame(String id, SavedGame game) {
    _saved[id] = game;
    notifyListeners();
    return _persist();
  }

  /// Stores a finished picture and returns true when it beats the old best score.
  Future<bool> recordCompletion(String id, {required int score, required int stars, required int seconds}) async {
    final old = _records[id];
    final isBest = old == null || score > old.bestScore;
    _records[id] = PuzzleRecord(
      bestScore: isBest ? score : old.bestScore,
      bestStars: old == null || stars > old.bestStars ? stars : old.bestStars,
      bestSeconds: old == null || seconds < old.bestSeconds ? seconds : old.bestSeconds,
    );
    _saved.remove(id);
    _sortSaved.remove(id);
    notifyListeners();
    await _persist();
    return isBest;
  }

  Future<void> resetPuzzle(String id) {
    _saved.remove(id);
    _sortSaved.remove(id);
    notifyListeners();
    return _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _key,
        jsonEncode({
          'version': _version,
          'seenTutorial': _seenTutorial,
          // v2: Sort became tap to pick up and drop, so everyone sees the new tutorial once.
          'seenSortTutorial2': _seenSortTutorial,
          'daily': {'date': _dailyDate, 'id': _dailyId, 'done': _dailyDone, 'streak': _streak, 'best': _bestStreak},
          'badges': _seenBadges.toList(),
          'records': _records.map((k, v) => MapEntry(k, v.toJson())),
          'saved': _saved.map((k, v) => MapEntry(k, v.toJson())),
          'sortSaved': _sortSaved,
          'timeAttack': _timeAttack.map((k, v) => MapEntry(k, v.toJson())),
          'bestCombo': _bestCombo,
          'dailyTimeAttack': {'date': _dailyTADate, ..._dailyTA.toJson()},
        }),
      );
    } catch (e) {
      // A failed write keeps the in-memory progress; the next save retries.
      debugPrint('Saving progress failed: $e');
    }
  }
}

/// Makes the [ProgressStore] available to the widget tree.
class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({super.key, required ProgressStore store, required super.child}) : super(notifier: store);

  static ProgressStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}
