import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/ui/board.dart';
import 'package:pawlypaint/ui/gem_style.dart';

/// The drill shape travels with the paints (PAP-24): there is no global, so a
/// painter built with new paints must draw and cache in the new shape.
void main() {
  final puzzle = allCourses.first.puzzles.first;

  test('forPuzzle gives every color the requested shape', () {
    expect(GemPaints.forPuzzle(puzzle, GemShape.round).every((g) => g.shape == GemShape.round), isTrue);
    expect(GemPaints.forPuzzle(puzzle, GemShape.square).every((g) => g.shape == GemShape.square), isTrue);
  });

  testWidgets('round and square drills draw different pixels', (tester) async {
    await tester.runAsync(() async {
      Future<Uint8List> draw(GemShape shape) async {
        final rec = ui.PictureRecorder();
        drawGem(Canvas(rec), const Rect.fromLTWH(0, 0, 48, 48), GemPaints(Colors.red, shape: shape));
        final picture = rec.endRecording();
        final image = await picture.toImage(48, 48);
        final data = await image.toByteData();
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      }

      final square = await draw(GemShape.square);
      final round = await draw(GemShape.round);
      expect(listEquals(square, round), isFalse);
      expect(listEquals(square, await draw(GemShape.square)), isTrue, reason: 'drawing is repeatable');
    });
  });

  test('a board painter caches per shape, so a new shape redraws its layers', () {
    final game = GameController(puzzle);
    const shimmer = AlwaysStoppedAnimation<double>(0);
    BoardPainter painterFor(GemShape shape) => BoardPainter(
          game: game,
          view: BoardView(),
          shimmer: shimmer,
          paints: GemPaints.forPuzzle(puzzle, shape),
          highlight: false,
          celebrate: false,
          cache: BoardCache(),
          pixelRatio: 1,
        );
    final square = painterFor(GemShape.square);
    final round = painterFor(GemShape.round);
    expect(square.look, isNot(round.look));
    expect(square.look, painterFor(GemShape.square).look);
    expect(round.shouldRepaint(square), isTrue);
  });
}
