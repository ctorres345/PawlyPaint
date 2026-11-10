import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'art/extreme_minecraft.dart';
import 'art/extreme_vocaloid.dart';
import 'art/kpop.dart';
import 'art/minecraft.dart';
import 'art/vocaloid.dart';
import 'course_builder.dart';

/// Ids of the courses only the sideload build has: fan art and the private
/// gift course. The store build leaves them out. Use this only in tests: the
/// ids are strings, so using them in `lib/` puts the names back in the store
/// binary.
const sideloadOnlyCourseIds = {'minecraft', 'vocaloid', 'kpop'};

/// Courses the store build does not ship. Saved progress for them is kept.
List<Course> sideloadOnlyCourses() => [
      buildCourse(
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
      buildCourse(
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
      buildCourse(
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
