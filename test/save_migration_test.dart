import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/boosters.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A store that reports a failed write for one key, the way Android does on a full disk.
class _RefusesKey extends InMemorySharedPreferencesStore {
  _RefusesKey(this.key, Map<String, Object> data) : super.withData(data);

  final String key;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      key == this.key ? false : super.setValue(valueType, key, value);
}

/// A version-1 save shaped like the ones the app wrote before PAP-15: every key
/// of `_writeOnce`, few stars, and some Time Attack and daily history.
Map<String, dynamic> v1Save({Object? version = 1, Map<String, dynamic> extra = const {}}) {
  final ids = buildCourses().first.puzzles.map((p) => p.id).toList();
  return {
    if (version != null) 'version': version,
    'seenTutorial': true,
    'seenSortTutorial2': true,
    'daily': {'date': '2026-11-09', 'id': ids[3], 'done': '2026-11-09', 'streak': 4, 'best': 6},
    'badges': ['first', 'wide'],
    'records': {
      ids[0]: {'score': 900, 'stars': 3, 'seconds': 80},
      'sort:${ids[0]}': {'score': 700, 'stars': 2, 'seconds': 95},
      ids[1]: {'score': 500, 'stars': 1, 'seconds': 120},
    },
    'saved': {
      ids[2]: {
        'signature': 12345,
        'placed': '0,1,2,,,5',
        'score': 120,
        'combo': 3,
        'mistakes': 1,
        'seconds': 44,
        'relaxed': true,
        'brush': 7,
        'order': [3, 1, 2],
      },
    },
    'sortSaved': {
      'sort:${ids[4]}': {
        'board': [1, 2, 3],
        'tray': [4],
        'moves': 9
      },
    },
    'timeAttack': {
      'easy': {'score': 400, 'wins': 2, 'plays': 3, 'combo': 5, 'left': 20},
    },
    'bestCombo': 9,
    'dailyTimeAttack': {'date': '2026-11-09', 'score': 0, 'wins': 0, 'plays': 0, 'combo': 0, 'left': 0},
    'boosters': {'bomb': 5, 'brush': 1, 'wand': 0},
    ...extra,
  };
}

