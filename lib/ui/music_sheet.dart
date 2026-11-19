import 'package:flutter/material.dart';

import '../state/music.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';

/// Opens the music and sound settings.
void showMusicSheet(BuildContext context) {
  final music = MusicScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MusicScope(music: music, child: const _MusicSheet()),
  );
}

/// App bar button that opens the music settings.
class MusicButton extends StatelessWidget {
  const MusicButton({super.key, this.sticker = false});

  /// The menu look from the redesign; play screens keep the plain icon until PAP-22.
  final bool sticker;

  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    final tooltip = music.muted ? 'Music off' : 'Music and sounds';
    final icon = music.muted ? Icons.music_off_rounded : Icons.music_note_rounded;
    if (sticker) return SquareButton(tooltip: tooltip, icon: icon, onPressed: () => showMusicSheet(context));
    return IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: () => showMusicSheet(context));
  }
}

class _MusicSheet extends StatelessWidget {
  const _MusicSheet();

  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    final t = context.paw;
    final text = Theme.of(context).textTheme;
    Widget option(MusicTheme? theme, IconData icon, String title, String subtitle) {
      final selected = music.choice == theme;
      final fg = selected ? t.onSoft : t.ink;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          selected: selected,
          button: true,
          enabled: !music.muted,
          label: '$title, $subtitle',
          excludeSemantics: true,
          child: Material(
            color: selected ? t.soft : t.tint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: selected ? BorderSide(color: t.accent, width: 2) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: music.muted ? null : () => music.setChoice(theme),
              child: Opacity(
                opacity: music.muted ? .5 : 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: fg),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(subtitle, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (selected) Icon(Icons.check_rounded, size: 22, color: fg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Art('mochi/music.png', size: 52),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Music & sounds', style: text.titleLarge)),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // PAP-19 "Music" board: the theme first, then the volumes, then the switches.
              Semantics(
                header: true,
                child: Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.muted)),
              ),
              const SizedBox(height: 8),
              option(null, Icons.shuffle_rounded, 'Random', 'A random theme for each picture'),
              for (final m in MusicTheme.values)
                option(
                  m,
                  switch (m) {
                    MusicTheme.chill => Icons.spa_rounded,
                    MusicTheme.fever => Icons.local_fire_department_rounded,
                    MusicTheme.hip => Icons.headphones_rounded,
                  },
                  m.label,
                  m.blurb,
                ),
              const SizedBox(height: 4),
              _VolumeSlider(
                icon: Icons.music_note_rounded,
                label: 'Music',
                value: music.musicVolume,
                enabled: !music.muted,
                onChanged: music.setMusicVolume,
              ),
              _VolumeSlider(
                icon: Icons.volume_up_rounded,
                label: 'Effects',
                value: music.sfxVolume,
                enabled: music.sfxOn,
                onChanged: (v) {
                  music.setSfxVolume(v);
                  music.play(Sfx.place);
                },
              ),
              _SwitchRow(
                icon: Icons.queue_music_rounded,
                label: 'Play music',
                value: !music.muted,
                onChanged: (on) => music.setMuted(!on),
              ),
              _SwitchRow(
                  icon: Icons.graphic_eq_rounded, label: 'Sound effects', value: music.sfxOn, onChanged: music.setSfx),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return MergeSemantics(
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(icon, color: t.ink),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink))),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 22, color: enabled ? t.ink : t.muted),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              label: '${(value * 100).round()}%',
              divisions: 10,
              semanticFormatterCallback: (v) => '$label volume ${(v * 100).round()} percent',
            ),
          ),
        ],
      ),
    );
  }
}
