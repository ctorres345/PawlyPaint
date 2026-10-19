# Graph Report - pawlypaint  (2026-10-19)

## Corpus Check
- 53 files · ~53,992 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 33 file(s) not represented in the graph (top: .xml 11, (none) 4, .plist 4)

## Summary
- 1199 nodes · 1543 edges · 46 communities (36 shown, 10 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 32 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `31190c78`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- sort_screen.dart
- board.dart
- progress_store.dart
- compose_music.py
- game_screen.dart
- music.dart
- tray.dart
- settings.dart
- artworks.dart
- sort_controller.dart
- vocaloid.dart
- _
- animals.dart
- minecraft.dart
- settings_screen.dart
- garden.dart
- sweets.dart
- game_controller.dart
- art_canvas.dart
- sort_game.dart
- main.dart
- coach.dart
- puzzle.dart
- achievements.dart
- course_screen.dart
- home_screen.dart
- gallery_screen.dart
- AppDelegate
- game_test.dart
- StatelessWidget
- idle_shimmer.dart
- completion_sheet.dart
- Installing on an iPhone
- manifest.json
- package:flutter/material.dart
- line.dart
- ChangeNotifier
- MainActivity.kt
- CLAUDE.md
- LaunchImage.imageset/README.md
- MusicController
- ProgressStore

## God Nodes (most connected - your core abstractions)
1. `_` - 48 edges
2. `Track` - 10 edges
3. `chill()` - 9 edges
4. `hip()` - 9 edges
5. `Puzzle` - 8 edges
6. `ProgressStore` - 8 edges
7. `menu()` - 8 edges
8. `fever()` - 8 edges
9. `MusicController` - 7 edges
10. `env()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `_` --references--> `Puzzle`  [EXTRACTED]
  lib/ui/gem_style.dart → lib/models/puzzle.dart

## Import Cycles
- None detected.

## Communities (46 total, 10 thin omitted)

### Community 0 - "sort_screen.dart"
Cohesion: 0.02
Nodes (80): _animate, _boardKey, build, _cache, capacity, _celebrate, _cell, _cellCenter (+72 more)

### Community 1 - "board.dart"
Cohesion: 0.03
Nodes (52): base, BoardCache, build, _cache, celebrate, cellSize, centerCell, _clamp (+44 more)

### Community 2 - "progress_store.dart"
Cohesion: 0.03
Nodes (56): _backupKey, bestScore, bestSeconds, bestStars, _bestStreak, combo, completedIn, _dailyDate (+48 more)

### Community 3 - "compose_music.py"
Cohesion: 0.09
Nodes (35): bass(), chill(), e_piano(), env(), fever(), hat(), hip(), kick() (+27 more)

### Community 4 - "game_screen.dart"
Cohesion: 0.04
Nodes (45): _animate, build, _celebrate, clock, _clockTick, _coach, _coachSteps, combo (+37 more)

### Community 5 - "music.dart"
Cohesion: 0.04
Nodes (48): _appActive, asset, blurb, choice, _choiceKey, current, didChangeAppLifecycleState, dispose (+40 more)

### Community 6 - "tray.dart"
Cohesion: 0.05
Nodes (38): Board, _BoardState, CourseScreen, _CourseScreenState, PictureViewer, _PictureViewerState, GameScreen, _GameScreenState (+30 more)

### Community 7 - "settings.dart"
Cohesion: 0.04
Nodes (39): afterMistake, drillPoints, maxComboBonus, mistakePenalty, pointsForDrill, Scoring, sortScore, sortStars (+31 more)

### Community 8 - "artworks.dart"
Cohesion: 0.04
Nodes (45): arcs, Artwork, berry, bg, birds, bite, black, butterfly (+37 more)

### Community 9 - "sort_controller.dart"
Cohesion: 0.05
Nodes (38): animating, arriving, _baseSeconds, boardVersion, cell, color, correctCount, duration (+30 more)

### Community 10 - "vocaloid.dart"
Cohesion: 0.05
Nodes (34): bg, _body, bowShade, c, collar, concert, dark, glowPink (+26 more)

### Community 11 - "_"
Cohesion: 0.05
Nodes (36): _, base, body, c, color, complete, crown, dark (+28 more)

### Community 12 - "animals.dart"
Cohesion: 0.05
Nodes (36): b, bee, bg, body, bunny, c, chick, eyeWhite (+28 more)

### Community 13 - "minecraft.dart"
Cohesion: 0.06
Nodes (35): bg, block, c, cave, creeper, diamond, enderman, flower (+27 more)

### Community 14 - "settings_screen.dart"
Cohesion: 0.06
Nodes (26): CanvasTheme, BoardPainter, DeskPainter, paint, shouldRepaint, theme, _FinishedPainter, GemShape (+18 more)

### Community 15 - "garden.dart"
Cohesion: 0.06
Nodes (32): acorn, appleTree, bg, birdhouse, blossom, body, c, cactus (+24 more)

### Community 16 - "sweets.dart"
Cohesion: 0.06
Nodes (32): berry, bg, bobaTea, body, c, cakeSlice, candle, candy (+24 more)

### Community 17 - "game_controller.dart"
Cohesion: 0.06
Nodes (26): _baseSeconds, boardVersion, combo, firstIncompleteColor, isColorDone, isComplete, lastMistakeAt, lastMistakeCell (+18 more)

### Community 18 - "art_canvas.dart"
Cohesion: 0.06
Nodes (29): ArtCanvas, at, bands, circle, col, _dist, dot, ellipse (+21 more)

### Community 19 - "sort_game.dart"
Cohesion: 0.07
Nodes (27): bestMove, capacity, current, decodeBoard, decodeTray, encodeBoard, encodeTray, Fill (+19 more)

### Community 20 - "main.dart"
Cohesion: 0.07
Nodes (23): base, build, copyWith, courses, main, medium, music, PawlyPaintApp (+15 more)

### Community 21 - "coach.dart"
Cohesion: 0.07
Nodes (19): allCourses, buildCourses, _course, _sizes, unlockAfter, build, CoachCard, CoachStep (+11 more)

### Community 22 - "puzzle.dart"
Cohesion: 0.07
Nodes (23): accent, blurb, cellCount, cells, cellsByColor, colorCount, _countColors, counts (+15 more)

### Community 23 - "achievements.dart"
Cohesion: 0.08
Nodes (22): Achievement, achievements, bestStreak, bothModes, cleanSorts, coursesDone, description, earned (+14 more)

### Community 24 - "course_screen.dart"
Cohesion: 0.09
Nodes (19): PlayMode, PuzzleRecord, SavedGame, build, completed, course, createState, index (+11 more)

### Community 25 - "home_screen.dart"
Cohesion: 0.10
Nodes (13): Course, Level, build, build, completed, course, courses, level (+5 more)

### Community 26 - "gallery_screen.dart"
Cohesion: 0.10
Nodes (16): Puzzle, _cache, course, courses, createState, didChangeDependencies, dispose, _GemsCache (+8 more)

### Community 27 - "AppDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 29 - "StatelessWidget"
Cohesion: 0.12
Nodes (15): _LevelHeader, _PuzzleTile, GalleryScreen, _StatsBar, _Tips, _CourseCard, _DailyCard, HomeScreen (+7 more)

### Community 30 - "idle_shimmer.dart"
Cohesion: 0.15
Nodes (7): _allowed, controller, dispose, _idle, idleAfter, IdleShimmer, poke

### Community 31 - "completion_sheet.dart"
Cohesion: 0.18
Nodes (7): badges, build, label, relaxed, showCompletionSheet, _Stat, value

### Community 32 - "Installing on an iPhone"
Cohesion: 0.18
Nodes (10): Build and install (and update), Development, Every 7 days (free Apple ID), First launch, Installing on an Android phone, Installing on an iPhone, Layout, One-time setup (+2 more)

### Community 33 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 34 - "package:flutter/material.dart"
Cohesion: 0.22
Nodes (5): BadgeGrid, badgeIcon, build, courses, store

### Community 35 - "line.dart"
Cohesion: 0.25
Nodes (7): dx, err, sx, x0, x1, y0, y1

### Community 36 - "ChangeNotifier"
Cohesion: 0.50
Nodes (3): GameController, SortController, BoardView

## Knowledge Gaps
- **887 isolated node(s):** `XCTest`, `sea`, `c`, `bg`, `sky` (+882 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 961 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `package:flutter/material.dart`, `tray.dart`, `settings.dart`, `vocaloid.dart`, `settings_screen.dart`, `puzzle.dart`, `gallery_screen.dart`, `game_test.dart`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **What connects `XCTest`, `sea`, `c` to the rest of the system?**
  _887 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `sort_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Why does `Puzzle` connect `gallery_screen.dart` to `sort_screen.dart`, `game_screen.dart`, `sort_controller.dart`, `_`, `game_controller.dart`, `puzzle.dart`, `course_screen.dart`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Should `board.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03389830508474576 - nodes in this community are weakly interconnected._
- **Why does `ProgressStore` connect `ProgressStore` to `sort_screen.dart`, `progress_store.dart`, `package:flutter/material.dart`, `game_screen.dart`, `ChangeNotifier`, `main.dart`, `home_screen.dart`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Should `progress_store.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.034482758620689655 - nodes in this community are weakly interconnected._