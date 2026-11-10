import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart' as session;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as ja;
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

/// Respect the iPhone's silent switch and mix politely with other audio.
final _iosContext = AudioContextIOS(category: AVAudioSessionCategory.ambient);

/// Sound effects mix in without asking for focus. With the default (gain) each
/// effect took focus from the music player, which Android reported as a
/// permanent loss, so the music paused for good (PAP-53).
final sfxAudioContext = AudioContext(
  iOS: _iosContext,
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.game,
    contentType: AndroidContentType.music,
    audioFocus: AndroidAudioFocus.none,
  ),
);

/// The music asks Android for audio focus (calls and other apps pause it) and
/// respects the iPhone's silent switch.
const musicSession = session.AudioSessionConfiguration(
  avAudioSessionCategory: session.AVAudioSessionCategory.ambient,
  androidAudioAttributes: session.AndroidAudioAttributes(
    contentType: session.AndroidAudioContentType.music,
    usage: session.AndroidAudioUsage.game,
  ),
  androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
);

/// Short sound effects, composed by tool/compose_sfx.py.
enum Sfx {
  place('sfx/place.wav'),
  land('sfx/land.wav'),
  color('sfx/color.wav'),
  complete('sfx/complete.wav'),
  wrong('sfx/wrong.wav'),
  shake('sfx/shake.wav'),
  place2('sfx/place2.wav'),
  place3('sfx/place3.wav'),
  land2('sfx/land2.wav'),
  land3('sfx/land3.wav'),
  combo('sfx/combo.wav'),
  boom('sfx/boom.wav');

  /// The drill tick for a streak at [level] (0 to 2): it brightens as it grows.
  static Sfx placeAt(int level) => const [place, place2, place3][level.clamp(0, 2)];

  /// The bead landing chime for a combo at [level] (0 to 2).
  static Sfx landAt(int level) => const [land, land2, land3][level.clamp(0, 2)];

  const Sfx(this.asset);

  final String asset;
}

/// Remembers that another app paused the music, so it comes back by itself only
/// when it should: not while the app is in the background (the lifecycle brings
/// it back when the app returns) and not when the player muted it meanwhile.
class InterruptionGate {
  bool _interrupted = false;

  /// The music was playing and another app took the audio.
  void begin() => _interrupted = true;

  /// Forget the interruption without resuming.
  void clear() => _interrupted = false;

  /// The other app let go. True when the music should start playing again.
  bool shouldResume({required bool appActive, required bool muted}) {
    final resume = _interrupted && appActive && !muted;
    _interrupted = false;
    return resume;
  }
}

/// Plays the menu song on menus and the chosen (or shuffled) theme while
/// painting. Settings are remembered on the device.
class MusicController extends ChangeNotifier with WidgetsBindingObserver {
  MusicController._(
    this._prefs, {
    required this.muted,
    required this.choice,
    required this.sfxOn,
    required this.musicVolume,
    required this.sfxVolume,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _mutedKey = 'music_muted';
  static const _choiceKey = 'music_choice';
  static const _sfxKey = 'sfx_on';
  static const _musicVolumeKey = 'music_volume';
  static const _sfxVolumeKey = 'sfx_volume';

  static Future<MusicController> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Music still plays; choices just aren't remembered.
      debugPrint('Music settings unavailable: $e');
    }
    final name = prefs?.getString(_choiceKey);
    try {
      // Every player starts with this: effects mix in without asking for focus.
      // Only the music player gets its own focus-taking context (see _start).
      await AudioPlayer.global.setAudioContext(sfxAudioContext);
    } catch (e) {
      debugPrint('Audio setup failed: $e');
    }
    return MusicController._(
      prefs,
      muted: prefs?.getBool(_mutedKey) ?? false,
      choice: MusicTheme.values.where((t) => t.name == name).firstOrNull,
      sfxOn: prefs?.getBool(_sfxKey) ?? true,
      musicVolume: prefs?.getDouble(_musicVolumeKey) ?? 0.55,
      sfxVolume: prefs?.getDouble(_sfxVolumeKey) ?? 0.5,
    );
  }

  final SharedPreferences? _prefs;
  // The package's own interruption handling is off: it would resume the music
  // after a call even when the app is in the background, and halve then double
  // the volume on a duck. [_onInterruption] does it with the app's state.
  final _player = ja.AudioPlayer(handleInterruptions: false);
  final _interruptions = InterruptionGate();
  StreamSubscription<session.AudioInterruptionEvent>? _interruptionSub;
  final _rng = math.Random();

  bool muted;

  /// The theme picked in settings, or null to shuffle between all three.
  MusicTheme? choice;

  /// What is playing (or would be, when muted).
  MusicTheme? current;
  MusicTheme? _lastGameTheme;

  /// Sound effects on or off, separate from the music.
  bool sfxOn;

  /// 0..1 loudness of the music and of the sound effects.
  double musicVolume;
  double sfxVolume;

