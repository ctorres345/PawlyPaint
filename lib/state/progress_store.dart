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
    required this.placed,
    required this.score,
    required this.combo,
    required this.mistakes,
    required this.seconds,
  });

  /// One character per cell: '1' placed, '0' empty.
  final String placed;
  final int score;
  final int combo;
  final int mistakes;
  final int seconds;

  int get placedCount => '1'.allMatches(placed).length;

  Map<String, Object> toJson() =>
      {'placed': placed, 'score': score, 'combo': combo, 'mistakes': mistakes, 'seconds': seconds};

  static SavedGame fromJson(Map<String, dynamic> j) => SavedGame(
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

  final SharedPreferences? _prefs;
  final Map<String, PuzzleRecord> _records;
  final Map<String, SavedGame> _saved;

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final records = <String, PuzzleRecord>{};
    final saved = <String, SavedGame>{};
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        (j['records'] as Map<String, dynamic>? ?? {})
            .forEach((k, v) => records[k] = PuzzleRecord.fromJson(v as Map<String, dynamic>));
        (j['saved'] as Map<String, dynamic>? ?? {})
            .forEach((k, v) => saved[k] = SavedGame.fromJson(v as Map<String, dynamic>));
      } catch (_) {
        // Unreadable progress starts fresh rather than crashing the app.
      }
    }
    return ProgressStore._(prefs, records, saved);
  }

  /// In-memory store for tests.
  factory ProgressStore.memory() => ProgressStore._(null, {}, {});

  PuzzleRecord? record(String id) => _records[id];
  SavedGame? saved(String id) => _saved[id];
  bool isCompleted(String id) => _records.containsKey(id);

  int completedIn(Course c) => c.puzzles.where((p) => isCompleted(p.id)).length;
  int starsIn(Course c) => c.puzzles.fold(0, (sum, p) => sum + (_records[p.id]?.bestStars ?? 0));

  bool isCourseUnlocked(List<Course> courses, int index) =>
      index == 0 || completedIn(courses[index - 1]) >= unlockAfter;

  bool isPuzzleUnlocked(Course c, int index) =>
      index == 0 || isCompleted(c.puzzles[index - 1].id) || isCompleted(c.puzzles[index].id) || _saved.containsKey(c.puzzles[index].id);

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
    await prefs.setString(
      _key,
      jsonEncode({
        'records': _records.map((k, v) => MapEntry(k, v.toJson())),
        'saved': _saved.map((k, v) => MapEntry(k, v.toJson())),
      }),
    );
  }
}

/// Makes the [ProgressStore] available to the widget tree.
class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({super.key, required ProgressStore store, required super.child}) : super(notifier: store);

  static ProgressStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}
