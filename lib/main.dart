import 'package:flutter/material.dart';

import 'data/courses.dart';
import 'state/progress_store.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProgressStore.load();
  runApp(PawlyPaintApp(store: store));
}

class PawlyPaintApp extends StatelessWidget {
  PawlyPaintApp({super.key, required this.store});

  final ProgressStore store;
  final courses = buildCourses();

  @override
  Widget build(BuildContext context) {
    return ProgressScope(
      store: store,
      child: MaterialApp(
        title: 'PawlyPaint',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: HomeScreen(courses: courses),
      ),
    );
  }
}

/// Quicksand is a light, rounded face, so body and label text get a little
/// extra weight to stay easy to read.
ThemeData _theme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Quicksand',
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE5739F)),
    scaffoldBackgroundColor: const Color(0xFFFFF7FA),
  );
  TextStyle? medium(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w600);
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      bodyLarge: medium(t.bodyLarge),
      bodyMedium: medium(t.bodyMedium),
      bodySmall: medium(t.bodySmall),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
