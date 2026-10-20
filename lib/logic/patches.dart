/// The biggest group of side-by-side [cells] on a [width]-wide board, so
/// "find next" can lead to the patch with the most painting left.
/// Ties go to the group found first.
List<int> largestPatch(int width, int height, Iterable<int> cells) {
  final open = cells.toSet();
  var best = <int>[];
  while (open.isNotEmpty) {
    final start = open.first;
    open.remove(start);
    final patch = [start];
    for (var k = 0; k < patch.length; k++) {
      final i = patch[k], x = i % width;
      for (final n in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (i >= width) i - width,
        if (i + width < width * height) i + width,
      ]) {
        if (open.remove(n)) patch.add(n);
      }
    }
    if (patch.length > best.length) best = patch;
  }
  return best;
}
