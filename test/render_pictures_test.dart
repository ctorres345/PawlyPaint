import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';

/// Not a real test: with RENDER_DIR set, writes every picture of the course
/// named by RENDER_COURSE as a PPM image, to eyeball new art.
///   RENDER_DIR=/tmp/pics RENDER_COURSE=catcafe flutter test test/render_pictures_test.dart
void main() {
  final dir = Platform.environment['RENDER_DIR'];
  final courseId = Platform.environment['RENDER_COURSE'];
  test('render pictures', () {
    if (dir == null || courseId == null) return;
    final course = allCourses.firstWhere((c) => c.id == courseId);
    Directory(dir).createSync(recursive: true);
    for (final level in course.levels) {
      for (final p in level.puzzles) {
        final buf = StringBuffer('P3\n${p.width} ${p.height}\n255\n');
        for (var i = 0; i < p.cells.length; i++) {
          final col = p.palette[p.cells[i]];
          buf.write('${(col.r * 255).round()} ${(col.g * 255).round()} ${(col.b * 255).round()}\n');
        }
        File('$dir/${p.id}.ppm').writeAsStringSync(buf.toString());
      }
    }
  }, skip: dir == null);
}
