import 'package:flutter/material.dart';

import '../state/settings.dart';
import 'desk.dart';
import 'gem_style.dart';
import 'music_sheet.dart';

/// Relaxed mode, vibration and how the canvas looks.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.spa_rounded),
            title: const Text('Relaxed mode'),
            subtitle: const Text('No timer, no score, and wrong taps are not counted. Just painting.'),
            value: settings.relaxed,
            onChanged: settings.setRelaxed,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Vibration'),
            subtitle: const Text('Gentle taps as you place beads'),
            value: settings.haptics,
            onChanged: settings.setHaptics,
          ),
          ListTile(
            leading: const Icon(Icons.music_note_rounded),
            title: const Text('Music & sounds'),
            subtitle: const Text('Themes, volume and sound effects'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showMusicSheet(context),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Canvas', style: text.titleMedium),
          ),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in CanvasTheme.values)
                  _Choice(
                    label: t.label,
                    selected: settings.theme == t,
                    onTap: () => settings.setTheme(t),
                    child: CustomPaint(painter: DeskPainter(t), child: Center(child: _SheetSwatch(theme: t))),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Drills', style: text.titleMedium),
          ),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final shape in GemShape.values)
                  _Choice(
                    label: shape.label,
                    selected: settings.shape == shape,
                    onTap: () => settings.setShape(shape),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: CustomPaint(painter: _DrillPreview(shape)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap, required this.child});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
                ),
                child: child,
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSwatch extends StatelessWidget {
  const _SheetSwatch({required this.theme});

  final CanvasTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
      );
}

/// Three drills in the given shape.
class _DrillPreview extends CustomPainter {
  _DrillPreview(this.shape);

  final GemShape shape;
  static final _paints = [
    GemPaints(const Color(0xFFE53950)),
    GemPaints(const Color(0xFF4AD6D0)),
    GemPaints(const Color(0xFFFFD54F))
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final saved = gemShape;
    gemShape = shape;
    const s = 26.0;
    final left = (size.width - s * 3) / 2, top = (size.height - s) / 2;
    for (var i = 0; i < 3; i++) {
      drawGem(canvas, Rect.fromLTWH(left + i * s, top, s, s), _paints[i]);
    }
    gemShape = saved;
  }

  @override
  bool shouldRepaint(_DrillPreview old) => old.shape != shape;
}
