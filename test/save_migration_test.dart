import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/boosters.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages -- transitive; the failing store below needs it. PAP-72 declares it.
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

/// Settings, music and player keys live beside the progress blob and must survive the reset.
const settingsKeys = <String, Object>{
  'relaxed_mode': true,
  'haptics_on': false,
  'canvas_theme': 'night',
  'drill_shape': 'heart',
  'photo_frame': 'gold',
  'theme_mode': 'dark',
  'player_name': 'Mochi',
  'player_title': 'collector',
  'music_muted': true,
  'music_choice': 'lofi',
  'sfx_on': false,
  'music_volume': 0.4,
  'sfx_volume': 0.6,
};

/// A version-2 save with something in every section, an unknown key and both tutorials done.
Map<String, dynamic> v2Save() => v1Save(version: 2, extra: {
      'secrets': ['mochi'],
      'celebrated': ['course.garden'],
      'streakBonusPaid': 2,
      'keptOpen': UnlockTables.legacyIds.toList(),
      'introduced': [UnlockTables.modeSort],
      'daysPlayed': ['2026-11-08', '2026-11-09'],
      'future': {'a': 1},
    });

/// What a fresh install writes on its first save, with both tutorials done.
Future<Map<String, dynamic>> freshInstallSave() async {
  final prefs = await seed({});
  final store = await ProgressStore.load();
  await store.markTutorialSeen();
  await store.markSortTutorialSeen();
  return readSave(prefs);
}

