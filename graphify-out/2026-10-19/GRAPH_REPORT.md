# Graph Report - pawlypaint  (2026-10-19)

## Corpus Check
- 69 files · ~85,552 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 33 file(s) not represented in the graph (top: .xml 11, (none) 4, .plist 4)

## Summary
- 1768 nodes · 2247 edges · 67 communities (58 shown, 9 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cf625e51`
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
- time_attack.dart
- StatelessWidget
- idle_shimmer.dart
- completion_sheet.dart
- PawlyPaint
- manifest.json
- ../models/puzzle.dart
- line.dart
- mini_map.dart
- MainActivity.kt
- CLAUDE.md
- LaunchImage.imageset/README.md
- game_test.dart
- extreme_minecraft.dart
- simplify.dart
- courses.dart
- music_sheet.dart
- CustomPainter
- extreme_classics.dart
- extreme_garden.dart
- extreme_vocaloid.dart
- extreme_animals.dart
- extreme_sweets.dart
- State
- time_attack_screen.dart
- scoring.dart
- booster_bar.dart
- picture_export.dart
- dart:math
- replay.dart
- ProgressStore
- List
- package:flutter/material.dart
- MusicController
- ChangeNotifier

## God Nodes (most connected - your core abstractions)
1. `_` - 68 edges
2. `Puzzle` - 10 edges
3. `Track` - 10 edges
4. `at()` - 10 edges
5. `chill()` - 9 edges
6. `hip()` - 9 edges
7. `ProgressStore` - 8 edges
8. `menu()` - 8 edges
9. `fever()` - 8 edges
10. `bell()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `_` --references--> `Puzzle`  [EXTRACTED]
  lib/ui/gem_style.dart → lib/models/puzzle.dart

## Import Cycles
- None detected.

## Communities (67 total, 9 thin omitted)

### Community 0 - "sort_screen.dart"
Cohesion: 0.02
Nodes (103): _animate, bar, _boardKey, build, _cache, capacity, _celebrate, _cell (+95 more)

### Community 1 - "board.dart"
Cohesion: 0.03
Nodes (67): base, _beacon, _blast, BoardCache, build, _cache, celebrate, _cellRect (+59 more)

### Community 2 - "progress_store.dart"
Cohesion: 0.02
Nodes (83): addBoosters, _backupKey, bestCombo, bestLeft, bestScore, bestSeconds, bestStars, _bestStreak (+75 more)

### Community 3 - "compose_music.py"
Cohesion: 0.09
Nodes (38): bass(), chill(), e_piano(), env(), fever(), hat(), hip(), kick() (+30 more)

### Community 4 - "game_screen.dart"
Cohesion: 0.03
Nodes (57): _animate, _bombArmed, _boosterActive, _boosterFill, build, _celebrate, _checkMilestone, clock (+49 more)

### Community 5 - "music.dart"
Cohesion: 0.04
Nodes (50): _appActive, asset, blurb, choice, _choiceKey, current, didChangeAppLifecycleState, dispose (+42 more)

### Community 6 - "tray.dart"
Cohesion: 0.05
Nodes (35): GemPaints, axis, build, _burst, _chipExtent, color, createState, _currentOrder (+27 more)

### Community 7 - "settings.dart"
Cohesion: 0.06
Nodes (27): currentLook, desk, haptics, _hapticsKey, heavy, label, light, load (+19 more)

### Community 8 - "artworks.dart"
Cohesion: 0.04
Nodes (45): arcs, Artwork, berry, bg, birds, bite, black, butterfly (+37 more)

### Community 9 - "sort_controller.dart"
Cohesion: 0.03
Nodes (64): animating, _apply, arriving, _baseSeconds, bestCombo, boardVersion, bonusSeconds, canUndo (+56 more)

### Community 10 - "vocaloid.dart"
Cohesion: 0.06
Nodes (30): bg, _body, bowShade, c, collar, concert, dark, glowPink (+22 more)

### Community 11 - "_"
Cohesion: 0.04
Nodes (54): _, base, body, c, center, color, complete, crown (+46 more)

### Community 12 - "animals.dart"
Cohesion: 0.05
Nodes (36): b, bee, bg, body, bunny, c, chick, eyeWhite (+28 more)

### Community 13 - "minecraft.dart"
Cohesion: 0.06
Nodes (35): bg, block, c, cave, creeper, diamond, enderman, flower (+27 more)

### Community 14 - "settings_screen.dart"
Cohesion: 0.11
Nodes (14): GemShape, build, child, _Choice, label, onTap, paint, _paints (+6 more)

### Community 15 - "garden.dart"
Cohesion: 0.06
Nodes (32): acorn, appleTree, bg, birdhouse, blossom, body, c, cactus (+24 more)

### Community 16 - "sweets.dart"
Cohesion: 0.06
Nodes (32): berry, bg, bobaTea, body, c, cakeSlice, candle, candy (+24 more)

### Community 17 - "game_controller.dart"
Cohesion: 0.05
Nodes (40): _baseSeconds, boardVersion, brushActive, _brushCells, brushColor, combo, excusedMistakes, fill (+32 more)

### Community 18 - "art_canvas.dart"
Cohesion: 0.06
Nodes (29): ArtCanvas, at, bands, circle, col, _dist, dot, ellipse (+21 more)

### Community 19 - "sort_game.dart"
Cohesion: 0.04
Nodes (42): action, BeadHop, bestStep, board, capacity, cells, color, current (+34 more)

### Community 20 - "main.dart"
Cohesion: 0.12
Nodes (12): base, build, copyWith, courses, main, medium, music, PawlyPaintApp (+4 more)

### Community 21 - "coach.dart"
Cohesion: 0.12
Nodes (14): build, CoachCard, CoachStep, icon, manual, nav, onNext, onSkip (+6 more)

### Community 22 - "puzzle.dart"
Cohesion: 0.08
Nodes (22): accent, blurb, cellCount, cells, cellsByColor, colorCount, _countColors, counts (+14 more)

### Community 23 - "achievements.dart"
Cohesion: 0.06
Nodes (28): best, largestPatch, open, Achievement, achievements, bestCombo, bestStreak, bothModes (+20 more)

### Community 24 - "course_screen.dart"
Cohesion: 0.09
Nodes (20): Course, PlayMode, PuzzleRecord, SavedGame, build, completed, course, createState (+12 more)

### Community 25 - "home_screen.dart"
Cohesion: 0.09
Nodes (17): Level, build, build, course, courses, done, icon, label (+9 more)

### Community 26 - "gallery_screen.dart"
Cohesion: 0.10
Nodes (15): _cache, course, courses, createState, didChangeDependencies, dispose, _GemsCache, key (+7 more)

### Community 27 - "AppDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 28 - "time_attack.dart"
Cohesion: 0.20
Nodes (7): daily, helpCost, score, secondsFor, settingsFor, TimeAttack, timeLimit

### Community 29 - "StatelessWidget"
Cohesion: 0.12
Nodes (16): _LevelHeader, _PuzzleTile, GalleryScreen, _StatsBar, _Tips, _CourseCard, _DailyCard, HomeScreen (+8 more)

### Community 30 - "idle_shimmer.dart"
Cohesion: 0.15
Nodes (7): _allowed, controller, dispose, _idle, idleAfter, IdleShimmer, poke

### Community 31 - "completion_sheet.dart"
Cohesion: 0.11
Nodes (10): badges, boosters, build, done, label, relaxed, showCompletionSheet, _Stat (+2 more)

### Community 32 - "PawlyPaint"
Cohesion: 0.17
Nodes (11): Build and install (and update), Development, Every 7 days (free Apple ID), First launch, Installing on an Android phone, Installing on an iPhone, Layout, One-time setup (+3 more)

### Community 33 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 34 - "../models/puzzle.dart"
Cohesion: 0.29
Nodes (4): c, red, toPuzzle, tutorialPuzzle

### Community 35 - "line.dart"
Cohesion: 0.25
Nodes (7): dx, err, sx, x0, x1, y0, y1

### Community 36 - "mini_map.dart"
Cohesion: 0.08
Nodes (19): board, build, _cache, createState, dispose, _frame, height, _jump (+11 more)

### Community 42 - "extreme_minecraft.dart"
Cohesion: 0.06
Nodes (31): c, ceil, cliff, cliffAt, d, dragon, dx, floor (+23 more)

### Community 46 - "simplify.dart"
Cohesion: 0.03
Nodes (75): a1, a2, alive, ap1, b1, b2, best, bg (+67 more)

### Community 47 - "courses.dart"
Cohesion: 0.08
Nodes (10): allCourses, buildCourses, _course, _forDifficulty, _minColorGap, _minDistance, separateColors, simple (+2 more)

### Community 48 - "music_sheet.dart"
Cohesion: 0.14
Nodes (11): build, enabled, icon, label, music, MusicButton, _MusicSheet, onChanged (+3 more)

### Community 49 - "CustomPainter"
Cohesion: 0.15
Nodes (12): BoardPainter, DeskPainter, _FinishedPainter, PuzzleThumbPainter, _MiniMapPainter, _ReplayPainter, _DrillPreview, _FlightPainter (+4 more)

### Community 50 - "extreme_classics.dart"
Cohesion: 0.07
Nodes (28): ball, balloons, baseDark, bk, blanket, body, c, cone (+20 more)

### Community 51 - "extreme_garden.dart"
Cohesion: 0.08
Nodes (24): bird, butterfly, c, capShape, doorShape, hillDark, house, pathShape (+16 more)

### Community 52 - "extreme_vocaloid.dart"
Cohesion: 0.08
Nodes (23): bg, blush, c, coatShade, crescent, eye, hair, s (+15 more)

### Community 53 - "extreme_animals.dart"
Cohesion: 0.09
Nodes (22): body, bowl, c, face, fur, glow, head, maneDark (+14 more)

### Community 54 - "extreme_sweets.dart"
Cohesion: 0.10
Nodes (20): body, bread, c, custard, frost, inWin, mini, mug (+12 more)

### Community 55 - "State"
Cohesion: 0.13
Nodes (18): Board, _BoardState, CourseScreen, _CourseScreenState, PictureViewer, _PictureViewerState, GameScreen, _GameScreenState (+10 more)

### Community 56 - "time_attack_screen.dart"
Cohesion: 0.10
Nodes (15): Difficulty, TimeAttackRecord, build, _colors, courses, _DailyChallengeCard, difficulty, _DifficultyCard (+7 more)

### Community 57 - "scoring.dart"
Cohesion: 0.07
Nodes (24): bombRadius, Booster, boosterReward, cellsInBlast, help, label, r, starter (+16 more)

### Community 58 - "booster_bar.dart"
Cohesion: 0.14
Nodes (9): active, axis, booster, BoosterBar, _BoosterButton, boosterIcon, build, count (+1 more)

### Community 59 - "picture_export.dart"
Cohesion: 0.10
Nodes (19): Puzzle, build, _busy, c, cell, createState, margin, paints (+11 more)

### Community 60 - "dart:math"
Cohesion: 0.33
Nodes (4): CanvasTheme, paint, shouldRepaint, theme

### Community 61 - "replay.dart"
Cohesion: 0.10
Nodes (18): build, _c, _cache, cell, _ChunkCache, createState, didChangeDependencies, dispose (+10 more)

### Community 63 - "List"
Cohesion: 0.25
Nodes (5): BadgeGrid, badgeIcon, build, courses, store

### Community 64 - "package:flutter/material.dart"
Cohesion: 0.22
Nodes (8): build, _c, combo, ComboPop, _ComboPopState, createState, dispose, initState

### Community 65 - "MusicController"
Cohesion: 0.40
Nodes (4): MusicController, MusicScope, AppSettings, SettingsScope

### Community 66 - "ChangeNotifier"
Cohesion: 0.50
Nodes (3): GameController, SortController, BoardView

## Knowledge Gaps
- **1386 isolated node(s):** `XCTest`, `sea`, `c`, `bg`, `sky` (+1381 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1477 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `package:flutter/material.dart`, `../models/puzzle.dart`, `tray.dart`, `game_test.dart`, `settings_screen.dart`, `CustomPainter`, `puzzle.dart`, `scoring.dart`, `picture_export.dart`, `dart:math`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **What connects `XCTest`, `sea`, `c` to the rest of the system?**
  _1386 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `sort_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.018518518518518517 - nodes in this community are weakly interconnected._
- **Why does `Puzzle` connect `picture_export.dart` to `sort_screen.dart`, `game_screen.dart`, `sort_controller.dart`, `_`, `game_controller.dart`, `puzzle.dart`, `course_screen.dart`, `gallery_screen.dart`, `replay.dart`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Should `board.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._
- **Why does `IdleShimmer` connect `idle_shimmer.dart` to `sort_screen.dart`, `gallery_screen.dart`, `game_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Should `progress_store.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023529411764705882 - nodes in this community are weakly interconnected._