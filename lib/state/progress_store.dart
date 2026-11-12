import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/courses.dart' show allCourses, unlockAfter;
import '../logic/boosters.dart';
import '../logic/unlocks.dart';
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
    this.brushColor,
    this.order = const [],
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

  /// The color a wide brush was working on, so leaving doesn't waste it.
  final int? brushColor;

  /// Cells in the order they were filled, for the replay at the end.
  final List<int> order;

  int get placedCount => '1'.allMatches(placed).length;

  Map<String, Object> toJson() => {
        'signature': signature,
        'placed': placed,
        'score': score,
        'combo': combo,
        'mistakes': mistakes,
        'seconds': seconds,
        'relaxed': excusedMistakes,
        if (brushColor != null) 'brush': brushColor!,
        if (order.isNotEmpty) 'order': order,
      };

  static SavedGame fromJson(Map<String, dynamic> j) => SavedGame(
        signature: j['signature'] as int,
        placed: j['placed'] as String,
        score: j['score'] as int,
        combo: j['combo'] as int,
        mistakes: j['mistakes'] as int,
        seconds: j['seconds'] as int,
        excusedMistakes: j['relaxed'] == true,
        brushColor: j['brush'] as int?,
        order: j['order'] is List ? (j['order'] as List).whereType<int>().toList() : const [],
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
  ProgressStore._(
    this._prefs,
    this._records,
    this._saved, [
    Map<String, Map<String, dynamic>>? sortSaved,
    int? pictureCount,
  ])  : _sortSaved = sortSaved ?? {},
        _pictureCount = pictureCount ?? _countPictures(allCourses);

  static int _countPictures(List<Course> courses) => courses.fold(0, (n, c) => n + c.puzzles.length);

  /// Pictures the running build ships, for scaling rewards when a picture is finished.
  final int _pictureCount;

  static const _key = 'progress_v1';
  static const _backupKey = 'progress_v1_backup';

  /// Raw copy of a save that could not be read at all.
  static const _unreadableKey = 'progress_v1_unreadable';

  /// Raw copy of a version-1 save, kept once before the first version-2 write.
  static const _v1BackupKey = 'progress_v1_backup_v1';

  /// Save format version. Any change to the shape of a record, saved game or
  /// other entry must bump it: unknown keys survive only at the top level.
  static const _version = 2;

  /// Top-level keys this build reads. Any other key is kept as it is and written back.
  static const _knownKeys = {
    'version',
    'seenTutorial',
    'seenSortTutorial2',
    'daily',
    'badges',
    'records',
    'saved',
    'sortSaved',
    'timeAttack',
    'bestCombo',
    'dailyTimeAttack',
    'boosters',
    'secrets',
    'celebrated',
    'streakBonusPaid',
    'keptOpen',
  };

  /// Parses each entry on its own and returns how many were skipped.
  static int _parseEach(Object? map, void Function(String, Map<String, dynamic>) add) {
    if (map is! Map<String, dynamic>) return map == null ? 0 : 1; // A whole section of the wrong type is skipped too.
    var skipped = 0;
    map.forEach((k, v) {
      try {
        add(k, v as Map<String, dynamic>);
      } catch (_) {
        skipped++; // Skip the broken entry.
      }
    });
    return skipped;
  }

  static Set<String> _stringSet(Object? list) => list is List ? list.whereType<String>().toSet() : <String>{};

  final SharedPreferences? _prefs;
  final Map<String, PuzzleRecord> _records;
  final Map<String, SavedGame> _saved;

  /// Sort-mode boards in progress, as the JSON the sort screen saved.
  final Map<String, Map<String, dynamic>> _sortSaved;

  // ---- Unlocks ------------------------------------------------------------

  /// True when the save came from a newer build (or its version can't be read).
  /// It is shown as far as we understand it and never written over.
  bool _readOnly = false;
  bool get isReadOnly => _readOnly;

  /// Top-level keys from a newer build, written back as they were.
  final Map<String, dynamic> _extra = {};

  final Set<String> _secrets = {};
  final Set<String> _celebrated = {};
  final Set<String> _keptOpen = {};
  int _streakBonusPaid = 0;

  Set<String> get secrets => Set.unmodifiable(_secrets);
  Set<String> get celebrated => Set.unmodifiable(_celebrated);

  /// Days of the 7-day booster bonus already paid (PAP-49).
  int get streakBonusPaid => _streakBonusPaid;

  Future<void> addSecret(String id) {
    if (!_secrets.add(id)) return Future.value();
    notifyListeners();
    return _persist();
  }

  Future<void> markCelebrated(Iterable<String> ids) {
    final before = _celebrated.length;
    _celebrated.addAll(ids);
    if (_celebrated.length == before) return Future.value();
    notifyListeners();
    return _persist();
  }

  Future<void> setStreakBonusPaid(int value) {
    if (value == _streakBonusPaid) return Future.value();
    _streakBonusPaid = value;
    notifyListeners();
    return _persist();
  }

  /// What is unlocked for a build that ships [courses]. Pass the build's full
  /// course list: rewards scale with its picture count. Every record counts,
  /// hidden courses included, so this reads the records and not the course lists.
  UnlockState unlockState(List<Course> courses) => _evaluate(_countPictures(courses));

  UnlockState _evaluate(int pictureCount) {
    final threeStar = <String>{};
    final bestStars = <String, int>{};
    final finished = <String>{};
    var paint = 0, sort = 0;
    _records.forEach((key, r) {
      final isSort = key.startsWith('sort:');
      final id = isSort ? key.substring(5) : key;
      isSort ? sort++ : paint++;
      finished.add(id);
      if (r.bestStars >= 3) threeStar.add(id);
      if (r.bestStars > (bestStars[id] ?? 0)) bestStars[id] = r.bestStars;
    });
    return Unlocks.evaluate(UnlockInput(
      threeStarPictures: threeStar,
      finishedPaint: paint,
      finishedSort: sort,
      finishedAny: finished.length,
      gateStars: bestStars.values.fold(0, (a, b) => a + b),
      pictureCount: pictureCount,
      keptOpen: _keptOpen,
      celebrated: _celebrated,
    ));
  }

  static Future<ProgressStore> load({
    int? pictureCount,
    bool gatesEnforced = UnlockTables.gatesEnforced,
  }) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Without storage the game still runs; progress just isn't kept.
      debugPrint('Progress storage unavailable: $e');
      return ProgressStore.memory(pictureCount: pictureCount);
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
    Map<Booster, int>? boosters;
    var readOnly = false;
    var secrets = <String>{}, celebrated = <String>{}, keptOpen = <String>{};
    var streakBonusPaid = 0;
    final extra = <String, dynamic>{};
    final raw = prefs.getString(_key);
    if (raw != null) {
      Map<String, dynamic> j;
      var readable = true;
      try {
        j = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Keep the unreadable blob so it can be recovered by hand, then start fresh.
        // If the copy can't be stored, nothing is written this session: the blob is all there is.
        try {
          if (!await prefs.setString(_unreadableKey, raw)) throw StateError('the write returned false');
        } catch (e) {
          debugPrint('Saving the unreadable progress failed: $e');
          readOnly = true;
        }
        j = const {};
        readable = false;
      }
      // A save from a newer build (or with a version we can't read) is loaded
      // as far as we understand it but never written over.
      final version = j['version'];
      if (readable && (version != null && (version is! int || version > _version))) {
        readOnly = true;
        // Nothing in the UI says so yet (PAP-41), so leave a trace.
        debugPrint('Progress is from a newer build (version $version): shown, but not saved.');
      }
      // Entries are parsed one by one, so one bad entry never loses the rest.
      final skipped = _parseEach(j['records'], (k, v) => records[k] = PuzzleRecord.fromJson(v)) +
          _parseEach(j['saved'], (k, v) => saved[k] = SavedGame.fromJson(v)) +
          _parseEach(j['sortSaved'], (k, v) => sortSaved[k] = v) +
          _parseEach(j['timeAttack'], (k, v) => timeAttack[k] = TimeAttackRecord.fromJson(v));
      if (skipped > 0 && prefs.getString(_backupKey) == null) {
        // The next save would drop the broken entries for good, so keep a copy first.
        try {
          await prefs.setString(_backupKey, raw);
        } catch (e) {
          debugPrint('Saving the progress backup failed: $e');
        }
      }
      if (readable && !readOnly && (version == null || (version is int && version <= 1))) {
        // Version 1 had every gate open, so it keeps them open. Keep a raw copy
        // first; without it the save stays untouched this session.
        keptOpen = UnlockTables.legacyIds;
        try {
          // Always the latest version-1 save: after a downgrade it is the one worth keeping.
          // Android reports a failed write (a full disk, say) as false, not as an error.
          if (!await prefs.setString(_v1BackupKey, raw)) throw StateError('the write returned false');
        } catch (e) {
          debugPrint('Saving the version 1 backup failed: $e');
          readOnly = true;
        }
      } else if (readable) {
        // Also for a save we won't write over: its gates still count.
        keptOpen = _stringSet(j['keptOpen']);
      }
      secrets = _stringSet(j['secrets']);
      celebrated = _stringSet(j['celebrated']);
      streakBonusPaid = j['streakBonusPaid'] is int ? j['streakBonusPaid'] as int : 0;
      j.forEach((k, v) {
        if (!_knownKeys.contains(k)) extra[k] = v;
      });
      seenTutorial = j['seenTutorial'] == true;
      seenSortTutorial = j['seenSortTutorial2'] == true;
      daily = j['daily'] is Map<String, dynamic> ? j['daily'] as Map<String, dynamic> : null;
      if (j['badges'] is List) badges.addAll((j['badges'] as List).whereType<String>());
      bestCombo = j['bestCombo'] is int ? j['bestCombo'] as int : 0;
      if (j['dailyTimeAttack'] case final Map<String, dynamic> d) {
        try {
          dailyTADate = d['date'] as String?;
          dailyTA = TimeAttackRecord.fromJson(d);
        } catch (_) {}
      }
      if (j['boosters'] case final Map<String, dynamic> b) {
        boosters = {for (final k in Booster.values) k: b[k.name] is int ? b[k.name] as int : 0};
      }
    }
    // Until the UI follows the gates everything is playable, so every save keeps it open.
    if (!gatesEnforced && !readOnly) keptOpen = {...keptOpen, ...UnlockTables.legacyIds};
    final store = ProgressStore._(prefs, records, saved, sortSaved, pictureCount)
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
      .._dailyTA = dailyTA
      .._boosters.addAll(boosters ?? Booster.starter)
      .._readOnly = readOnly
      .._secrets.addAll(secrets)
      .._celebrated.addAll(celebrated)
      .._keptOpen.addAll(keptOpen)
      .._streakBonusPaid = streakBonusPaid
      .._extra.addAll(extra);
    // Rewards a save already qualifies for stay earned if the build grows before the next picture.
    store._keepEarnedRewards();
    return store;
  }

  void _keepEarnedRewards() =>
      _keptOpen.addAll(_evaluate(_pictureCount).unlocked.where((u) => u.startsWith('reward.')));

  /// In-memory store for tests.
  factory ProgressStore.memory({int? pictureCount}) =>
      ProgressStore._(null, {}, {}, null, pictureCount).._boosters.addAll(Booster.starter);

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

  // ---- Boosters -----------------------------------------------------------

  final Map<Booster, int> _boosters = {};

  int boosters(Booster b) => _boosters[b] ?? 0;

  /// Spends one [b]; false when there is none left.
  bool useBooster(Booster b) {
    if (boosters(b) <= 0) return false;
    _boosters[b] = boosters(b) - 1;
    notifyListeners();
    _persist();
    return true;
  }

  Future<void> addBoosters(Map<Booster, int> gift) {
    gift.forEach((b, n) => _boosters[b] = boosters(b) + n);
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
    // Rewards scale with the build, so keep each one once earned: a bigger build must not take it back.
    _keepEarnedRewards();
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

  Future<void>? _writing;
  bool _dirty = false;

  /// Writes the whole store. Finishing a picture saves several things at
  /// once, so a save requested while one is in flight waits for it and
  /// then writes the newest state in a single pass.
  Future<void> _persist() {
    final pending = _writing;
    if (pending != null) {
      _dirty = true;
      return pending;
    }
    return _writing = _write();
  }

  Future<void> _write() async {
    do {
      _dirty = false;
      await _writeOnce();
    } while (_dirty);
    _writing = null;
  }

  /// How many times the store has been written, for tests.
  @visibleForTesting
  int writes = 0;

  Future<void> _writeOnce() async {
    final prefs = _prefs;
    if (prefs == null || _readOnly) return;
    writes++;
    try {
      final stored = await prefs.setString(
        _key,
        jsonEncode({
          ..._extra,
          'version': _version,
          'seenTutorial': _seenTutorial,
          // The "2" in this key is the Sort tutorial: Sort became tap to pick up and drop,
          // so everyone sees the new tutorial once. It is not the save format version.
          'seenSortTutorial2': _seenSortTutorial,
          'daily': {'date': _dailyDate, 'id': _dailyId, 'done': _dailyDone, 'streak': _streak, 'best': _bestStreak},
          'badges': _seenBadges.toList(),
          'records': _records.map((k, v) => MapEntry(k, v.toJson())),
          'saved': _saved.map((k, v) => MapEntry(k, v.toJson())),
          'sortSaved': _sortSaved,
          'timeAttack': _timeAttack.map((k, v) => MapEntry(k, v.toJson())),
          'bestCombo': _bestCombo,
          'dailyTimeAttack': {'date': _dailyTADate, ..._dailyTA.toJson()},
          'boosters': {for (final b in Booster.values) b.name: boosters(b)},
          'secrets': _secrets.toList(),
          'celebrated': _celebrated.toList(),
          'streakBonusPaid': _streakBonusPaid,
          'keptOpen': _keptOpen.toList(),
        }),
      );
      // Android reports a failed write (a full disk, say) as false, not as an error.
      if (!stored) debugPrint('Saving progress failed: the write returned false');
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