void main() {
  final courses = buildCourses();

  group('fresh paint reset (save v3)', () {
    test('a version 2 save starts over like a fresh install, keeping the tutorials', () async {
      final fresh = await freshInstallSave();
      final raw = jsonEncode(v2Save());
      final prefs = await seed({'progress_v1': raw, ...settingsKeys});
      final store = await ProgressStore.load();

      expect(store.isReadOnly, isFalse);
      expect(store.freshPaintPending, isTrue);
      expect(store.seenTutorial, isTrue);
      expect(store.seenSortTutorial, isTrue);
      expect(prefs.getString('progress_v1_before_reset'), raw, reason: 'raw old save, byte for byte');

      // Written inside load(), not on the next save.
      final saved = readSave(prefs);
      expect(saved['version'], 3);
      expect(saved['freshPaintCard'], isTrue);
      expect(saved, isNot(contains('future')), reason: 'unknown keys live only in the backup');
      expect({...saved}..remove('freshPaintCard'), fresh);
      for (final e in settingsKeys.entries) {
        expect(prefs.get(e.key), e.value, reason: e.key);
      }
    });

    test('a version 1 save ends in the same state and its old copy is not rewritten', () async {
      final fresh = await freshInstallSave();
      for (final version in [1, null]) {
        final raw = jsonEncode(v1Save(version: version));
        final prefs = await seed({'progress_v1': raw, 'progress_v1_backup_v1': 'older copy'});
        final store = await ProgressStore.load();
        expect(store.freshPaintPending, isTrue, reason: 'version $version');
        expect(store.unlockState(courses).isCourseOpen('catcafe'), isFalse, reason: 'no legacy gates after a reset');
        expect({...readSave(prefs)}..remove('freshPaintCard'), fresh, reason: 'version $version');
        expect(prefs.getString('progress_v1_before_reset'), raw);
        expect(prefs.getString('progress_v1_backup_v1'), 'older copy');
      }
    });

    test('tutorials she had not finished stay unfinished', () async {
      final save = v2Save()
        ..remove('seenTutorial')
        ..['seenSortTutorial2'] = false;
      await seed({'progress_v1': jsonEncode(save)});
      final store = await ProgressStore.load();
      expect(store.freshPaintPending, isTrue);
      expect(store.seenTutorial, isFalse);
      expect(store.seenSortTutorial, isFalse);
    });

    test('when the copy cannot be written, the old save is left alone and the reset retries next launch', () async {
      final raw = jsonEncode(v1Save());
      SharedPreferencesStorePlatform.instance = _RefusesKey(
        'flutter.progress_v1_before_reset',
        {'flutter.progress_v1': raw},
      );
      SharedPreferences.resetStatic();
      var prefs = await SharedPreferences.getInstance();
      final refused = await ProgressStore.load();
      expect(refused.isReadOnly, isTrue);
      expect(refused.freshPaintPending, isFalse);
      expect(refused.bestCombo, 9, reason: 'her old save, shown as it was');
      expect(refused.unlockState(courses).isCourseOpen('catcafe'), isTrue,
          reason: 'version 1 gates, this session only');
      await refused.noteCombo(50);
      expect(prefs.getString('progress_v1'), raw);
      expect(prefs.getString('progress_v1_backup_v1'), isNull);

      // Next launch, storage works again.
      prefs = await seed({'progress_v1': raw});
      final retried = await ProgressStore.load();
      expect(retried.isReadOnly, isFalse);
      expect(retried.freshPaintPending, isTrue);
      expect(retried.bestCombo, 0);
      expect(prefs.getString('progress_v1_before_reset'), raw);
    });

    test('runs once: the second launch copies nothing and the card stays gone once closed', () async {
      final raw = jsonEncode(v2Save());
      final prefs = await seed({'progress_v1': raw});
      final first = await ProgressStore.load();
      await first.recordCompletion(courses.first.puzzles.first.id, score: 10, stars: 2, seconds: 30);
      await prefs.setString('progress_v1_before_reset', 'marker');

      final second = await ProgressStore.load();
      expect(second.freshPaintPending, isTrue, reason: 'still pending until she closes it');
      expect(second.record(courses.first.puzzles.first.id)?.bestStars, 2, reason: 'new progress kept');
      expect(second.writes, 0);
      expect(prefs.getString('progress_v1_before_reset'), 'marker');

      await second.dismissFreshPaint();
      expect(second.freshPaintPending, isFalse);
      expect(readSave(prefs), isNot(contains('freshPaintCard')));
      final third = await ProgressStore.load();
      expect(third.freshPaintPending, isFalse);
      expect(third.record(courses.first.puzzles.first.id)?.bestStars, 2);
    });

    test('a copy already there is never overwritten, and the reset still happens', () async {
      // Say the app stopped after the copy and before the version 3 write.
      final raw = jsonEncode(v2Save());
      final prefs = await seed({'progress_v1': raw, 'progress_v1_before_reset': 'first copy'});
      final store = await ProgressStore.load();
      expect(store.freshPaintPending, isTrue);
      expect(store.bestCombo, 0);
      expect(readSave(prefs)['version'], 3);
      expect(prefs.getString('progress_v1_before_reset'), 'first copy');
    });

    test('when the version 3 write fails, the copy is kept and the next launch resets again', () async {
      final raw = jsonEncode(v2Save());
      final disk = _RefusesKey('flutter.progress_v1', {'flutter.progress_v1': raw});
      SharedPreferencesStorePlatform.instance = disk;
      SharedPreferences.resetStatic();
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isFalse, reason: 'the next save tries again');
      expect(store.freshPaintPending, isTrue);
      // The in-memory cache shows the write; what reached storage is what counts.
      var stored = await disk.getAll();
      expect(stored['flutter.progress_v1'], raw);
      expect(stored['flutter.progress_v1_before_reset'], raw);

      SharedPreferences.resetStatic();
      final again = await ProgressStore.load();
      expect(again.freshPaintPending, isTrue);
      expect(again.bestCombo, 0);
      stored = await disk.getAll();
      expect(stored['flutter.progress_v1_before_reset'], raw);
    });

    test('a version 2 save with a broken entry writes only the reset copy', () async {
      final broken = v2Save();
      broken['records'] = {...(broken['records'] as Map), 'bad': 'not a record'};
      final raw = jsonEncode(broken);
      final prefs = await seed({'progress_v1': raw});
      await ProgressStore.load();
      expect(prefs.getString('progress_v1_before_reset'), raw);
      expect(prefs.getString('progress_v1_backup'), isNull);
    });
  });

  group('a version 3 save', () {
    test('rewards it already earned stay earned when the build grows', () async {
      final ids = buildCourses(store: true).first.puzzles.map((p) => p.id).take(3);
      final save = v1Save(version: 3, extra: {
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

    test('loads as it is: no reset, no copy, no card', () async {
      final raw = jsonEncode(v1Save(version: 3));
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.freshPaintPending, isFalse);
      expect(store.bestCombo, 9);
      expect(store.writes, 0);
      expect(prefs.getString('progress_v1'), raw);
      expect(prefs.getString('progress_v1_before_reset'), isNull);
    });
  });

  group('fresh and new data', () {
    test('once the UI follows the gates, a fresh install saves as version 3 with gates closed', () async {
      final prefs = await seed({});
      final store = await ProgressStore.load(gatesEnforced: true);
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeSort), isFalse);
      await store.markTutorialSeen();
      final saved = readSave(prefs);
      expect(saved['version'], 3);
      expect(saved['keptOpen'], isEmpty);
      expect(saved, isNot(contains('freshPaintCard')));
      expect(store.freshPaintPending, isFalse, reason: 'a fresh install has nothing to explain');
      expect(prefs.getString('progress_v1_before_reset'), isNull);
    });

    test('the gates are enforced by default, so a fresh install starts closed', () async {
      await seed({});
      expect(UnlockTables.gatesEnforced, isTrue);
      final store = await ProgressStore.load();
      final s = store.unlockState(courses);
      expect(s.isModeOpen(UnlockTables.modeSort), isFalse);
      expect(s.isCourseOpen('catcafe'), isFalse);
      expect(s.summary, isEmpty);
      expect(store.introduced, isEmpty);
    });

    test('a save from the build before the gates stays fully open and is not re-introduced', () async {
      // That build wrote every old gate into keptOpen and had no introduced key.
      final prefs = await seed({
        'progress_v1': jsonEncode({'version': 3, 'keptOpen': UnlockTables.legacyIds.toList()}),
      });
      final store = await ProgressStore.load();
      final s = store.unlockState(courses);
      expect(s.isCourseOpen('catcafe'), isTrue);
      expect(s.isModeOpen(UnlockTables.modeTimeAttack), isTrue);
      for (final b in Booster.values) {
        expect(s.isBoosterOpen(b), isTrue, reason: b.name);
      }
      // One summary for everything open and never celebrated; no tips, no free uses.
      expect(s.summary, containsAll(UnlockTables.legacyIds));
      expect(store.introduced, containsAll([UnlockTables.modeSort, UnlockTables.boosterId(Booster.bomb)]));
      expect(store.boosters(Booster.bomb), Booster.starter[Booster.bomb]);
      await store.markCelebrated(s.summary);
      expect(store.unlockState(courses).summary, isEmpty);
      expect(readSave(prefs)['introduced'], containsAll(store.introduced));
    });

    test('introducing a booster gives one free use, once', () async {
      await seed({});
      final store = await ProgressStore.load();
      final id = UnlockTables.boosterId(Booster.wand);
      final before = store.boosters(Booster.wand);
      await store.markIntroduced(id);
      await store.markIntroduced(id);
      expect(store.boosters(Booster.wand), before + 1);
      expect(store.introduced, {id});
      final again = await ProgressStore.load();
      expect(again.introduced, {id});
      expect(again.boosters(Booster.wand), before + 1);
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
        'progress_v1': jsonEncode(v1Save(version: 3, extra: {
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
      expect(saved['version'], 3);
    });

    test('a newer save is read but never written over', () async {
      final raw = jsonEncode(v1Save(version: 4, extra: {'future': 1}));
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.bestCombo, 9, reason: 'not reset');
      expect(store.freshPaintPending, isFalse);
      await store.noteCombo(50);
      await store.markTutorialSeen();
      expect(prefs.getString('progress_v1'), raw);
      expect(prefs.getString('progress_v1_before_reset'), isNull);
    });

    test('a newer save keeps the gates it recorded open', () async {
      final raw = jsonEncode(v1Save(version: 4, extra: {'keptOpen': UnlockTables.legacyIds.toList()}));
      await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.unlockState(courses).isCourseOpen('catcafe'), isTrue);
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeTimeAttack), isTrue);
    });

    test('a version that is not a number is never written over', () async {
      final raw = jsonEncode(v1Save(version: 'two'));
      final prefs = await seed({'progress_v1': raw});
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.freshPaintPending, isFalse, reason: 'not reset either');
      await store.noteCombo(50);
      expect(prefs.getString('progress_v1'), raw);
    });

    test('a broken entry is backed up before the next save drops it', () async {
      final broken = v1Save(version: 3);
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
      expect(store.freshPaintPending, isFalse);
      expect(prefs.getString('progress_v1_unreadable'), '{not json');
      expect(prefs.getString('progress_v1_before_reset'), isNull);
      expect(store.unlockState(courses).isModeOpen(UnlockTables.modeSort), isFalse);
    });
  });
}
