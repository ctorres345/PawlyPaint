/// Paint-mode helpers that place drills for you. They are earned by
/// finishing pictures, never bought, and don't affect stars.
enum Booster {
  bomb('Bomb', 'Tap the canvas to fill every spot around it.'),
  wand('Magic wand', 'Fills every spot of the selected color.'),
  brush('Wide brush', 'Paints 3 spots wide until this color is done.');

  const Booster(this.label, this.help);

  final String label;
  final String help;

  /// Boosters she starts with, so they can be tried right away.
  static const starter = {Booster.bomb: 3, Booster.wand: 2, Booster.brush: 2};
}

/// Boosters earned for finishing a Paint picture. Only the first finish of a
/// picture pays out, so replays can't be farmed.
/// Hard and Extreme canvases ([width] 32 and up) add a magic wand.
Map<Booster, int> boosterReward({required int width, required int stars, required bool daily}) {
  final r = {Booster.bomb: 1};
  if (stars >= 3) r[Booster.brush] = 1;
  if (width >= 32) r[Booster.wand] = 1;
  if (daily) r[Booster.wand] = (r[Booster.wand] ?? 0) + 1;
  return r;
}

/// Bomb blast radius in cells: a little wider on the big canvases.
int bombRadius(int width) => width >= 32 ? 3 : 2;

/// Cells within [radius] of ([cx], [cy]), as a round blob, clipped to the board.
List<int> cellsInBlast(int width, int height, int cx, int cy, int radius) => [
      for (var y = cy - radius; y <= cy + radius; y++)
        for (var x = cx - radius; x <= cx + radius; x++)
          if (x >= 0 &&
              y >= 0 &&
              x < width &&
              y < height &&
              (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius + radius)
            y * width + x,
    ];
