import '../models/puzzle.dart';

/// Shape art: a picture drawn from simple shapes in code, for courses not yet
/// on PNG art (lib/data/pictures.dart). By convention palette index 0 is the
/// background; colors a drawing never uses are dropped.
typedef Artwork = Puzzle Function(String id, int size);