  Future<void> setMusicVolume(double v) async {
    musicVolume = v;
    notifyListeners();
    try {
      await _player.setVolume(v);
    } catch (_) {}
    await _prefs?.setDouble(_musicVolumeKey, v);
  }

  Future<void> setSfxVolume(double v) async {
    sfxVolume = v;
    notifyListeners();
    await _prefs?.setDouble(_sfxVolumeKey, v);
  }

  /// Quick repeating sounds share a small pool of players so rapid taps
  /// don't cut each other off.
  /// A few players per sound, used in turn so quick repeats overlap.
  static const _voices = 3;
  final Map<Sfx, List<AudioPlayer>> _sfxPlayers = {};
  final Map<Sfx, int> _nextVoice = {};
  final Set<AudioPlayer> _stopModeSet = {};

  /// audioplayers redraws the screen every frame while a player plays, to
  /// report its position. Nothing here needs the position, so that is off:
  /// otherwise the music alone keeps the whole app rendering nonstop.
  static AudioPlayer _quietPlayer() => AudioPlayer()..positionUpdater = null;
  final Map<Sfx, DateTime> _lastPlayed = {};
  bool _inGame = false;
  bool _musicContextSet = false;
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
    await _prefs?.setBool(_sfxKey, value);
  }

  /// Plays a sound effect; very rapid repeats (a fast drag) are thinned out.
  Future<void> play(Sfx sfx) async {
    if (!sfxOn || !_appActive) return;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last).inMilliseconds < 45) return;
    _lastPlayed[sfx] = now;
    try {
      final voices = _sfxPlayers[sfx] ??= List.generate(_voices, (_) => _quietPlayer());
      final i = _nextVoice[sfx] = ((_nextVoice[sfx] ?? -1) + 1) % _voices;
      final voice = voices[i];
      // SoundPool never reports that a sound finished, so on Android a voice
      // stays "playing" and ignores every later play. Stopping it first frees
      // it for the next one (PAP-54). Stop, not release, keeps the sound loaded.
      if (!_stopModeSet.contains(voice)) {
        _stopModeSet.add(voice);
        await voice.setReleaseMode(ReleaseMode.stop);
      }
      await voice.stop();
      await voice.play(AssetSource(sfx.asset), volume: sfxVolume, mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    notifyListeners();
    await _prefs?.setBool(_mutedKey, value);
    _start();
  }

  Future<void> setChoice(MusicTheme? value) async {
    if (value == choice) return;
    choice = value;
    notifyListeners();
    if (value == null) {
      await _prefs?.remove(_choiceKey);
    } else {
      await _prefs?.setString(_choiceKey, value.name);
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
      if (!_musicContextSet) {
        // Once, and never blocking the music: if this fails the music still plays.
        _musicContextSet = true;
        try {
          final audioSession = await session.AudioSession.instance;
          await audioSession.configure(musicSession);
          _interruptionSub = audioSession.interruptionEventStream.listen(_onInterruption);
        } catch (e) {
          debugPrint('Music audio session failed: $e');
        }
        if (generation != _generation) return;
      }
      await _player.setAsset('assets/${_inGame ? current!.asset : _menuAsset}');
      if (generation != _generation) return;
      await _player.setLoopMode(ja.LoopMode.one);
      await _player.setVolume(musicVolume);
      // A newer request (mute, next level) may have come in while this one loaded.
      if (generation != _generation) return;
      // play() only finishes when playback ends, which a loop never does.
      unawaited(_player.play());
      // The app may have gone to the background while the track loaded.
      if (!_appActive) await _player.pause();
    } catch (e) {
      // Music is a nice-to-have; never let an audio hiccup break the game.
      debugPrint('Music failed: $e');
    }
  }

  /// Another app took the audio (a call, a video): pause, and come back when it
  /// ends. A duck (a notification sound) just lowers the volume meanwhile.
  void _onInterruption(session.AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case session.AudioInterruptionType.duck:
          unawaited(_player.setVolume(musicVolume / 2));
        case session.AudioInterruptionType.pause:
        case session.AudioInterruptionType.unknown:
          if (_player.playing) {
            _interruptions.begin();
            unawaited(_player.pause());
          }
      }
    } else {
      switch (event.type) {
        case session.AudioInterruptionType.duck:
          unawaited(_player.setVolume(musicVolume));
        case session.AudioInterruptionType.pause:
          if (_interruptions.shouldResume(appActive: _appActive, muted: muted)) unawaited(_player.play());
        case session.AudioInterruptionType.unknown:
          _interruptions.clear();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (active) {
      // Pick up where the song left off (pulling down Control Center or a
      // notification shouldn't restart it); start fresh only if it stopped.
      if (_player.processingState == ja.ProcessingState.ready && !_player.playing && !muted) {
        unawaited(_player.play());
      } else {
        _start();
      }
    } else {
      unawaited(_player.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interruptionSub?.cancel();
    _player.dispose();
    for (final voices in _sfxPlayers.values) {
      for (final p in voices) {
        p.dispose();
      }
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
