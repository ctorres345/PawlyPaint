import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../logic/photo_frames.dart';
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'effect_clock.dart';
import 'frame_picker.dart';
import 'gem_style.dart';
import 'picture_export.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';
import 'unlock_ui.dart' show picturesWord;

/// Which finished pictures the Gallery shows.
enum GalleryFilter {
  all('All'),
  paint('Paint'),
  sort('Sort'),
  threeStars('3 stars');

  const GalleryFilter(this.label);

  final String label;
}

/// Best stars for [p] in [mode], or in either mode when [mode] is null.
int bestStars(ProgressStore store, Puzzle p, [PlayMode? mode]) =>
    (mode == null ? PlayMode.values : [mode]).map((m) => store.record(m.key(p.id))?.bestStars ?? 0).fold(0, math.max);

/// Every finished picture, to admire, course by course (PAP-19 "Gallery" board).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  GalleryFilter _filter = GalleryFilter.all;

  bool _shows(ProgressStore store, Puzzle p) => switch (_filter) {
        GalleryFilter.all => store.isDone(p.id),
        GalleryFilter.paint => store.isDone(p.id, PlayMode.paint),
        GalleryFilter.sort => store.isDone(p.id, PlayMode.sort),
        GalleryFilter.threeStars => bestStars(store, p) == 3,
      };

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final t = context.paw;
    final text = Theme.of(context).textTheme;
    final courses = widget.courses;
    final total = courses.fold(0, (s, c) => s + c.puzzles.length);
    final finished = courses.fold(0, (s, c) => s + store.completedIn(c.puzzles));
    final mode = switch (_filter) {
      GalleryFilter.paint => PlayMode.paint,
      GalleryFilter.sort => PlayMode.sort,
      _ => null,
    };
    final sections = [
      for (final c in courses)
        if (c.puzzles.where((p) => _shows(store, p)).toList() case final shown when shown.isNotEmpty) (c, shown),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PawChip(
              icon: Icons.photo_library_rounded,
              iconColor: t.ink,
              label: '$finished / $total',
              semanticLabel: '$finished of $total pictures finished',
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in GalleryFilter.values)
                    _FilterChip(filter: f, selected: f == _filter, onTap: () => setState(() => _filter = f)),
                ],
              ),
            ),
          ),
          if (sections.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Art('mochi/painting.png', size: 96),
                    const SizedBox(height: 12),
                    Text(
                      finished == 0 ? 'Finished pictures will hang here.' : 'No pictures match this filter yet.',
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final (course, shown) in sections) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: StickerHeader(
                    title: StickerTitle(art: courseArt(course), text: course.title, artSize: 30),
                    trailing: MiniChip(label: '${shown.length} of ${course.puzzles.length}'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .82,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final p in shown) _PictureTile(course: course, puzzle: p, stars: bestStars(store, p, mode)),
                    // Counts pictures not finished in any mode, whatever the filter hides.
                    if (course.puzzles.length - store.completedIn(course.puzzles) case final left when left > 0)
                      _MysteryTile(left: left),
                  ]),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                child: Text(
                  'The ? tile counts the pictures still to paint. Tap a finished one to see it big.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.filter, required this.selected, required this.onTap});

  final GalleryFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: filter.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // 32 to see, padded to 44 to touch.
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: PawChip(
              label: filter.label,
              icon: filter == GalleryFilter.threeStars ? Icons.star_rounded : null,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({required this.course, required this.puzzle, required this.stars});

  final Course course;
  final Puzzle puzzle;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      button: true,
      label: '${puzzle.title}, from ${course.title}, $stars ${stars == 1 ? 'star' : 'stars'}',
      excludeSemantics: true,
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.tile),
          side: BorderSide(color: t.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PictureViewer(puzzle: puzzle, course: course)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              children: [
                Expanded(
                  child: Hero(
                    tag: 'gallery-${puzzle.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                          painter: PuzzleThumbPainter(puzzle, complete: true), child: const SizedBox.expand()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                StarRow(stars: stars),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pictures of a course still to finish, as one gray tile.
class _MysteryTile extends StatelessWidget {
  const _MysteryTile({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      label: '$left more ${picturesWord(left)} to finish',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(PawRadius.tile),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Icon(Icons.help_rounded, size: 40, color: t.muted),
              ),
            ),
            const SizedBox(height: 4),
            Text('+$left', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.muted, height: 1.33)),
          ],
        ),
      ),
    );
  }
}

