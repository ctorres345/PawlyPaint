import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../models/puzzle.dart';
import 'gem_style.dart';

/// Draws the finished [puzzle] as an image about 1600 pixels across, on a
/// paper-white sheet with a small margin.
Future<ui.Image> renderPicture(Puzzle puzzle, {Color sheet = const Color(0xFFFFFBF7)}) {
  final cell = (1600 / math.max(puzzle.width, puzzle.height)).floorToDouble().clamp(24.0, 96.0);
  final paints = GemPaints.forPuzzle(puzzle);
  final margin = cell;
  final w = puzzle.width * cell + margin * 2, h = puzzle.height * cell + margin * 2;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = sheet);
  for (var i = 0; i < puzzle.cellCount; i++) {
    final rect = Rect.fromLTWH(margin + (i % puzzle.width) * cell, margin + (i ~/ puzzle.width) * cell, cell, cell);
    drawGem(c, rect, paints[puzzle.cells[i]]);
  }
  final picture = rec.endRecording();
  return picture.toImage(w.round(), h.round()).whenComplete(picture.dispose);
}

/// Saves the finished [puzzle] to the phone's photos. Returns null when it
/// worked, or what went wrong.
Future<String?> savePictureToPhotos(Puzzle puzzle) async {
  try {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      return 'PawlyPaint needs permission to add photos. You can allow it in Settings.';
    }
    final image = await renderPicture(puzzle);
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

/// A "Save to Photos" button that shows when it's saving and when it's done.
/// Works inside sheets and dialogs, where a snack bar would be hidden.
class SavePictureButton extends StatefulWidget {
  const SavePictureButton({super.key, required this.puzzle});

  final Puzzle puzzle;

  @override
  State<SavePictureButton> createState() => _SavePictureButtonState();
}

class _SavePictureButtonState extends State<SavePictureButton> {
  bool _busy = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final error = await savePictureToPhotos(widget.puzzle);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = error == null;
    });
    if (error != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(error),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy || _saved ? null : _save,
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_saved ? Icons.check_circle_rounded : Icons.download_rounded),
      label: Text(_saved ? 'Saved to Photos' : 'Save to Photos'),
    );
  }
}
