/// Photo frames for pictures saved to Photos (PAP-43). Pure rules, no Flutter.
library;

import 'unlocks.dart';

/// Secret the PAP-45 hidden trigger adds; it shows the hidden frame.
const secretFrameId = 'secret.frame';

/// Secret added on the first framed save; it earns the Frame it badge.
const framedSaveSecret = 'frame.saved';

/// 3-star pictures she has, read back from the next reward, in a build of
/// [pictureCount] pictures. Null once every reward is open.
int? threeStarPictures(UnlockState unlocks, int pictureCount) {
  final next = unlocks.nextReward;
  if (next == null) return null;
  final r = _reward(next.id);
  return r == null ? null : UnlockTables.scaled(r.threshold, pictureCount) - next.remaining;
}

Reward? _reward(String? id) => UnlockTables.rewards.where((r) => r.id == id).firstOrNull;

/// A frame drawn around a saved picture. [none] saves the picture as before.
enum PhotoFrame {
  none('No frame'),
  wood('Wood'),
  // Its star-and-cat sticker overlaps the photo's bottom-left corner on purpose.
  polaroid('Polaroid', rewardId: 'reward.frame.polaroid'),
  lace('Lace', rewardId: 'reward.frame.lace'),
  paw('Paw print', rewardId: 'reward.frame.paw'),
  secret('Secret', secretId: secretFrameId);

  const PhotoFrame(this.label, {this.rewardId, this.secretId});

  final String label;

  /// The 3-star reward that opens it, from the PAP-14 tables.
  final String? rewardId;

  /// The secret that reveals it. Until then it is not shown at all.
  final String? secretId;

  /// The art's file name, without folder or extension. Null for [none].
  String? get asset => this == none ? null : 'frame_photo_$name';

  /// Open to use, given what is unlocked and the secrets found.
  bool isOpen(UnlockState unlocks, Set<String> secrets) {
    final r = rewardId, s = secretId;
    if (r != null) return unlocks.isUnlocked(r);
    if (s != null) return secrets.contains(s);
    return true;
  }

  /// Shown in the picker: everything but a hidden frame that is still a secret.
  bool isVisible(Set<String> secrets) => secretId == null || secrets.contains(secretId);

  /// 3-star pictures needed in a build of [pictureCount] pictures, or null when no reward opens it.
  int? threshold(int pictureCount) {
    final r = _reward(rewardId);
    return r == null ? null : UnlockTables.scaled(r.threshold, pictureCount);
  }

  /// [chosen] if it is open, or no frame. A save can hold a frame that is not open
  /// (an older build, or a save copied from another phone).
  static PhotoFrame usable(PhotoFrame chosen, UnlockState unlocks, Set<String> secrets) =>
      chosen.isOpen(unlocks, secrets) ? chosen : none;
}