/// One finished picture, full size, with its shimmer.
class PictureViewer extends StatefulWidget {
  const PictureViewer({super.key, required this.puzzle, required this.course});

  final Puzzle puzzle;
  final Course course;

  @override
  State<PictureViewer> createState() => _PictureViewerState();
}

class _PictureViewerState extends State<PictureViewer> {
  late final EffectClock _shimmer = EffectClock(idleAfter: const Duration(seconds: 30))..poke();
  late final paints = GemPaints.forPuzzle(widget.puzzle, SettingsScope.read(context).shape);
  final _cache = _GemsCache();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shimmer.follow(context);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    final frame = usableFrame(context);
    Widget stars(PlayMode mode) {
      final r = store.record(mode.key(widget.puzzle.id));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${mode.label} ', style: text.labelLarge),
          StarRow(stars: r?.bestStars ?? 0, size: 20),
        ],
      );
    }

    return Scaffold(
      backgroundColor: SettingsScope.of(context).theme.desk,
      appBar: AppBar(title: Text(widget.puzzle.title), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.puzzle.width / widget.puzzle.height,
                    child: Hero(
                      tag: 'gallery-${widget.puzzle.id}',
                      child: FramedPreview(
                        frame: frame,
                        aspect: widget.puzzle.width / widget.puzzle.height,
                        paper: SettingsScope.of(context).theme.sheet,
                        child: Material(
                          elevation: frame == PhotoFrame.none ? 8 : 0,
                          borderRadius: BorderRadius.circular(frame == PhotoFrame.none ? 16 : 4),
                          color: SettingsScope.of(context).theme.sheet,
                          child: Padding(
                            // In a frame, its opening already leaves room around the gems.
                            padding: EdgeInsets.all(frame == PhotoFrame.none ? 12 : 0),
                            child: Listener(
                              onPointerDown: (_) => _shimmer.poke(),
                              child: CustomPaint(
                                painter: _FinishedPainter(widget.puzzle, paints, _shimmer, _cache),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(widget.course.title, style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 24, children: [stars(PlayMode.paint), stars(PlayMode.sort)]),
            const SizedBox(height: 12),
            const FramePicker(),
            SavePictureButton(puzzle: widget.puzzle),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// The finished gems, recorded once and replayed under the shimmer.
class _GemsCache {
  ui.Picture? picture;
  Object? key;

  void dispose() {
    picture?.dispose();
    picture = null;
  }
}

class _FinishedPainter extends CustomPainter {
  _FinishedPainter(this.puzzle, this.paints, this.shimmer, this.cache) : super(repaint: shimmer);

  final Puzzle puzzle;
  final List<GemPaints> paints;
  final ValueListenable<double> shimmer;
  final _GemsCache cache;
  final CanvasTheme _theme = canvasTheme;
  Object get look => (_theme, paints.first.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final cs = math.min(size.width / puzzle.width, size.height / puzzle.height);
    Rect cell(int i) => Rect.fromLTWH((i % puzzle.width) * cs, (i ~/ puzzle.width) * cs, cs, cs);
    final key = (size, look);
    if (cache.key != key || cache.picture == null) {
      cache.dispose();
      cache.key = key;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < puzzle.cellCount; i++) {
        drawGem(c, cell(i), paints[puzzle.cells[i]]);
      }
      cache.picture = rec.endRecording();
    }
    canvas.drawPicture(cache.picture!);

    // Only the moving light is drawn each frame.
    final t = shimmer.value;
    final span = (puzzle.width + puzzle.height).toDouble();
    final band = t * 1.6 - 0.3;
    for (var i = 0; i < puzzle.cellCount; i++) {
      final x = i % puzzle.width, y = i ~/ puzzle.width;
      final shine = (1 - ((x + y) / span - band).abs() / 0.07).clamp(0.0, 1.0);
      if (shine > 0) drawGemShine(canvas, cell(i), shine, paints.first.shape);
      final hash = (i * 2654435761) & 0xFFFF;
      if (hash % 5 == 0) {
        final s = math.sin(2 * math.pi * (t * 3 + hash / 0xFFFF));
        if (s > 0.94) drawGemSparkle(canvas, cell(i), (s - 0.94) / 0.06);
      }
    }
  }

  @override
  bool shouldRepaint(_FinishedPainter old) => old.puzzle != puzzle || old.look != look;
}
