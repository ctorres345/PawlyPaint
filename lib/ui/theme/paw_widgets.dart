import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/puzzle.dart';
import '../../state/achievements.dart' show BadgeTier;
import 'tokens.dart';

// The sticker look of the menus (PAP-19 canvas, Home C): thick outlines, a
// solid "lip" shadow in the outline color, pill shapes and Mochi art. Every
// color comes from [PawTokens].

/// The solid lip under a sticker, [dy] pixels deep.
List<BoxShadow> lip(PawTokens t, [double dy = 4]) => [BoxShadow(color: t.outline, offset: Offset(0, dy))];

/// The art for a course, under `assets/art/`.
String courseArt(Course c) => switch (c.id) {
      'classics' => 'courses/classics.png',
      'animals' => 'courses/animals.png',
      'garden' => 'courses/garden.png',
      'sweets' => 'courses/sweets.png',
      'catcafe' => 'courses/cafe.png',
      _ => 'mochi/avatar.png',
    };

/// The background tint a course wears.
CourseTint courseTintOf(Course c) => switch (c.id) {
      'classics' || 'kpop' => CourseTint.pink,
      'animals' => CourseTint.orange,
      'garden' || 'minecraft' => CourseTint.green,
      'sweets' || 'vocaloid' => CourseTint.purple,
      _ => CourseTint.tan,
    };

/// Mochi's face for a difficulty, under `assets/art/`.
String difficultyArt(Difficulty d) => 'difficulty/${d.name}.png';

/// Art from `assets/art/`, decorative unless [label] is set.
class Art extends StatelessWidget {
  const Art(this.path, {super.key, required this.size, this.label, this.gray = false});

  final String path;
  final double size;
  final String? label;

  /// Locked look: gray and faint.
  final bool gray;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/art/$path',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: label,
      excludeFromSemantics: label == null,
    );
    if (gray) {
      img = Opacity(
        opacity: .55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: img,
        ),
      );
    }
    return img;
  }
}

/// A tilted pill heading with Mochi art: "Courses", "Keep painting" and so on.
class StickerTitle extends StatelessWidget {
  const StickerTitle({
    super.key,
    this.art = '',
    required this.text,
    this.color,
    this.foreground,
    this.artSize = 26,
    this.gray = false,
    this.icon,
    this.fontSize = 18,
  });

  /// 19 or more counts as large bold text, which needs only 3:1 contrast
  /// (the Hard purple with dark ink).
  final double fontSize;

  /// Path under `assets/art/`.
  final String art;

  /// A Material icon in place of [art] (Settings uses icons).
  final IconData? icon;
  final String text;

  /// Fill and text color; the accent pair when null.
  final Color? color;
  final Color? foreground;
  final double artSize;

  /// Locked look: gray art.
  final bool gray;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    // Fixed height: the text stops growing at 1.3x so it is not cut off.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        header: true,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              height: 38,
              padding: const EdgeInsets.only(left: 6, right: 16),
              decoration: BoxDecoration(
                color: color ?? t.accent,
                borderRadius: BorderRadius.circular(PawRadius.pill),
                border: Border.all(color: t.outline, width: 3),
                boxShadow: lip(t, 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(icon, size: 24, color: foreground ?? t.onAccent)
                  else
                    Art(art, size: artSize, gray: gray),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: foreground ?? t.onAccent, fontSize: fontSize, fontWeight: FontWeight.w800, height: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sticker title on the left and an optional chip on the right.
class StickerHeader extends StatelessWidget {
  const StickerHeader({super.key, required this.title, this.trailing});

  final StickerTitle title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: title),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      );
}

/// A small outlined pill: "★ 24 / 960", "3 days", "3 in progress".
class MiniChip extends StatelessWidget {
  const MiniChip({super.key, required this.label, this.icon, this.iconColor, this.semanticLabel});

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    // Fixed height: the text stops growing at 1.3x so it is not cut off.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: Container(
          height: 24,
          padding: EdgeInsets.only(left: icon == null ? 8 : 4, right: 8),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(PawRadius.pill),
            border: Border.all(color: t.outline, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: iconColor ?? t.star), const SizedBox(width: 3)],
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.ink, height: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded chip (PAP-19 `.chip`): the Course and Gallery counts, "Locked"
/// and the Gallery filters. Selected chips take the accent pair.
class PawChip extends StatelessWidget {
  const PawChip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.color,
    this.selected = false,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;

