import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'artworks.dart';

/// Inside a course, Easy is open from the start and each harder level opens
/// once [unlockAfter] pictures of the level before it are finished. Inside a
/// level, each picture opens when the one before it is finished.
const unlockAfter = 3;

/// Canvas size for each difficulty.
const _sizes = {Difficulty.easy: 16, Difficulty.medium: 24, Difficulty.hard: 32};

/// Courses are themed categories; all of them are open from the start.
List<Course> buildCourses() => [
      _course(
        'classics',
        'Cozy Classics',
        'Hearts, pets, flowers and sweet treats',
        const Color(0xFFF48FB1),
        {
          Difficulty.easy: {'heart': heart, 'paw': paw, 'sun': sun, 'mushroom': mushroom, 'cherries': cherries},
          Difficulty.medium: {
            'cat': cat,
            'daisy': daisy,
            'strawberry': strawberry,
            'rainbow': rainbow,
            'cupcake': cupcake,
          },
          Difficulty.hard: {
            'sunset': sunset,
            'butterfly': butterfly,
            'puppy': puppy,
            'tulips': tulips,
            'moonlight': moonlight,
          },
        },
      ),
    ];

/// Pictures are keyed by a stable slug, so reordering or adding pictures
/// never moves saved progress onto a different one.
Course _course(String id, String title, String subtitle, Color accent, Map<Difficulty, Map<String, Artwork>> art) =>
    Course(
      id: id,
      title: title,
      subtitle: subtitle,
      accent: accent,
      levels: [
        for (final MapEntry(key: difficulty, value: pictures) in art.entries)
          Level(
            difficulty: difficulty,
            puzzles: [
              for (final MapEntry(key: slug, value: draw) in pictures.entries) draw('$id-$slug', _sizes[difficulty]!),
            ],
          ),
      ],
    );
