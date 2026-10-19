import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/courses.dart' show unlockAfter;
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

/// A picture left half done, so it can be resumed later.
class SavedGame {
  const SavedGame({
    required this.signature,
    required this.placed,
    required this.score,
    required this.combo,
    required this.mistakes,
    required this.seconds,
  });

  /// [Puzzle.signature] of the picture this was saved from.
  final int signature;

  /// One character per cell: '1' placed, '0' empty.
  final String placed;
  final int score;
  final int combo;
  final int mistakes;
  final int seconds;

  int get placedCount => '1'.allMatches(placed).length;

  Map<String, Object> toJson() => {
        'signature': signature,
        'placed': placed,
        'score': score,
        'combo': combo,
        'mistakes': mistakes,
        'seconds': seconds
      };

  static SavedGame fromJson(Map<String, dynamic> j) => SavedGame(
        signature: j['signature'] as int,
        placed: j['placed'] as String,
        score: j['score'] as int,
        combo: j['combo'] as int,
        mistakes: j['mistakes'] as int,
        seconds: j['seconds'] as int,
      );
}

/// Records, saved games and unlock rules, persisted on the device.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._records, this._saved);

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

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final records = <String, PuzzleRecord>{};
    final saved = <String, SavedGame>{};
    var seenTutorial = false;
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
      seenTutorial = j['seenTutorial'] == true;
    }
    return ProgressStore._(prefs, records, saved).._seenTutorial = seenTutorial;
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

  bool get seenTutorial => _seenTutorial;
  bool _seenTutorial = false;

  Future<void> markTutorialSeen() {
    _seenTutorial = true;
    return _persist();
  }

  bool isCompleted(String id) => _records.containsKey(id);

  int completedIn(List<Puzzle> puzzles) => puzzles.where((p) => isCompleted(p.id)).length;
  int starsIn(List<Puzzle> puzzles) => puzzles.fold(0, (sum, p) => sum + (_records[p.id]?.bestStars ?? 0));

  /// Easy is always open; a harder level opens after [unlockAfter] finished
  /// pictures in the level before it.
  bool isLevelUnlocked(Course c, int index) => index == 0 || completedIn(c.levels[index - 1].puzzles) >= unlockAfter;

  /// Inside a level, a picture opens when the one before it is finished
  /// (or once it has been finished or started).
  bool isPuzzleUnlocked(Level level, int index) {
    final id = level.puzzles[index].id;
    return index == 0 || isCompleted(level.puzzles[index - 1].id) || isCompleted(id) || _saved.containsKey(id);
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
    notifyListeners();
    await _persist();
    return isBest;
  }

  Future<void> resetPuzzle(String id) {
    _saved.remove(id);
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
          'records': _records.map((k, v) => MapEntry(k, v.toJson())),
          'saved': _saved.map((k, v) => MapEntry(k, v.toJson())),
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
