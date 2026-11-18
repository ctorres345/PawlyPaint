/// Names, art and words for the 3-star rewards (PAP-38). The rules live in
/// `logic/unlocks.dart`; this only says how each reward looks on the Unlocks
/// screen and in its celebration.
library;

import '../logic/photo_frames.dart';
import '../logic/unlocks.dart';

class RewardInfo {
  const RewardInfo(this.name, this.kind, this.art, this.blurb, this.cheer);

  final String name;

  /// What sort of thing it is, like "Background".
  final String kind;

  /// The art's path under `assets/art/`.
  final String art;

  /// One sentence for the celebration.
  final String blurb;

  /// What Mochi says when it opens.
  final String cheer;
}

/// Whether the build has [r]'s content yet. Until then the Unlocks screen and
/// the celebration say it is on its way. Frames shipped in PAP-43; the content
/// tickets (PAP-16, PAP-44 to PAP-47) add theirs here.
bool rewardReady(Reward r) => _shipped.contains(r.id);

final _shipped = {
  for (final f in PhotoFrame.values)
    if (f.rewardId != null) f.rewardId!,
};

const _info = {
  'reward.bg.sakura': RewardInfo('Sakura canvas', 'Background', 'icons/canvas.png',
      'Soft cherry blossoms behind your pictures.', 'Pretty in pink!'),
  'reward.palette.matcha': RewardInfo('Matcha palette', 'Palette', 'icons/palette_matcha.png',
      'A calm green look for the whole app.', 'Green tea time!'),
  'reward.frame.polaroid': RewardInfo('Polaroid frame', 'Photo frame', 'frames/frame_photo_polaroid.png',
      'Save your pictures to Photos like an instant photo.', 'Say cheese!'),
  'reward.drill.heart':
      RewardInfo('Heart drills', 'Drill shape', 'icons/gems.png', 'Place your gems as little hearts.', 'So much love!'),
  'reward.drill.glitter':
      RewardInfo('Glitter drills', 'Drill shape', 'icons/gems.png', 'Gems with an extra sparkle.', 'Sparkle sparkle!'),
  'reward.bg.ocean': RewardInfo(
      'Ocean canvas', 'Background', 'icons/canvas.png', 'Gentle waves behind your pictures.', 'Splish splash!'),
  'reward.palette.midnight': RewardInfo('Midnight Café palette', 'Palette', 'icons/palette_midnight.png',
      'A cozy evening look for the whole app.', 'Night owl mode!'),
  'reward.frame.lace': RewardInfo('Lace frame', 'Photo frame', 'frames/frame_photo_lace.png',
      'A delicate lace border for saved pictures.', 'So fancy!'),
  'reward.secret.song':
      RewardInfo('Secret song', 'Music', 'mochi/music.png', 'A new tune to paint along to.', "Let's dance!"),
  'reward.drill.pastel':
      RewardInfo('Pastel drills', 'Drill shape', 'icons/gems.png', 'Gems in soft candy colors.', 'Sweet as candy!'),
  'reward.bg.starry': RewardInfo('Starry canvas', 'Background', 'icons/canvas.png',
      'A night sky full of stars behind your pictures.', 'Wish upon a star!'),
  'reward.frame.paw': RewardInfo('Paw print frame', 'Photo frame', 'frames/frame_photo_paw.png',
      'Little paw prints around saved pictures.', 'Paws up!'),
  'reward.mochi.outfit':
      RewardInfo('Mochi outfit', 'For Mochi', 'mochi/happy.png', 'A new outfit for Mochi.', 'Do I look cute?'),
  'reward.drill.holographic': RewardInfo(
      'Holographic drills', 'Drill shape', 'icons/gems.png', 'Gems that shimmer with every color.', 'Shiny!'),
  'reward.palette.strawberry': RewardInfo('Strawberry Milk palette', 'Palette', 'icons/palette_strawberry.png',
      'A sweet pink look for the whole app.', 'Berry nice!'),
  'reward.drill.golden': RewardInfo(
      'Golden drills', 'Drill shape', 'icons/gems.png', 'Gems of pure gold, for a true master.', "You're a legend!"),
};

/// How [r] looks. Every reward in [UnlockTables.rewards] has an entry (a test checks).
RewardInfo rewardInfo(Reward r) => _info[r.id]!;

/// The reward with [id], or null.
Reward? rewardById(String id) => UnlockTables.rewards.where((r) => r.id == id).firstOrNull;

/// Every reward id that has art and words, for the test.
Iterable<String> get describedRewardIds => _info.keys;
