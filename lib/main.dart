import 'package:flutter/material.dart';

import 'data/courses.dart';
import 'state/achievements.dart';
import 'state/music.dart';
import 'state/progress_store.dart';
import 'state/settings.dart';
import 'ui/frame_picker.dart';
import 'ui/home_screen.dart';
import 'ui/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load everything at once rather than one after another.
  final (store, music, settings) = await (ProgressStore.load(), MusicController.load(), AppSettings.load()).wait;
  registerFrameBadge();
  await baselineBadges(allCourses, store);
  runApp(PawlyPaintApp(store: store, music: music, settings: settings));
  music.playMenu();
}

class PawlyPaintApp extends StatelessWidget {
  PawlyPaintApp({super.key, required this.store, required this.music, required this.settings});

  final ProgressStore store;
  final MusicController music;
  final AppSettings settings;
  final courses = allCourses;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => MaterialApp(
              title: 'PawlyPaint',
              debugShowCheckedModeBanner: false,
              theme: pawTheme(PawTokens.latte, Brightness.light),
              darkTheme: pawTheme(PawTokens.espresso, Brightness.dark),
              themeMode: settings.themeMode,
              navigatorObservers: [homeRouteObserver],
              home: HomeScreen(courses: courses),
            ),
          ),
        ),
      ),
    );
  }
}
