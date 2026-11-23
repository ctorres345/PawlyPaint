import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder, ZLibDecoderWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/indexed_png.dart';
import 'package:pawlypaint/data/pictures.dart' show picturesDir;

/// A 2x2, 8-bit indexed PNG whose IDAT holds [idat] (zlib data); CRCs are
/// zero because the reader doesn't check them.
Uint8List png(List<int> idat) {
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> body) => out
    ..add((ByteData(4)..setUint32(0, body.length)).buffer.asUint8List())
    ..add(type.codeUnits)
    ..add(body)
    ..add([0, 0, 0, 0]);
  chunk('IHDR', [0, 0, 0, 2, 0, 0, 0, 2, 8, 3, 0, 0, 0]);
  chunk('PLTE', [255, 0, 0, 0, 0, 255]);
  chunk('IDAT', idat);
  chunk('IEND', []);
  return out.takeBytes();
}

/// Rows of filter byte 0 plus indexes: [[0, 1], [1, 0]].
final pixels = io.ZLibEncoder().convert([0, 0, 1, 0, 1, 0]);

/// The zlib stream of a picture PNG: its IDAT chunks joined.
Uint8List idatOf(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  final data = BytesBuilder();
  for (var pos = 8; pos + 8 <= bytes.length;) {
    final length = view.getUint32(pos);
    if (String.fromCharCodes(bytes, pos + 4, pos + 8) == 'IDAT') data.add(bytes.sublist(pos + 8, pos + 8 + length));
    pos += 12 + length;
  }
  return data.takeBytes();
}

void main() {
  test('a good stream decodes', () {
    final p = decodeIndexedPng(png(pixels), name: 'good.png');
    expect((p.width, p.height), (2, 2));
    expect(p.indexes, [0, 1, 1, 0]);
    expect(p.palette, [0xFFFF0000, 0xFF0000FF]);
  });

  final badStreams = {
    'bad-sum.png': Uint8List.fromList(pixels)..[pixels.length - 1] ^= 0xFF,
    'cut.png': pixels.sublist(0, pixels.length - 3),
    'junk.png': [0x78, 0x9C, 0xFF, 0xFF, 0xFF, 0xFF],
  };
  for (final MapEntry(key: name, value: idat) in badStreams.entries) {
    test('$name: a bad zlib stream is a FormatException naming the file', () {
      expect(
        () => decodeIndexedPng(png(idat), name: name),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', startsWith('$name: '))),
      );
      expect(
        () => const ZLibDecoderWeb().decodeBytes(idat, verify: true),
        throwsFormatException,
        reason: 'the reader wraps only a FormatException, so the web inflater must throw one',
      );
    });
  }

  // archive inflates natively on device and in pure Dart on web. Tests run
  // only on the VM, so this checks the pure-Dart code there, not a browser
  // build: the browser check is a manual run (PR).
  test('every bundled picture inflates the same as with dart:io, native and pure-Dart', () {
    final files =
        io.Directory(picturesDir).listSync(recursive: true).whereType<io.File>().where((f) => f.path.endsWith('.png'));
    expect(files, isNotEmpty);
    for (final f in files) {
      final idat = idatOf(f.readAsBytesSync());
      final before = io.ZLibDecoder().convert(idat);
      expect(const ZLibDecoder().decodeBytes(idat, verify: true), before, reason: '${f.path} native');
      expect(const ZLibDecoderWeb().decodeBytes(idat, verify: true), before, reason: '${f.path} pure-Dart');
    }
  });
}
