import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
// The platform interface is a transitive dependency; the fake below needs it.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for audioplayers' Android side, SoundPool path (PAP-54).
///
/// It copies the one rule that matters from `WrappedPlayer.kt`: `resume` only
/// starts a sound when the player is not already "playing", and SoundPool never
/// reports completion, so only `stop` or `pause` clears that flag.
class _FakeAndroidAudio extends AudioplayersPlatformInterface {
  final _events = <String, StreamController<AudioEvent>>{};
  final _playing = <String, bool>{};
  final _source = <String, String>{};
  final releaseModes = <String, ReleaseMode>{};

  /// How many times each source really started sounding.
  final audibleStarts = <String, int>{};

  StreamController<AudioEvent> _controller(String id) => _events.putIfAbsent(id, StreamController.broadcast);

  @override
  Stream<AudioEvent> getEventStream(String playerId) => _controller(playerId).stream;

  @override
  Future<void> create(String playerId) async => _controller(playerId);

  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
    _source[playerId] = url;
    scheduleMicrotask(
        () => _controller(playerId).add(const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true)));
  }

  @override
  Future<void> resume(String playerId) async {
    if (_playing[playerId] ?? false) return;
    _playing[playerId] = true;
    final url = _source[playerId]!;
    audibleStarts[url] = (audibleStarts[url] ?? 0) + 1;
  }

  @override
  Future<void> stop(String playerId) async => _playing[playerId] = false;

  @override
  Future<void> pause(String playerId) async => _playing[playerId] = false;

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async => releaseModes[playerId] = releaseMode;

  /// The release mode of every player that was given a sound effect.
  Iterable<ReleaseMode?> get effectReleaseModes =>
      _source.entries.where((e) => e.value.contains('sfx/')).map((e) => releaseModes[e.key]);

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> release(String playerId) async => _playing[playerId] = false;

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes, {String? mimeType}) async {}

  @override
  Future<void> setAudioContext(String playerId, AudioContext audioContext) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<int?> getCurrentPosition(String playerId) async => null;

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
}

class _FakeGlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}

/// Skips copying the asset to the temp folder; the fake only needs the path.
class _PathOnlyCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => '/cache/$fileName';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAndroidAudio audio;
  late MusicController music;

  setUp(() async {
    audio = _FakeAndroidAudio();
    AudioplayersPlatformInterface.instance = audio;
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudio();
    AudioCache.instance = _PathOnlyCache();
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });

  tearDown(() => music.dispose());

  Future<void> tapRepeatedly(Sfx sfx, int times) async {
    for (var i = 0; i < times; i++) {
      await music.play(sfx);
      // Longer than the 45 ms thinning, so every tap is meant to be heard.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  test('an effect sounds every time it is played, not only the first few (PAP-54)', () async {
    await tapRepeatedly(Sfx.place, 10);
    expect(audio.audibleStarts['/cache/sfx/place.wav'], 10);
  });

  test('every effect keeps sounding after many plays', () async {
    for (final sfx in Sfx.values) {
      await tapRepeatedly(sfx, 5);
    }
    for (final sfx in Sfx.values) {
      expect(audio.audibleStarts['/cache/${sfx.asset}'], 5, reason: sfx.name);
    }
  });

  test('effect voices stop in place instead of unloading their sound', () async {
    await tapRepeatedly(Sfx.place, 4);
    expect(audio.effectReleaseModes, everyElement(ReleaseMode.stop));
  });
}
