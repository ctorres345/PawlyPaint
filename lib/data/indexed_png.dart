import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;

/// A decoded palette PNG: a palette index per pixel, row by row, and the
/// palette as 0xFFRRGGBB in the file's own order.
typedef IndexedPng = ({int width, int height, Uint8List indexes, List<int> palette});

/// Reads an indexed (colour type 3), non-interlaced PNG with no transparency,
/// the only kind tool/art_to_puzzle.py writes. Anything else is a
/// [FormatException] naming [name], so a bad picture fails loudly.
IndexedPng decodeIndexedPng(Uint8List bytes, {String name = 'PNG'}) {
  Never fail(String why) => throw FormatException('$name: $why');
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 8 || !Iterable.generate(8).every((i) => bytes[i] == signature[i])) fail('not a PNG');

  final view = ByteData.sublistView(bytes);
  var width = 0, height = 0, depth = 0;
  List<int>? palette;
  final data = BytesBuilder(copy: false);
  var pos = 8;
  while (true) {
    if (pos + 8 > bytes.length) fail('ends without IEND');
    final length = view.getUint32(pos);
    final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
    if (pos + 12 + length > bytes.length) fail('chunk $type runs past the end');
    final body = Uint8List.sublistView(bytes, pos + 8, pos + 8 + length);
    pos += 12 + length;
    switch (type) {
      case 'IHDR':
        final h = ByteData.sublistView(body);
        width = h.getUint32(0);
        height = h.getUint32(4);
        depth = body[8];
        if (body[9] != 3) fail('colour type ${body[9]}, want 3 (indexed)');
        if (body[12] != 0) fail('interlaced');
        if (!const {1, 2, 4, 8}.contains(depth)) fail('bit depth $depth');
      case 'PLTE':
        palette = [
          for (var i = 0; i + 2 < body.length; i += 3) 0xFF000000 | body[i] << 16 | body[i + 1] << 8 | body[i + 2],
        ];
      case 'tRNS':
        fail('has transparency');
      case 'IDAT':
        data.add(body);
      case 'IEND':
        break;
    }
    if (type == 'IEND') break;
  }
  if (width == 0 || height == 0) fail('no IHDR');
  final colours = palette ?? fail('no palette');

  // Native zlib on Android and iPhone, pure Dart on web. verify checks the
  // Adler-32, so a cut or damaged stream fails here instead of decoding.
  final Uint8List raw;
  try {
    raw = const ZLibDecoder().decodeBytes(data.takeBytes(), verify: true);
  } on FormatException catch (e) {
    fail('bad image data (${e.message})');
  }
  final stride = (width * depth + 7) >> 3;
  if (raw.length < height * (stride + 1)) fail('image data too short');
  final indexes = Uint8List(width * height);
  var prev = Uint8List(stride);
  final mask = (1 << depth) - 1;
  for (var y = 0; y < height; y++) {
    final start = y * (stride + 1);
    final filter = raw[start];
    final line = Uint8List.fromList(raw.sublist(start + 1, start + 1 + stride));
    for (var i = 0; i < stride; i++) {
      final left = i > 0 ? line[i - 1] : 0, up = prev[i], upLeft = i > 0 ? prev[i - 1] : 0;
      line[i] = (line[i] +
              switch (filter) {
                0 => 0,
                1 => left,
                2 => up,
                3 => (left + up) >> 1,
                4 => _paeth(left, up, upLeft),
                _ => fail('filter $filter'),
              }) &
          0xFF;
    }
    for (var x = 0; x < width; x++) {
      final bit = x * depth;
      final index = (line[bit >> 3] >> (8 - depth - (bit & 7))) & mask;
      if (index >= colours.length) fail('pixel $x,$y uses palette index $index of ${colours.length}');
      indexes[y * width + x] = index;
    }
    prev = line;
  }
  return (width: width, height: height, indexes: indexes, palette: colours);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}
