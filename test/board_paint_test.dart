import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/ui/board.dart';
import 'package:pawlypaint/ui/gem_style.dart';
import 'package:pawlypaint/ui/layer_raster.dart';

void main() {
  test('LayerRaster draws a bitmap once and reuses it while the zoom holds', () {
    final raster = LayerRaster();
    var painted = 0;
    void frame(double pixelsPerUnit) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      raster.draw(
        canvas,
        key: 'k',
        bounds: const Rect.fromLTWH(0, 0, 960, 960),
        pixelsPerUnit: pixelsPerUnit,
        paintLayer: (c) {
          painted++;
          c.drawRect(const Rect.fromLTWH(0, 0, 960, 960), Paint()..color = Colors.pink);
        },
      );
      rec.endRecording().dispose();
    }

    frame(1.2);
    frame(1.2);
    frame(1.3);
    expect(painted, 1, reason: 'small zoom changes reuse the bitmap');
    expect(raster.usedImage, isTrue);
    frame(2.0);
    expect(painted, 2, reason: 'zooming in a lot rasterizes again');
    frame(0.5);
    expect(painted, 3, reason: 'zooming far out frees the big bitmap for a small one');
    frame(10);
    expect(raster.usedImage, isFalse, reason: 'past the bitmap cap the layer is drawn as vectors');
    raster.dispose();
  });

  test('BoardPainter paints an Extreme board from the cached bitmap', () {
    final puzzle = allCourses.first.puzzles.last;
    final game = GameController(puzzle);
    for (var i = 0; i < 200; i++) {
      game.place(i);
    }
    final view = BoardView()..fit(const Size(400, 700), puzzle.width, puzzle.height);
    final cache = BoardCache();
    const shimmer = AlwaysStoppedAnimation<double>(0.3);
    final painter = BoardPainter(
      game: game,
      view: view,
      shimmer: shimmer,
      paints: GemPaints.forPuzzle(puzzle),
      highlight: true,
      celebrate: false,
      cache: cache,
      pixelRatio: 3,
    );
    final sw = Stopwatch()..start();
    for (var f = 0; f < 60; f++) {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), const Size(400, 700));
      rec.endRecording().dispose();
    }
    sw.stop();
    expect(cache.raster.usedImage, isTrue);
    expect(cache.committed, greaterThanOrEqualTo(BoardCache.chunk), reason: 'placed drills were committed to the bitmap');
    expect(game.order.length - cache.committed, lessThan(BoardCache.chunk));
    // ignore: avoid_print
    print('60 frames of a ${puzzle.width}x${puzzle.height} board: ${sw.elapsedMilliseconds} ms');
    cache.dispose();
  });
}
