import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:gal/gal.dart';

import '../data/courses.dart' show allCourses;
import '../logic/photo_frames.dart';
import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';
import '../state/settings.dart' show SettingsScope;
import 'badges.dart' show newBadgeLabel;
import 'frame_picker.dart';
import 'gem_style.dart';

/// A frame's art and where its opening is, in the art's own pixels.
class FrameArt {
  FrameArt(this.image, this.bounds, this.window);

  final ui.Image image;

  /// The visible art: every pixel that is not fully transparent.
  final Rect bounds;

  /// The opening the picture shows through.
  final Rect window;

  /// Decodes the full-size art for [frame], kept for saves only (2048 px; the
  /// screen uses the 1x to 3.0x art).
  static Future<ui.Image> decode(PhotoFrame frame) => _decode('assets/art/frames/export/${frame.asset}.png');

  static Future<ui.Image> _decode(String key) async {
    final data = await rootBundle.load(key);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }

  /// Decodes the 3.0x art for [frame] and measures it. Its shares match the full-size
  /// art's within a pixel or two there, at a quarter of the pixels to scan.
  static Future<FrameArt> load(PhotoFrame frame) async {
    final image = await _decode('assets/art/frames/3.0x/${frame.asset}.png');
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) throw StateError('No pixels in ${frame.asset}');
    // A full scan of the art; off the UI thread, so opening the picker doesn't stutter.
    final (:bounds, :window) = await compute(_measure, (rgba, image.width, image.height));
    return FrameArt(image, bounds, window);
  }

  static ({Rect bounds, Rect window}) _measure((ByteData, int, int) a) => measure(a.$1, a.$2, a.$3);

  /// Finds the visible art and the opening, scanning out from the middle of the art
  /// until it meets the frame's inner edge. Throws when the middle is not see-through.
  @visibleForTesting
  static ({Rect bounds, Rect window}) measure(ByteData rgba, int width, int height) {
    int alpha(int x, int y) => rgba.getUint8((y * width + x) * 4 + 3);
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (alpha(x, y) == 0) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) throw StateError('The frame art is empty');
    final cx = (left + right) ~/ 2, cy = (top + bottom) ~/ 2;
    if (alpha(cx, cy) != 0) throw StateError('The frame art has no see-through middle');
    // The inner edge is where the frame's outline is mostly solid.
    bool open(int x, int y) => alpha(x, y) < 128;
    var wl = cx, wr = cx, wt = cy, wb = cy;
    while (wl > left && open(wl - 1, cy)) {
      wl--;
    }
    while (wr < right && open(wr + 1, cy)) {
      wr++;
    }
    while (wt > top && open(cx, wt - 1)) {
      wt--;
    }
    while (wb < bottom && open(cx, wb + 1)) {
      wb++;
    }
    return (
      bounds: Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0),
      window: Rect.fromLTRB(wl.toDouble(), wt.toDouble(), wr + 1.0, wb + 1.0),
    );
  }
}

/// Where a frame's art and opening are, as shares of the art's size, so it
/// fits any resolution of the art. Measured once per frame and kept.
class FrameGeometry {
  const FrameGeometry(this.bounds, this.window, this.aspect);

  /// The visible art, as shares of the image (0 to 1).
  final Rect bounds;

  /// The opening, as shares of the image (0 to 1).
  final Rect window;

  /// The art's width over its height.
  final double aspect;

  static final _cache = <PhotoFrame, Future<FrameGeometry>>{};

  /// The geometry of [frame]'s art. A failed load is not kept, so it is tried again.
  static Future<FrameGeometry> of(PhotoFrame frame) => _cache[frame] ??= () async {
        try {
          final art = await FrameArt.load(frame);
          final size = Size(art.image.width.toDouble(), art.image.height.toDouble());
          art.image.dispose();
          Rect share(Rect r) =>
              Rect.fromLTRB(r.left / size.width, r.top / size.height, r.right / size.width, r.bottom / size.height);
          return FrameGeometry(share(art.bounds), share(art.window), size.width / size.height);
        } catch (_) {
          _cache.remove(frame);
          rethrow;
        }
      }();
}

/// Share of the frame's opening the gems fill, so its rounded corners never cut a gem.
const windowFill = 0.88;

/// Longest side of a framed picture, so a save stays light on memory on small phones
/// and under the 4096-pixel texture limit of older ones.
const maxFramedSide = 2560.0;

