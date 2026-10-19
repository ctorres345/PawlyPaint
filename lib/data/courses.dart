import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'art/animals.dart';
import 'art/garden.dart';
import 'art/sweets.dart';
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
      _course(
        'animals',
        'Animal Friends',
        'Pets, critters and wild friends',
        const Color(0xFFFFB74D),
        {
          Difficulty.easy: {'fish': fish, 'bunny': bunny, 'chick': chick, 'ladybug': ladybug, 'snail': snail},
          Difficulty.medium: {'fox': fox, 'penguin': penguin, 'owl': owl, 'frog': frog, 'whale': whale},
          Difficulty.hard: {'panda': panda, 'turtle': turtle, 'hedgehog': hedgehog, 'parrot': parrot, 'bee': bee},
        },
      ),
      _course(
        'garden',
        'Garden',
        'Flowers, sprouts and sunny afternoons',
        const Color(0xFFA5D6A7),
        {
          Difficulty.easy: {'tulip': tulip, 'leaf': leaf, 'cactus': cactus, 'sprout': sprout, 'acorn': acorn},
          Difficulty.medium: {
            'sunflower': sunflower,
            'rose': rose,
            'watering-can': wateringCan,
            'carrot': carrot,
            'birdhouse': birdhouse,
          },
          Difficulty.hard: {
            'cherry-blossom': cherryBlossom,
            'lotus': lotus,
            'gnome': gnome,
            'lavender': lavender,
            'apple-tree': appleTree,
          },
        },
      ),
      _course(
        'sweets',
        'Sweet Treats',
        'Candy, cakes and cozy desserts',
        const Color(0xFFCE93D8),
        {
          Difficulty.easy: {
            'lollipop': lollipop,
            'ice-cream': iceCream,
            'donut': donut,
            'candy': candy,
            'cookie': cookie
          },
          Difficulty.medium: {
            'macarons': macarons,
            'cake-slice': cakeSlice,
            'popsicle': popsicle,
            'gingerbread': gingerbread,
            'pudding': pudding,
          },
          Difficulty.hard: {
            'layer-cake': layerCake,
            'sundae': sundae,
            'boba-tea': bobaTea,
            'pancakes': pancakes,
            'tea-time': teaTime,
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
