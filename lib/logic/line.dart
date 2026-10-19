/// Grid cells on the line between two cells (Bresenham), both ends included.
///
/// Used so a fast drag fills every cell it crosses, not just the ones the
/// touch events happened to land on.
Iterable<(int, int)> cellsOnLine((int, int) from, (int, int) to) sync* {
  var (x0, y0) = from;
  final (x1, y1) = to;
  final dx = (x1 - x0).abs(), dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;
  while (true) {
    yield (x0, y0);
    if (x0 == x1 && y0 == y1) return;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
}
