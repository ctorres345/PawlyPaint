import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/logic/boosters.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _day = 1;

/// Plays on the 1-based [day] of a fixed month run, so day N is always a different date.
Future<void> _finish(ProgressStore store, int day, {String id = 'p'}) {
  _day = day;
  return store.recordCompletion(id, score: 1, stars: 1, seconds: 1);
}

List<String> _keys(int n) => [for (var i = 1; i <= n; i++) dayKey(DateTime(2025, 1, i))];

Future<ProgressStore> _load(Map<String, dynamic> save) async {
  SharedPreferences.setMockInitialValues({
    'progress_v1': jsonEncode({'version': 2, ...save})
  });
  return ProgressStore.load();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProgressStore.clock = () => DateTime(2026, 1, _day);
  });
  tearDown(() => ProgressStore.clock = DateTime.now);

  test('the 7th different day pays once, then again on the 14th', () async {
    final store = await ProgressStore.load();
    for (var d = 1; d <= 6; d++) {
      await _finish(store, d);
    }
    expect(store.takeDaysPlayedBonus(), 0);
    final bombs = store.boosters(Booster.bomb), wands = store.boosters(Booster.wand);
    await _finish(store, 7);
    expect(store.boosters(Booster.bomb), bombs + 1);
    expect(store.boosters(Booster.wand), wands + 1);
    expect(store.takeDaysPlayedBonus(), 1);
    expect(store.takeDaysPlayedBonus(), 0);
    await _finish(store, 7);
    await _finish(store, 8);
    expect(store.takeDaysPlayedBonus(), 0);
    expect(store.boosters(Booster.bomb), bombs + 1);
    for (var d = 9; d <= 14; d++) {
      await _finish(store, d);
    }
    expect(store.takeDaysPlayedBonus(), 1);
    expect(store.boosters(Booster.bomb), bombs + 2);
  });

  test('a gap neither lowers the count nor takes anything', () async {
    final store = await ProgressStore.load();
    for (var d = 1; d <= 3; d++) {
      await _finish(store, d);
    }
    final bombs = store.boosters(Booster.bomb);
    for (var d = 30; d <= 33; d++) {
      await _finish(store, d);
    }
    expect(store.daysPlayed, 7);
    expect(store.takeDaysPlayedBonus(), 1);
    expect(store.boosters(Booster.bomb), bombs + 1);
  });

  test('the paid count survives a reload and does not pay twice', () async {
    final store = await ProgressStore.load();
    for (var d = 1; d <= 7; d++) {
      await _finish(store, d);
    }
    final again = await ProgressStore.load();
    expect(again.streakBonusPaid, 1);
    final bombs = again.boosters(Booster.bomb);
    await _finish(again, 7);
    expect(again.takeDaysPlayedBonus(), 0);
    expect(again.boosters(Booster.bomb), bombs);
  });

  test('an imported save that is already paid up pays nothing', () async {
    final store = await _load({'daysPlayed': _keys(14), 'streakBonusPaid': 2});
    await _finish(store, 15);
    expect(store.daysPlayed, 15);
    expect(store.takeDaysPlayedBonus(), 0);
  });

  test('a save owed several gifts is back-paid in one go', () async {
    final store = await _load({'daysPlayed': _keys(30), 'streakBonusPaid': 0});
    final bombs = store.boosters(Booster.bomb), wands = store.boosters(Booster.wand);
    await _finish(store, 1);
    expect(store.boosters(Booster.bomb), bombs + 4);
    expect(store.boosters(Booster.wand), wands + 4);
    expect(store.takeDaysPlayedBonus(), 4);
    expect(store.streakBonusPaid, 4);
  });

  test('a save with only a daily streak of 14 back-pays 2', () async {
    final store = await _load({
      'daily': {'date': '2025-06-30', 'id': 'x', 'done': '2025-06-30', 'streak': 14, 'best': 14},
    });
    expect(store.daysPlayed, 14);
    await _finish(store, 1);
    expect(store.takeDaysPlayedBonus(), 2);
  });

  test('a Sort finish pays too', () async {
    final store = await ProgressStore.load();
    for (var d = 1; d <= 7; d++) {
      await _finish(store, d, id: PlayMode.sort.key('p'));
    }
    expect(store.takeDaysPlayedBonus(), 1);
  });

  test('a negative paid count loads as 0', () async {
    final store = await _load({'streakBonusPaid': -3});
    expect(store.streakBonusPaid, 0);
  });
}
