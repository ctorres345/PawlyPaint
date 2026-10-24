import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'art/animals.dart';
import 'art/catcafe.dart';
import 'art/kpop.dart';
import 'art/garden.dart';
import 'art/minecraft.dart';
import 'art/sweets.dart';
import 'art/vocaloid.dart';
import 'artworks.dart';
import 'art/extreme_classics.dart';
import 'art/extreme_animals.dart';
import 'art/extreme_garden.dart';
import 'art/extreme_sweets.dart';
import 'art/extreme_minecraft.dart';
import 'art/extreme_vocaloid.dart';
import 'simplify.dart';

/// Inside a course, Easy is open from the start and each harder level opens
/// once [unlockAfter] pictures of the level before it are finished. Inside a
/// level, each picture opens when the one before it is finished.
const unlockAfter = 3;

/// Canvas size for each difficulty.
const _sizes = {Difficulty.easy: 16, Difficulty.medium: 24, Difficulty.hard: 32, Difficulty.extreme: 40};

/// How far apart (CIE Lab ΔE) every two colors must be on Easy and Medium,
/// which also get a plain background. Hard keeps the full drawing: subtle
/// shades and busy backdrops are what make it hard.
const _minDistance = {Difficulty.easy: 22.0, Difficulty.medium: 16.0};

/// Smallest CIEDE2000 difference between any two drill colors.
const _minColorGap = {
  Difficulty.easy: 18.0,
  Difficulty.medium: 16.0,
  Difficulty.hard: 14.0,
  Difficulty.extreme: 12.0,
};

