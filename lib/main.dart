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
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE5739F)),
          scaffoldBackgroundColor: const Color(0xFFFFF7FA),
        ),
        home: HomeScreen(courses: courses),
      ),
    );
  }
}
