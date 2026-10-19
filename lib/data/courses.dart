import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'artworks.dart';

/// Courses in play order. Each course unlocks once the previous one has
/// [unlockAfter] finished pictures, and inside a course each picture unlocks
/// when the one before it is finished.
const unlockAfter = 3;

List<Course> buildCourses() => [
      _course('beginner', 'Beginner', 'Small canvases, a handful of colors', const Color(0xFFF48FB1), 16,
          [heart, paw, sun, mushroom, cherries]),
      _course('intermediate', 'Intermediate', 'Bigger pictures with soft shading', const Color(0xFFB39DDB), 24,
          [cat, daisy, strawberry, rainbow, cupcake]),
      _course('expert', 'Expert', 'Large canvases and rich palettes', const Color(0xFF80CBC4), 32,
          [sunset, butterfly, puppy, tulips, moonlight]),
    ];

Course _course(String id, String title, String subtitle, Color accent, int size, List<Artwork> art) => Course(
      id: id,
      title: title,
      subtitle: subtitle,
      accent: accent,
      puzzles: [
        for (var i = 0; i < art.length; i++) art[i]('$id-${i + 1}', size),
      ],
    );