  /// Fill when not selected; the tint when null.
  final Color? color;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final fg = selected ? t.onAccent : t.ink;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.accent : color ?? t.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: selected ? fg : iconColor ?? t.star),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// A big pill button with a lip: "Paint", "Race".
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(PawRadius.pill), boxShadow: lip(t)),
      child: Material(
        color: color,
        shape: StadiumBorder(side: BorderSide(color: t.outline, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded square sticker button for the top bar (music, settings).
class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        // 44 pt to touch, 40 pt to see.
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: lip(t, 2)),
              child: Material(
                color: t.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.outline, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: onPressed, child: Icon(icon, size: 22, color: t.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Her name and title in a 146 pt pill with a gold medal (PAP-20). A name or
/// title too wide for it (wide letters, large text) shrinks instead of wrapping or clipping.
class Nameplate extends StatelessWidget {
  const Nameplate({super.key, required this.name, required this.title, required this.tier, this.onTap});

  static const width = 146.0;

  final String name;
  final String title;

  /// The tier of the badge that gives [title]: it colors the medal. Null for the starter title.
  final BadgeTier? tier;

  /// Opens Badges from Home; null where it is only shown (on Badges itself).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final medal = tier == null ? null : t.tiers[tier]!;
    return Semantics(
      button: onTap != null,
      label: 'Your nameplate: $name, $title${onTap == null ? '' : '. Opens Badges'}',
      excludeSemantics: true,
      // A fixed 146 x 44 pill: its text stops growing at 1.3x so two lines still fit.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          width: width,
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(PawRadius.pill), boxShadow: lip(t, 2)),
          child: Material(
            color: t.surface,
            shape: StadiumBorder(side: BorderSide(color: t.outline, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 3, right: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: medal?.fill ?? t.tint,
                        shape: BoxShape.circle,
                        border: Border.all(color: medal?.frame ?? t.outline, width: 2),
                      ),
                      child: Icon(Icons.workspace_premium_rounded, size: 20, color: medal?.frame ?? t.muted),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.1, color: t.ink),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: medal?.text ?? t.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill on a hero card's top edge: "Today's picture", "Time Attack".
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.icon, required this.label, required this.color, required this.foreground});

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    // Fixed height: the text stops growing at 1.3x so it is not cut off.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(PawRadius.pill),
          border: Border.all(color: t.outline, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: foreground, height: 1)),
          ],
        ),
      ),
    );
  }
}

/// A sticker card with a thick outline, a lip and sun rays, and an optional
/// [tag] on its top edge.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.color,
    required this.child,
    this.tag,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(12, 20, 12, 12),
    this.semanticLabel,
  });

  final Color color;
  final Widget child;
  final Widget? tag;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final card = Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: lip(t)),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: t.outline, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _Burst(t.surface.withValues(alpha: .38)),
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
    final body = tag == null
        ? card
        : Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [card, Positioned(top: -13, left: 12, child: ExcludeSemantics(child: tag!))],
          );
    if (semanticLabel == null) return body;
    return Semantics(label: semanticLabel, button: onTap != null, child: body);
  }
}

/// Still sun rays from the top right corner, like the prototype's conic burst.
class _Burst extends CustomPainter {
  const _Burst(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .82, size.height * .18);
    final r = size.longestSide * 1.5;
    final paint = Paint()..color = color;
    const step = 18 * math.pi / 180;
    for (var a = 0.0; a < 2 * math.pi; a += step) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.sin(a), c.dy - r * math.cos(a))
        ..lineTo(c.dx + r * math.sin(a + step / 2), c.dy - r * math.cos(a + step / 2))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Burst old) => old.color != color;
}

/// A rounded progress bar.
class PawBar extends StatelessWidget {
  const PawBar({super.key, required this.value, this.track, this.height = 6});

