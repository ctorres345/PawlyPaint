import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'artworks.dart';

/// Courses in play order. Each course unlocks once the previous one has
/// [unlockAfter] finished pictures, and inside a course each picture unlocks
/// when the one before it is finished.
const unlockAfter = 3;

List<Course> buildCourses() => [
      _course('beginner', 'Beginner', 'Small canvases, a handful of colors', const Color(0xFFF48FB1), 16,
          {'heart': heart, 'paw': paw, 'sun': sun, 'mushroom': mushroom, 'cherries': cherries}),
      _course('intermediate', 'Intermediate', 'Bigger pictures with soft shading', const Color(0xFFB39DDB), 24,
          {'cat': cat, 'daisy': daisy, 'strawberry': strawberry, 'rainbow': rainbow, 'cupcake': cupcake}),
      _course('expert', 'Expert', 'Large canvases and rich palettes', const Color(0xFF80CBC4), 32,
          {'sunset': sunset, 'butterfly': butterfly, 'puppy': puppy, 'tulips': tulips, 'moonlight': moonlight}),
    ];

/// Pictures are keyed by a stable slug, so reordering or adding pictures
/// never moves saved progress onto a different one.
Course _course(String id, String title, String subtitle, Color accent, int size, Map<String, Artwork> art) => Course(
      id: id,
      title: title,
      subtitle: subtitle,
      accent: accent,
      puzzles: [
        for (final MapEntry(key: slug, value: draw) in art.entries) draw('$id-$slug', size),
      ],
    );
