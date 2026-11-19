import 'package:flutter/material.dart';

import '../data/tutorial.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'badges_screen.dart' show editPlayerName;
import 'desk.dart';
import 'game_screen.dart';
import 'gem_style.dart';
import 'music_sheet.dart';
import 'sort_screen.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';

/// Theme, canvas and drills, play options, her name and the tutorials
/// (PAP-19 "Settings" board).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = context.paw;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const _Section(icon: Icons.palette_rounded, text: 'Look'),
            _Card(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Theme'),
                  const SizedBox(height: 8),
                  PawSegmented<ThemeMode>(
                    items: const [
                      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                    ],
                    selected: settings.themeMode,
                    onSelect: settings.setThemeMode,
                  ),
                  const SizedBox(height: 18),
                  const _Label('Canvas'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in CanvasTheme.values)
                        Expanded(
                          child: _Option(
                            label: c.label,
                            selected: settings.theme == c,
                            onTap: () => settings.setTheme(c),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(PawRadius.chip),
                              child: SizedBox.square(dimension: 44, child: CustomPaint(painter: DeskPainter(c))),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _Label('Drills'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final shape in GemShape.values)
                        Expanded(
                          child: _Option(
                            label: shape.label,
                            selected: settings.shape == shape,
                            onTap: () => settings.setShape(shape),
                            child: SizedBox.square(dimension: 44, child: CustomPaint(painter: _DrillPreview(shape))),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const _Section(icon: Icons.sports_esports_rounded, text: 'Play'),
            _Card(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.spa_rounded,
                    title: 'Relaxed mode',
                    caption: 'No timer, no score, and wrong taps are not counted. Just painting.',
                    first: true,
                    value: settings.relaxed,
                    onChanged: settings.setRelaxed,
                  ),
                  _Row(
                    icon: Icons.vibration_rounded,
                    title: 'Vibration',
                    caption: 'Gentle taps as you place beads',
                    value: settings.haptics,
                    onChanged: settings.setHaptics,
                  ),
                  _Row(
                    icon: Icons.music_note_rounded,
                    title: 'Music & sounds',
                    caption: 'Themes, volume and sound effects',
                    onTap: () => showMusicSheet(context),
                  ),
                  _Row(
                    icon: Icons.school_rounded,
                    title: 'How to play',
                    caption: 'Play the Paint or Sort tutorial again',
                    onTap: () => _showHowToPlay(context),
                  ),
                ],
              ),
            ),
            const _Section(icon: Icons.person_rounded, text: 'You'),
            _Card(
              child: _Row(
                icon: Icons.badge_rounded,
                title: 'Your name',
                caption: '${settings.playerName}. It shows on your nameplate.',
                first: true,
                trailing: Icon(Icons.edit_rounded, color: t.muted),
                onTap: () => editPlayerName(context, settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets her play the Paint or Sort tutorial again.
void _showHowToPlay(BuildContext context) {
  final store = ProgressScope.of(context);
  void open(Widget Function() screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen()));
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brush_rounded),
            title: const Text('Paint tutorial'),
            subtitle: const Text('Fill numbered spots with matching drills'),
            onTap: () {
              Navigator.pop(sheet);
              open(() => GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true));
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Sort tutorial'),
            subtitle: const Text('Unscramble a picture using the tray'),
            onTap: () {
              Navigator.pop(sheet);
              open(() => SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// A sticker section title with a Material icon.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 12),
        child: StickerTitle(icon: icon, text: text),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.paw.muted));
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PawRadius.tile),
        border: Border.all(color: t.outline),
        boxShadow: t.shadow,
      ),
      child: child,
    );
  }
}

/// One settings row: a soft icon tile, a title with a caption, and a switch or chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.caption,
    this.first = false,
    this.value,
    this.onChanged,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool first;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final toggle = value != null;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: t.outline))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(PawRadius.chip)),
            child: Icon(icon, size: 20, color: t.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
                Text(caption, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (toggle)
            ExcludeSemantics(child: Switch(value: value!, onChanged: onChanged))
          else
            trailing ?? Icon(Icons.chevron_right_rounded, color: t.muted),
        ],
      ),
    );
    return Semantics(
      button: !toggle,
      toggled: toggle ? value : null,
      label: '$title. $caption',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: toggle ? () => onChanged?.call(!value!) : onTap, child: row),
      ),
    );
  }
}

/// A picture option (canvas or drill shape); the selected one is soft with an accent ring.
class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap, required this.child});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? t.soft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? t.accent : Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    child,
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? t.onSoft : t.ink,
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

/// One drill in the given shape.
class _DrillPreview extends CustomPainter {
  _DrillPreview(this.shape) : _paint = GemPaints(previewGem, shape: shape);

  final GemShape shape;
  final GemPaints _paint;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 30.0;
    drawGem(canvas, Rect.fromLTWH((size.width - s) / 2, (size.height - s) / 2, s, s), _paint);
  }

  @override
  bool shouldRepaint(_DrillPreview old) => old.shape != shape;
}