/// Draws the finished [puzzle] as an image, its gems about 1600 pixels across,
/// on a paper-white sheet. Without a [frame] it has a small margin. With one,
/// the frame is scaled evenly to fit the gems in its opening, so its art is never
/// stretched, and the gems shrink as needed to keep the image within [maxFramedSide].
Future<ui.Image> renderPicture(
  Puzzle puzzle, {
  required GemShape shape,
  Color sheet = const Color(0xFFFFFBF7),
  PhotoFrame frame = PhotoFrame.none,
}) async {
  var cell = (1600 / math.max(puzzle.width, puzzle.height)).floorToDouble().clamp(24.0, 96.0);
  final paints = GemPaints.forPuzzle(puzzle, shape);
  // The measured shares are cached, so a save only decodes the art to draw it.
  final geometry = frame == PhotoFrame.none ? null : await FrameGeometry.of(frame);
  final art = geometry == null ? null : await FrameArt.decode(frame);
  try {
    late final Size size;
    late final Offset origin;
    Rect? frameSrc, frameDst;
    if (art == null || geometry == null) {
      size = Size(puzzle.width * cell + cell * 2, puzzle.height * cell + cell * 2);
      origin = Offset(cell, cell);
    } else {
      Rect px(Rect r) =>
          Rect.fromLTRB(r.left * art.width, r.top * art.height, r.right * art.width, r.bottom * art.height);
      final b = px(geometry.bounds), win = px(geometry.window);
      frameSrc = b;
      // Art pixels per gem, then the longest side that gives with its 4% margins.
      final perCell = math.max(puzzle.width / (win.width * windowFill), puzzle.height / (win.height * windowFill));
      final side = b.longestSide * perCell * 1.08;
      cell = math.min(cell, (maxFramedSide / side).floorToDouble());
      final gw = puzzle.width * cell, gh = puzzle.height * cell;
      final k = perCell * cell;
      final margin = (b.longestSide * k * 0.04).roundToDouble();
      size = Size((b.width * k + margin * 2).roundToDouble(), (b.height * k + margin * 2).roundToDouble());
      frameDst = Rect.fromLTWH(margin, margin, b.width * k, b.height * k);
      final c = Offset(margin + (win.center.dx - b.left) * k, margin + (win.center.dy - b.top) * k);
      origin = Offset((c.dx - gw / 2).roundToDouble(), (c.dy - gh / 2).roundToDouble());
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..drawRect(Offset.zero & size, Paint()..color = sheet);
    for (var i = 0; i < puzzle.cellCount; i++) {
      final rect =
          Rect.fromLTWH(origin.dx + (i % puzzle.width) * cell, origin.dy + (i ~/ puzzle.width) * cell, cell, cell);
      drawGem(c, rect, paints[puzzle.cells[i]]);
    }
    if (art != null && frameSrc != null && frameDst != null) {
      c.drawImageRect(art, frameSrc, frameDst, Paint()..filterQuality = FilterQuality.high);
    }
    final picture = rec.endRecording();
    try {
      return await picture.toImage(size.width.round(), size.height.round());
    } finally {
      picture.dispose();
    }
  } finally {
    art?.dispose();
  }
}

/// Saves the finished [puzzle] to the phone's photos, in [frame]. Returns null
/// when it worked, or what went wrong.
Future<String?> savePictureToPhotos(Puzzle puzzle, GemShape shape, {PhotoFrame frame = PhotoFrame.none}) async {
  try {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      return 'PawlyPaint needs permission to add photos. You can allow it in Settings.';
    }
    final image = await renderPicture(puzzle, shape: shape, frame: frame);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) throw StateError('No image data');
    final name = 'PawlyPaint ${puzzle.title}'.replaceAll(RegExp(r'[^\w ]'), '');
    await Gal.putImageBytes(png.buffer.asUint8List(), name: name);
    return null;
  } catch (e) {
    debugPrint('Saving picture failed: $e');
    return "Couldn't save the picture. Please try again.";
  }
}

/// A "Save to Photos" button that saves in the frame picked in [FramePicker] and
/// shows when it's saving and when it's done. Picking another frame lets her save
/// again. Works inside sheets and dialogs, where a snack bar would be hidden.
class SavePictureButton extends StatefulWidget {
  const SavePictureButton({super.key, required this.puzzle});

  final Puzzle puzzle;

  @override
  State<SavePictureButton> createState() => _SavePictureButtonState();
}

class _SavePictureButtonState extends State<SavePictureButton> {
  bool _busy = false;

  /// The frame of the last save that worked, or null before one.
  PhotoFrame? _savedWith;

  Future<void> _save(PhotoFrame frame) async {
    setState(() => _busy = true);
    final store = ProgressScope.read(context);
    final error = await savePictureToPhotos(widget.puzzle, SettingsScope.read(context).shape, frame: frame);
    final framed = error == null && frame != PhotoFrame.none;
    if (framed) await store.addSecret(framedSaveSecret);
    // Closed while saving: leave a new badge unseen, so the next completion sheet shows it.
    if (!mounted) return;
    final badges = framed ? takeNewAchievements(allCourses, store) : const <Achievement>[];
    setState(() {
      _busy = false;
      if (error == null) _savedWith = frame;
    });
    final message = error ?? (badges.isEmpty ? null : badges.map((b) => '${newBadgeLabel(b)}!').join('\n'));
    if (message != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: error == null ? const Icon(Icons.military_tech_rounded, color: Color(0xFFFFA000)) : null,
          content: Text(message, textAlign: error == null ? TextAlign.center : null),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = usableFrame(context);
    final saved = _savedWith == frame;
    return TextButton.icon(
      onPressed: _busy || saved ? null : () => _save(frame),
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(saved ? Icons.check_circle_rounded : Icons.download_rounded),
      label: Text(saved ? 'Saved to Photos' : 'Save to Photos'),
    );
  }
}