/// Every course, drawn once on first use.
final List<Course> allCourses = buildCourses();

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
          Difficulty.extreme: {
            'heart-balloons': xHeartBalloons,
            'picnic': xPicnic,
            'yarn-kitten': xYarnKitten,
            'carousel': xCarousel,
            'fireside': xFireside,
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
          Difficulty.extreme: {
            'hamster': xHamster,
            'koala': xKoala,
            'otter': xOtter,
            'lion': xLion,
            'fawn': xFawn,
          },
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
          Difficulty.extreme: {
            'pumpkin-patch': xPumpkinPatch,
            'butterfly-meadow': xButterflyMeadow,
            'mushroom-cottage': xMushroomCottage,
            'rose-arbor': xRoseArbor,
            'greenhouse': xGreenhouse,
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
          Difficulty.extreme: {
            'cupcake-party': xCupcakeParty,
            'strawberry-tart': xStrawberryTart,
            'hot-cocoa': xHotCocoa,
            'candy-house': xCandyHouse,
            'bakery': xBakery,
          },
        },
      ),
      _course(
        'catcafe',
        'Cat Café',
        'Cats, kittens and cozy café corners',
        const Color(0xFFD7B899),
        {
          Difficulty.easy: {
            'cafe-cat': cafeCat,
            'yarn-ball': yarnBall,
            'milk': milkSaucer,
            'paw-latte': pawLatte,
            'fish-treat': fishTreat,
          },
          Difficulty.medium: {
            'cat-nap': catNap,
            'tabby': tabby,
            'kitty-cupcake': kittyCupcake,
            'window-seat': windowSeat,
            'tuxedo': tuxedo,
          },
          Difficulty.hard: {
            'cat-loaf': catLoaf,
            'box-cat': boxCat,
            'calico': calico,
            'barista': barista,
            'cuddle-puddle': cuddlePuddle,
          },
          Difficulty.extreme: {
            'cafe-counter': xCafeCounter,
            'rainy-day': xRainyDay,
            'cat-tower': xCatTower,
            'tea-party': xTeaParty,
            'night-cafe': xNightCafe,
          },
        },
      ),
      _course(
        'minecraft',
        'Blocky World',
        'A Minecraft-inspired collection',
        const Color(0xFF8BC34A),
        {
          Difficulty.easy: {
            'grass-block': grassBlock,
            'creeper': creeper,
            'diamond': diamond,
            'apple': mcApple,
            'torch': torch,
          },
          Difficulty.medium: {'pickaxe': pickaxe, 'sword': mcSword, 'tnt': tnt, 'pig': pig, 'cake': mcCake},
          Difficulty.hard: {
            'overworld': overworld,
            'enderman': enderman,
            'nether-portal': netherPortal,
            'sheep': sheep,
            'cave': cave,
          },
          Difficulty.extreme: {
            'bee-meadow': xMcBeeMeadow,
            'ghast': xMcGhast,
            'lush-cave': xMcLushCave,
            'village': xMcVillage,
            'the-end': xMcTheEnd,
          },
        },
        special: true,
      ),
      _course(
        'vocaloid',
        'Virtual Stage',
        'A Vocaloid-inspired collection',
        const Color(0xFF4DD0C8),
        {
          Difficulty.easy: {
            'leek': leek,
            'note': musicNote,
            'headphones': headphones,
            'microphone': microphone,
            'orange': orange,
          },
          Difficulty.medium: {'miku': mikuFace, 'rin': rinFace, 'len': lenFace, 'luka': lukaFace, 'kaito': kaitoFace},
          Difficulty.hard: {
            'miku-live': mikuFull,
            'twins': rinLen,
            'concert': concert,
            'snow-miku': snowMiku,
            'sakura-miku': sakuraMiku,
          },
          Difficulty.extreme: {
            'kaito-ice-cream': xVocKaitoIceCream,
            'luka-tuna': xVocLukaTuna,
            'meiko-stage': xVocMeikoStage,
            'road-roller': xVocRoadRoller,
            'moonlit': xVocMoonlit,
          },
        },
        special: true,
      ),
      _course(
        'kpop',
        'K-Pop Stage',
        'Lightsticks, photocards and comeback stages',
        const Color(0xFFB388FF),
        {
          Difficulty.easy: {
            'lightstick': lightstick,
            'finger-heart': fingerHeart,
            'photocard': photocard,
            'album': album,
            'fan-banner': sloganBanner,
          },
          Difficulty.medium: {
            'main-vocal': mainVocal,
            'main-rapper': rapper,
            'photocard-binder': photocardBinder,
            'concert-ticket': concertTicket,
            'fan-letter': fanLetter,
          },
          Difficulty.hard: {
            'dance-practice': dancePractice,
            'lightstick-ocean': lightOcean,
            'comeback-stage': comebackStage,
            'photo-booth': photoBooth,
            'the-group': idolGroup,
          },
          Difficulty.extreme: {
            'stadium-night': xStadiumNight,
            'music-show': xMusicShow,
            'fan-cafe': xFanCafe,
            'award-night': xAwardNight,
            'encore-fireworks': xEncoreFireworks,
          },
        },
        special: true,
      ),
    ];

/// Pictures are keyed by a stable slug, so reordering or adding pictures
/// never moves saved progress onto a different one.
Course _course(
  String id,
  String title,
  String subtitle,
  Color accent,
  Map<Difficulty, Map<String, Artwork>> art, {
  bool special = false,
}) =>
    Course(
      special: special,
      id: id,
      title: title,
      subtitle: subtitle,
      accent: accent,
      levels: [
        for (final MapEntry(key: difficulty, value: pictures) in art.entries)
          Level(
            difficulty: difficulty,
            puzzles: [
              for (final MapEntry(key: slug, value: draw) in pictures.entries)
                _forDifficulty(draw('$id-$slug', _sizes[difficulty]!), difficulty),
            ],
          ),
      ],
    );

Puzzle _forDifficulty(Puzzle p, Difficulty difficulty) {
  final minDistance = _minDistance[difficulty];
  final simple = minDistance == null ? p : simplifyPicture(p, minDistance: minDistance);
  return separateColors(simple, minDistance: _minColorGap[difficulty]!);
}