Future<SharedPreferences> seed(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Map<String, dynamic> readSave(SharedPreferences prefs) =>
    jsonDecode(prefs.getString('progress_v1')!) as Map<String, dynamic>;

void main() {
  final courses = buildCourses();

  group('version 1 save', () {
    test('keeps every field, opens everything it had, and saves as version 2', () async {
      final original = v1Save();
      final prefs = await seed({'progress_v1': jsonEncode(original)});
      final store = await ProgressStore.load(gatesEnforced: true);

      expect(store.isReadOnly, isFalse);
      expect(store.record(original['records'].keys.first as String)?.bestStars, 3);
      expect(store.bestStreak, 6);
      expect(store.bestCombo, 9);
      expect(store.timeAttack(Difficulty.easy).wins, 2);
      expect(store.boosters(Booster.bomb), 5);
      expect(store.seenTutorial, isTrue);
      expect(store.hasSeenBadge('wide'), isTrue);

      // Nothing she could play before is locked, even with only 4 stars.
      final s = store.unlockState(courses);
      for (final c in courses) {
        expect(s.isCourseOpen(c.id), isTrue, reason: c.id);
      }
      expect(s.isModeOpen(UnlockTables.modeSort), isTrue);
      expect(s.isModeOpen(UnlockTables.modeTimeAttack), isTrue);
      expect(s.isModeOpen(UnlockTables.modeDaily), isTrue);
      for (final b in Booster.values) {
        expect(s.isBoosterOpen(b), isTrue);
      }
      expect(s.catchUp, containsAll(UnlockTables.legacyIds), reason: 'one catch-up summary');

      await store.noteCombo(12);
      final saved = readSave(prefs);
      expect(saved['version'], 2);
      expect(saved['bestCombo'], 12);
      for (final k in original.keys.where((k) => k != 'version' && k != 'bestCombo')) {
        expect(saved[k], original[k], reason: 'key $k kept as it was');
      }
      expect(saved['celebrated'], isEmpty);
      expect(saved['secrets'], isEmpty);
      expect(saved['streakBonusPaid'], 0);
      expect(saved['keptOpen'], containsAll(UnlockTables.legacyIds));
    });

    test('rewards a version 1 save already earned stay earned when the build grows', () async {
      final ids = buildCourses(store: true).first.puzzles.map((p) => p.id).take(3);
      final save = v1Save(extra: {
        'records': {
          for (final id in ids) id: {'score': 1, 'stars': 3, 'seconds': 1},
        },
      });
      final prefs = await seed({'progress_v1': jsonEncode(save)});
      // A 100-picture build: Sakura needs 3 pictures there, 5 at 160.
      final store = await ProgressStore.load(pictureCount: 100);
      expect(store.unlockState(buildCourses(store: true)).unlocked, contains('reward.bg.sakura'));
      await store.noteCombo(12);
      expect(readSave(prefs)['keptOpen'], contains('reward.bg.sakura'));
      final grown = await ProgressStore.load();
      expect(grown.unlockState(courses).unlocked, contains('reward.bg.sakura'));
    });

    test('keeps a raw copy of the old save once', () async {
      final prefs = await seed({'progress_v1': jsonEncode(v1Save())});
      final raw = prefs.getString('progress_v1');
      final store = await ProgressStore.load();
      await store.noteCombo(12);
      expect(prefs.getString('progress_v1_backup_v1'), raw);

      // A second load of the version-2 save leaves that copy alone.
      await ProgressStore.load();
      expect(prefs.getString('progress_v1_backup_v1'), raw);
    });

    test('a save with no version field is version 1', () async {
      await seed({'progress_v1': jsonEncode(v1Save(version: null))});
      final store = await ProgressStore.load(gatesEnforced: true);
      expect(store.isReadOnly, isFalse);
      expect(store.unlockState(courses).isCourseOpen('catcafe'), isTrue);
    });

    test('the legacy gates survive a second launch', () async {
      await seed({'progress_v1': jsonEncode(v1Save())});
      final first = await ProgressStore.load(gatesEnforced: true);
      await first.noteCombo(12);
      final second = await ProgressStore.load(gatesEnforced: true);
      expect(second.unlockState(courses).isCourseOpen('catcafe'), isTrue);
      expect(second.unlockState(courses).isModeOpen(UnlockTables.modeTimeAttack), isTrue);
      for (final b in Booster.values) {
        expect(second.unlockState(courses).isBoosterOpen(b), isTrue);
      }
    });
  });

  group('fresh and new data', () {
    test('once the UI follows the gates, a fresh install saves as version 2 with gates closed', () async {
      final prefs = await seed({});
      final store = await ProgressStore.load(gatesEnforced: true);
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeSort), isFalse);
      await store.markTutorialSeen();
      final saved = readSave(prefs);
      expect(saved['version'], 2);
      expect(saved['keptOpen'], isEmpty);
      expect(prefs.getString('progress_v1_backup_v1'), isNull);
    });

    test('while the UI shows everything, every save keeps it open for later', () async {
      final prefs = await seed({});
      expect(UnlockTables.gatesEnforced, isFalse, reason: 'PAP-41 flips this; then rewrite this test');
      final store = await ProgressStore.load();
      await store.markTutorialSeen();
      expect(readSave(prefs)['keptOpen'], containsAll(UnlockTables.legacyIds));
      // The gates it could play stay open when they are enforced later.
      final later = await ProgressStore.load(gatesEnforced: true);
      expect(later.unlockState(courses).isCourseOpen('catcafe'), isTrue);
      expect(later.unlockState(courses).isModeOpen(UnlockTables.modeTimeAttack), isTrue);
    });

    test('secrets, celebrated and the streak bonus survive a reload', () async {
      await seed({});
      final store = await ProgressStore.load();
      await store.addSecret('mochi');
      await store.markCelebrated({'course.garden', 'mode.sort'});
      await store.setStreakBonusPaid(2);
      final again = await ProgressStore.load();
      expect(again.secrets, {'mochi'});
      expect(again.celebrated, {'course.garden', 'mode.sort'});
      expect(again.streakBonusPaid, 2);
    });
  });

  group('save safety', () {
    test('unknown top-level keys survive load and save', () async {
      final prefs = await seed({
        'progress_v1': jsonEncode(v1Save(version: 2, extra: {
          'future': {
            'a': [1, 2]
          },
          'flag': true
        })),
      });
      final store = await ProgressStore.load();
      await store.noteCombo(12);
      final saved = readSave(prefs);
      expect(saved['future'], {
        'a': [1, 2]
      });
      expect(saved['flag'], isTrue);
      expect(saved['version'], 2);
    });

    test('a newer save is read but never written over', () async {
      final raw = jsonEncode(v1Save(version: 3, extra: {'future': 1}));
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.bestCombo, 9);
      await store.noteCombo(50);
      await store.markTutorialSeen();
      expect(prefs.getString('progress_v1'), raw);
      expect(prefs.getString('progress_v1_backup_v1'), isNull);
    });

    test('when the old-save copy cannot be written, the save is left alone', () async {
      final raw = jsonEncode(v1Save());
      SharedPreferencesStorePlatform.instance = _RefusesKey(
        'flutter.progress_v1_backup_v1',
        {'flutter.progress_v1': raw},
      );
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      await store.noteCombo(50);
      expect(prefs.getString('progress_v1'), raw);
      // Her gates are still judged as before in this session.
      expect(store.unlockState(courses).isCourseOpen('catcafe'), isTrue);
    });

    test('a newer save keeps the gates it recorded open', () async {
      final raw = jsonEncode(v1Save(version: 3, extra: {'keptOpen': UnlockTables.legacyIds.toList()}));
      await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.unlockState(courses).isCourseOpen('catcafe'), isTrue);
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeTimeAttack), isTrue);
    });

    test('migrating again after a downgrade refreshes the version 1 copy', () async {
      final newer = jsonEncode(v1Save(extra: {'bestCombo': 33}));
      final prefs = await seed({'progress_v1': newer, 'progress_v1_backup_v1': jsonEncode(v1Save())});
      await ProgressStore.load();
      expect(prefs.getString('progress_v1_backup_v1'), newer);
    });

    test('a version that is not a number is never written over', () async {
      final raw = jsonEncode(v1Save(version: 'two'));
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      await store.noteCombo(50);
      expect(prefs.getString('progress_v1'), raw);
    });

    test('a broken entry is backed up before the next save drops it', () async {
      final broken = v1Save();
      broken['records'] = {...(broken['records'] as Map), 'bad': 'not a record'};
      final raw = jsonEncode(broken);
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      await store.noteCombo(12);
      expect(prefs.getString('progress_v1_backup'), raw);
      expect(readSave(prefs)['records'], isNot(contains('bad')));
    });

    test('when an unreadable save cannot be copied, nothing is written over it', () async {
      SharedPreferencesStorePlatform.instance = _RefusesKey(
        'flutter.progress_v1_unreadable',
        {'flutter.progress_v1': '{not json'},
      );
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      await store.noteCombo(50);
      expect(prefs.getString('progress_v1'), '{not json');
    });

    test('an unreadable save is backed up and the game starts fresh', () async {
      final prefs = await seed({'progress_v1': '{not json'});
      final store = await ProgressStore.load(gatesEnforced: true);
      expect(store.isReadOnly, isFalse);
      expect(prefs.getString('progress_v1_unreadable'), '{not json');
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeSort), isFalse);
    });
  });
}
