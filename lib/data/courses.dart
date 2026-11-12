import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'art/animals.dart';
import 'art/catcafe.dart';
import 'art/garden.dart';
import 'art/sweets.dart';
import 'artworks.dart';
import 'art/extreme_classics.dart';
import 'art/extreme_animals.dart';
import 'art/extreme_garden.dart';
import 'art/extreme_sweets.dart';
import 'build_flavor.dart';
import 'course_builder.dart';
import 'sideload_courses.dart';

export 'sideload_courses.dart' show sideloadOnlyCourseIds;

/// Inside a course, Easy is open from the start and each harder level opens
/// once [unlockAfter] pictures of the level before it are finished. Inside a
/// level, each picture opens when the one before it is finished.
const unlockAfter = 3;

/// Every course this build ships, drawn once on first use. The store build
/// leaves out the sideload-only courses; the compiler drops their art because
/// `isStoreBuild` is a constant. Keep the explicit `if (!isStoreBuild)` and
/// don't swap it for `buildCourses(...)`.
final List<Course> allCourses = [...sharedCourses(), if (!isStoreBuild) ...sideloadOnlyCourses()];

/// The courses both builds ship. The game shows them all today; the star gates
/// in `lib/logic/unlocks.dart` (PAP-15) are rules only until PAP-41 uses them.
List<Course> sharedCourses() => [
      buildCourse(
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
      buildCourse(
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
      buildCourse(
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
      buildCourse(
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
      buildCourse(
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
    ];

/// Every course for tests: the store list, or the sideload list with all.
List<Course> buildCourses({bool store = false}) => [...sharedCourses(), if (!store) ...sideloadOnlyCourses()];
