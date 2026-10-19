import '../models/puzzle.dart';
import 'art_canvas.dart';

/// A tiny heart used to teach both modes.
Puzzle tutorialPuzzle() {
  // The heart comes first so the first color taught is the fun one.
  const red = 0, bg = 1, shine = 2;
  final c = ArtCanvas(8, 8, background: bg);
  c.heart(0.5, 0.52, 0.42, red);
  c.dot(0.3, 0.35, shine);
  return c.toPuzzle(id: 'tutorial-heart', title: 'First Heart', palette: const [0xFFE53950, 0xFFFCE4EC, 0xFFFFB3C1]);
}
