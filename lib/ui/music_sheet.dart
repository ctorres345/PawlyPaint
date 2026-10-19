import 'package:flutter/material.dart';

import '../state/music.dart';

/// App bar button that opens the music settings.
class MusicButton extends StatelessWidget {
  const MusicButton({super.key});

  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    return IconButton(
      tooltip: music.muted ? 'Music off' : 'Music',
      icon: Icon(music.muted ? Icons.music_off_rounded : Icons.music_note_rounded),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => MusicScope(music: music, child: const _MusicSheet()),
      ),
    );
  }
}

class _MusicSheet extends StatelessWidget {
  const _MusicSheet();

  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    final text = Theme.of(context).textTheme;
    Widget option(MusicTheme? theme, IconData icon, String title, String subtitle) {
      final selected = music.choice == theme;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        selected: selected,
        enabled: !music.muted,
        onTap: () => music.setChoice(theme),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Music', style: text.titleLarge),
              ),
              SwitchListTile(
                title: const Text('Play music'),
                subtitle: const Text('Menu song and painting themes'),
                value: !music.muted,
                onChanged: (on) => music.setMuted(!on),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('While painting', style: text.titleSmall),
              ),
              option(null, Icons.shuffle_rounded, 'Random', 'A random theme for each picture'),
              for (final t in MusicTheme.values)
                option(
                  t,
                  switch (t) {
                    MusicTheme.chill => Icons.spa_rounded,
                    MusicTheme.fever => Icons.local_fire_department_rounded,
                    MusicTheme.hip => Icons.headphones_rounded,
                  },
                  t.label,
                  t.blurb,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
