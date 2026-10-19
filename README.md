# PawlyPaint

A cozy jewel (diamond) painting game for iOS and Android, built with Flutter.

Fill numbered canvases with sparkly drills. Pictures come in picross-style
courses (Beginner, Intermediate, Expert); each one stays a mystery until you
finish it, and your stars, best score and best time are kept on the device.

## Features

- **Realistic canvas**: a printed, color-tinted sheet with numbers and a stronger grid line every 10 cells.
- **Faceted drills** with a shimmer that sweeps across the finished area, small twinkles, and a pop when a drill lands.
- **Smart highlighting**: the selected color glows and everything else dims. The target button jumps to the nearest cell still missing that color.
- **Tray organization**: sort by number or by drills left; finished colors move to the end, and the next color is picked for you.
- **Controls**: tap or drag with one finger to place drills (a drag only fills matching cells), and pinch or drag with two fingers to zoom and pan.
- **Scoring**: 10 points a drill plus a combo bonus, a penalty for wrong taps, a time bonus under par, and 1 to 3 stars.
- **Progress**: half-finished pictures are saved and resumed. Each finished picture unlocks the next, and finishing 3 pictures in a course unlocks the next course.

The pictures are drawn from shapes in code (`lib/data/artworks.dart`), so
adding one is a short function: no image assets or photo upload needed.

## Running it

```bash
flutter create . --platforms=android,ios --project-name pawlypaint   # first time only, generates the platform folders
flutter pub get
flutter run
flutter test
```

## Layout

- `lib/data` builds the courses and draws the pictures.
- `lib/logic/scoring.dart` holds the scoring and star rules.
- `lib/state` has the game controller and saved progress (`shared_preferences`).
- `lib/ui` has the canvas painter, tray and screens.
