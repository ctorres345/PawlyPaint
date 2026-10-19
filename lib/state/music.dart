import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three in-game themes, Dr. Mario style.
enum MusicTheme {
  chill('Chill', 'Mellow keys and a lazy beat', 'music/chill.m4a'),
  fever('Fever', 'Bouncy and upbeat', 'music/fever.m4a'),
  hip('Hip', 'Swingy, with a groovy bass', 'music/hip.m4a');

  const MusicTheme(this.label, this.blurb, this.asset);

  final String label;
  final String blurb;
  final String asset;
}

/// Picks a random theme for the next picture: never the same one twice in a row.
MusicTheme nextShuffleTheme(MusicTheme? last, math.Random rng) {
  final options = MusicTheme.values.where((t) => t != last).toList();
  return options[rng.nextInt(options.length)];
}

const _menuAsset = 'music/menu.m4a';

/// Short sound effects, composed by tool/compose_sfx.py.
enum Sfx {
  place('sfx/place.wav'),
  land('sfx/land.wav'),
  color('sfx/color.wav'),
  complete('sfx/complete.wav'),
  wrong('sfx/wrong.wav'),
  shake('sfx/shake.wav');

  const Sfx(this.asset);

  final String asset;
}

/// Plays the menu song on menus and the chosen (or shuffled) theme while
/// painting. Settings are remembered on the device.
class MusicController extends ChangeNotifier with WidgetsBindingObserver {
  MusicController._(this._prefs, {required this.muted, required this.choice, required this.sfxOn}) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _mutedKey = 'music_muted';
  static const _choiceKey = 'music_choice';
  static const _sfxKey = 'sfx_on';
  static const _sfxVolume = 0.5;
  static const _volume = 0.55;

  static Future<MusicController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_choiceKey);
    // Respect the iPhone's silent switch and mix politely with other audio.
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(usageType: AndroidUsageType.game, contentType: AndroidContentType.music),
      ));
    } catch (e) {
      debugPrint('Audio setup failed: $e');
    }
    return MusicController._(
      prefs,
      muted: prefs.getBool(_mutedKey) ?? false,
      choice: MusicTheme.values.where((t) => t.name == name).firstOrNull,
      sfxOn: prefs.getBool(_sfxKey) ?? true,
    );
  }

  final SharedPreferences _prefs;
  final _player = AudioPlayer();
  final _rng = math.Random();

  bool muted;

  /// The theme picked in settings, or null to shuffle between all three.
  MusicTheme? choice;

  /// What is playing (or would be, when muted).
  MusicTheme? current;
  MusicTheme? _lastGameTheme;

  /// Sound effects on or off, separate from the music.
  bool sfxOn;

  /// Quick repeating sounds share a small pool of players so rapid taps
  /// don't cut each other off.
  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  bool _inGame = false;
  bool _appActive = true;
  int _generation = 0;

  void playMenu() {
    _inGame = false;
    current = null;
    _start();
  }

  int _openGames = 0;

  /// Called when a picture opens; starts a theme.
  void enterGame() {
    _openGames++;
    playGame();
  }

  /// Called when a picture closes; back to the menu song once none is open
  /// (a restart replaces the screen, so briefly two are open).
  void leaveGame() {
    _openGames = math.max(0, _openGames - 1);
    if (_openGames == 0) playMenu();
  }

  void playGame() {
    _inGame = true;
    current = choice ?? nextShuffleTheme(_lastGameTheme, _rng);
    _lastGameTheme = current;
    _start();
  }

  Future<void> setSfx(bool value) async {
    sfxOn = value;
    notifyListeners();
    await _prefs.setBool(_sfxKey, value);
  }

  /// Plays a sound effect; very rapid repeats (a fast drag) are thinned out.
  Future<void> play(Sfx sfx) async {
    if (!sfxOn || !_appActive) return;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last).inMilliseconds < 45) return;
    _lastPlayed[sfx] = now;
    try {
      final pool = _pools[sfx] ??= await AudioPool.create(
        source: AssetSource(sfx.asset),
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
      );
      await pool.start(volume: _sfxVolume);
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    notifyListeners();
    await _prefs.setBool(_mutedKey, value);
    _start();
  }

  Future<void> setChoice(MusicTheme? value) async {
    if (value == choice) return;
    choice = value;
    notifyListeners();
    if (value == null) {
      await _prefs.remove(_choiceKey);
    } else {
      await _prefs.setString(_choiceKey, value.name);
    }
    if (_inGame) playGame();
  }

  Future<void> _start() async {
    notifyListeners();
    // A newer request may arrive while this one awaits; only the latest plays.
    final generation = ++_generation;
    try {
      await _player.stop();
      if (muted || !_appActive || generation != _generation) return;
      // One theme per level: shuffle picks it when the level starts, and it
      // loops until the level ends or starts over.
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(_inGame ? current!.asset : _menuAsset), volume: _volume);
    } catch (e) {
      // Music is a nice-to-have; never let an audio hiccup break the game.
      debugPrint('Music failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (active) {
      _start();
    } else {
      unawaited(_player.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    for (final pool in _pools.values) {
      pool.dispose();
    }
    super.dispose();
  }
}

/// Makes the [MusicController] available to the widget tree.
class MusicScope extends InheritedNotifier<MusicController> {
  const MusicScope({super.key, required MusicController music, required super.child}) : super(notifier: music);

  static MusicController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MusicScope>()!.notifier!;

  /// For callbacks that must not subscribe to changes.
  static MusicController read(BuildContext context) => context.getInheritedWidgetOfExactType<MusicScope>()!.notifier!;
}