  final double value;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PawRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: t.accent,
        backgroundColor: track ?? t.tint,
      ),
    );
  }
}

/// The places the dock goes.
enum DockItem {
  home('Home', 'brand/mark_light.png'),
  gallery('Gallery', 'icons/gallery.png'),
  unlocks('Unlocks', 'icons/unlock.png'),
  badges('Badges', 'icons/badge.png');

  const DockItem(this.label, this.art);

  final String label;
  final String art;
}

/// Keeps a play screen (Paint, Sort, Time Attack) in the light Latte look. They
/// still draw some light-only colors, so they follow dark mode only once PAP-22
/// restyles them. Wrap the whole stateful page in it, so dialogs and sheets
/// opened from the page's own context take this theme too.
class LightPlayTheme extends StatelessWidget {
  const LightPlayTheme({super.key, required this.builder});

  static final _theme = pawTheme(PawTokens.latte, Brightness.light);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Theme(data: _theme, child: Builder(builder: builder));
}

/// The floating game dock at the bottom of Home (PAP-19 Home C).
class PawDock extends StatelessWidget {
  const PawDock({super.key, required this.onSelect, this.dots = const {}});

  static const height = 68.0;

  final ValueChanged<DockItem> onSelect;

  /// Items with something new to see.
  final Set<DockItem> dots;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: 'Main',
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: t.outline, width: 3),
          boxShadow: lip(t),
        ),
        // The buttons scale down together on phones under about 342 pt, and the
        // labels stop growing at 1.3x so they stay inside the fixed buttons.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in DockItem.values)
                // Shares the width in proportion to the buttons' own widths (84 and 72).
                Flexible(
                  flex: item == DockItem.home ? 84 : 72,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _DockButton(
                      item: item,
                      art: item == DockItem.home && dark ? 'brand/mark_dark.png' : item.art,
                      on: item == DockItem.home,
                      dot: dots.contains(item),
                      onTap: () => onSelect(item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.item, required this.art, required this.on, required this.dot, required this.onTap});

  final DockItem item;
  final String art;
  final bool on;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final label = Text(
      item.label,
      maxLines: 1,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? t.onAccent : t.muted, height: 1.1),
    );
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [Art(art, size: on ? 40 : 38), const SizedBox(height: 1), label],
        ),
        if (dot)
          Positioned(
            top: -2,
            right: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
                border: Border.all(color: t.surface, width: 2),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      button: true,
      selected: on,
      label: dot ? '${item.label}, something new' : item.label,
      excludeSemantics: true,
      child: on
          // Lays out in the 62 pt row like the others (so the dock only shrinks for
          // width), and rises 78 pt tall above it.
          ? SizedBox(
              width: 84,
              height: 62,
              child: OverflowBox(
                minHeight: 78,
                maxHeight: 78,
                child: Transform.translate(
                  offset: const Offset(0, -13),
                  child: Container(
                    width: 84,
                    height: 78,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: lip(t)),
                    child: Material(
                      color: t.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: t.outline, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(onTap: onTap, child: Center(child: content)),
                    ),
                  ),
                ),
              ),
            )
          : SizedBox(
              width: 72,
              height: 62,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Center(child: content),
              ),
            ),
    );
  }
}

/// A pill segmented control on a tint track (PAP-19 `.seg`).
class PawSegmented<T> extends StatelessWidget {
  const PawSegmented({super.key, required this.items, required this.selected, required this.onSelect});

  /// Value, label and icon of each segment.
  final List<(T, String, IconData)> items;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(PawRadius.pill)),
      child: Row(
        children: [
          for (final (value, label, icon) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                label: label,
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      shadows: value == selected ? t.shadow : null,
                    ),
                    child: Material(
                      color: value == selected ? t.surface : Colors.transparent,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(value),
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 18, color: value == selected ? t.accent : t.ink),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: value == selected ? t.accent : t.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three stars: earned ones in star color, the rest as muted outlines.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 16});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var s = 0; s < 3; s++)
          s < stars
              ? Icon(Icons.star_rounded, size: size, color: t.star)
              : Icon(Icons.star_outline_rounded, size: size, color: t.muted),
      ],
    );
  }
}
