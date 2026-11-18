import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/courses.dart' show allCourses;
import '../logic/photo_frames.dart';
import '../logic/unlocks.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'picture_export.dart';

/// Earned the first time a picture is saved in a frame (PAP-43).
final frameItBadge = Achievement(
  'frame.it',
  'Frame it',
  'Save a picture in a photo frame',
  (f) => f.secrets.contains(framedSaveSecret),
  progress: (f) => BadgeProgress(f.secrets.contains(framedSaveSecret) ? 1 : 0, 1),
);

/// Adds [frameItBadge] to the badge engine. Call once at startup, before [baselineBadges].
void registerFrameBadge() => registerBadge(frameItBadge);

/// The frame in use for Save to Photos: the one picked, if it is open.
PhotoFrame usableFrame(BuildContext context) {
  final store = ProgressScope.of(context);
  return PhotoFrame.usable(SettingsScope.of(context).frame, store.currentUnlocks, store.secrets);
}

/// [child] in [frame], as large as fits, laid out as the saved picture is: the
/// frame scaled evenly and [child] (of [aspect], width over height) centred in
/// its opening. With no frame, or until the frame's art is measured, [child]
/// fills the space alone.
class FramedPreview extends StatelessWidget {
  const FramedPreview({
    super.key,
    required this.frame,
    required this.child,
    this.aspect = 1,
    this.paper = const Color(0xFFFFFBF7),
  });

  final PhotoFrame frame;
  final Widget child;
  final double aspect;

  /// Shows in the opening around [child], like the sheet of the saved picture.
  final Color paper;

  @override
  Widget build(BuildContext context) {
    final asset = frame.asset;
    if (asset == null) return child;
    return FutureBuilder<FrameGeometry>(
      // A new state per frame, so a switch never lays out one frame's art with another's opening.
      key: ValueKey(frame),
      future: FrameGeometry.of(frame),
      builder: (context, snap) {
        final g = snap.data;
        if (g == null) return child;
        return LayoutBuilder(builder: (context, box) {
          final b = g.bounds, w = g.window;
          // Art width in logical pixels so the visible art fits the box.
          final x = math.min(box.maxWidth / b.width, box.maxHeight * g.aspect / b.height);
          final y = x / g.aspect;
          final win = Rect.fromLTWH((w.left - b.left) * x, (w.top - b.top) * y, w.width * x, w.height * y);
          final room = Size(win.width * windowFill, win.height * windowFill);
          final fit = room.width / room.height > aspect
              ? Size(room.height * aspect, room.height)
              : Size(room.width, room.width / aspect);
          return Center(
            child: SizedBox(
              width: b.width * x,
              height: b.height * y,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fromRect(rect: win, child: ColoredBox(color: paper)),
                  Positioned.fromRect(
                      rect: Rect.fromCenter(center: win.center, width: fit.width, height: fit.height), child: child),
                  Positioned(
                    left: -b.left * x,
                    top: -b.top * y,
                    width: x,
                    height: y,
                    child: IgnorePointer(child: Image.asset('assets/art/frames/$asset.png', fit: BoxFit.fill)),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

/// A row of frames to pick for Save to Photos. Locked frames show how to earn
/// them; the hidden frame is left out until its secret is found.
class FramePicker extends StatefulWidget {
  const FramePicker({super.key});

  @override
  State<FramePicker> createState() => _FramePickerState();
}

class _FramePickerState extends State<FramePicker> {
  /// What to say under the row after a locked frame is tapped.
  String? _hint;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final settings = SettingsScope.of(context);
    final unlocks = store.currentUnlocks;
    final secrets = store.secrets;
    final chosen = usableFrame(context);
    final pictures = allCourses.fold(0, (n, c) => n + c.puzzles.length);
    final text = Theme.of(context).textTheme;
    final frames = PhotoFrame.values.where((f) => f.isVisible(secrets)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Photo frame', style: text.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          // Tile, gap and a label that grows with the text size setting.
          height: math.max(96, 76 + MediaQuery.textScalerOf(context).scale((text.labelSmall?.fontSize ?? 11) * 1.5)),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: frames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = frames[i];
              final open = f.isOpen(unlocks, secrets);
              final need = f.threshold(pictures);
              final hint = need == null ? null : _lockedHint(f, need, unlocks, pictures);
              return _FrameTile(
                frame: f,
                open: open,
                selected: f == chosen,
                lockedHint: hint,
                onTap: () {
                  settings.selection();
                  setState(() => _hint = open ? null : hint);
                  if (open) settings.setFrame(f);
                },
              );
            },
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _hint == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(_hint!, style: text.bodySmall, textAlign: TextAlign.center),
                ),
        ),
      ],
    );
  }
}

String _lockedHint(PhotoFrame f, int need, UnlockState unlocks, int pictures) {
  final have = threeStarPictures(unlocks, pictures);
  final so = have == null ? '' : ' You have $have so far.';
  return 'Earn 3 stars on $need pictures to unlock ${f.label}.$so';
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.frame,
    required this.open,
    required this.selected,
    required this.onTap,
    this.lockedHint,
  });

  final PhotoFrame frame;
  final bool open;
  final bool selected;
  final String? lockedHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final asset = frame.asset;
    final Widget art = asset == null
        ? Icon(Icons.crop_free_rounded, size: 32, color: scheme.onSurfaceVariant)
        : Image.asset('assets/art/frames/$asset.png', width: 52, height: 52, fit: BoxFit.contain);
    // Top-aligned, so the ink stays the size of the tile, not the row.
    return Align(
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        selected: selected,
        label: open ? frame.label : '${frame.label}, locked. ${lockedHint ?? ''}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: open ? 1 : 0.35, child: art),
                      if (!open)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.lock_rounded, size: 18, color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  frame.label,
                  style: text.labelSmall?.copyWith(color: open ? null : scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
