part of '../sort_screen.dart';

/// The Sort screen's state: the game, its timers and what each tap does.
/// The end-of-round flow and the layout are mixed in from [_SortFlow] and
/// [_SortLayout].
abstract class _SortStateBase extends State<SortScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  AppSettings get _settings => SettingsScope.read(context);

  late final SortController game;
  late final List<GemPaints> paints;
  final view = BoardView();
  late final IdleShimmer _shimmer;
  bool _animate = true;
  Animation<double> get shimmer => _shimmer.animation;
  late final Ticker _ticker;
  int _lastFrameUs = 0;
  final clock = ValueNotifier<int>(0);

  /// Ticks every frame while something animates (flights, hint, pulses).
  final frame = ValueNotifier<int>(0);
  Timer? _clockTick;
  final _boardKey = GlobalKey();
  final _trayKey = GlobalKey();
  final _stackKey = GlobalKey();
  late bool showWrong = widget.tutorial;

  /// True while the player holds the preview, showing the finished picture.
  bool peeking = false;
  bool _finished = false;
  int _savedVersion = 0;

  /// The zoom-out after finishing; kept so leaving mid-way can stop it.
  AnimationController? _glide;
  bool _celebrate = false;
  DateTime? _sweepAt;
  int _unsaved = 0;
  MusicController? _music;
  late bool _showTips = !widget.store.seenSortTutorial && !widget.tutorial;

  /// Drains while the combo is alive; restarted on every good drop.
  late final AnimationController _comboBar;
  bool get _timed => widget.timeAttack != null;

  static const _coachSteps = [
    CoachStep(Icons.touch_app_rounded,
        'Beads with a dot are in the wrong spot. Tap one to pick it up, along with any misplaced beads of its color touching it.'),
    CoachStep(Icons.inventory_2_outlined, 'Now tap the tray to put them there. That leaves empty spots behind.'),
    CoachStep(Icons.auto_awesome_rounded,
        'Empty spots show the color they need. Pick up that color (from the tray or the canvas), then tap a glowing spot.'),
    CoachStep(Icons.bolt_rounded,
        'Good drops in a row build a combo for bonus points. Hold the little picture in the corner to peek.'),
    CoachStep(Icons.vibration_rounded,
        'The eye button turns the dots on or off, and the hint shows a good move. Finish the heart!'),
  ];
  int _coach = 0;

  void _endTutorial() {
    widget.store.markSortTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _coachEvent(SortTapResult result) {
    if (!widget.tutorial) return;
    final next = switch ((_coach, result)) {
      (0, SortTapResult.selected) => 1,
      (0 || 1, SortTapResult.moved) => 2,
      (< 3, SortTapResult.sorted) => 3,
      _ => _coach,
    };
    if (next != _coach) setState(() => _coach = next);
  }

  @override
  void initState() {
    super.initState();
    game = _timed
        ? SortController.timed(widget.puzzle, seed: widget.seed)
        : SortController(widget.puzzle, resume: widget.tutorial ? null : widget.store.sortSaved(widget.puzzle.id));
    _comboBar = AnimationController(vsync: this, duration: Scoring.comboWindow);
    paints = GemPaints.forPuzzle(widget.puzzle);
    _shimmer = IdleShimmer(this)..poke();
    _ticker = createTicker((_) {
      game.tick();
      final hintAt = game.hintAt, missAt = game.mistakeAt;
      final now = DateTime.now();
      if (game.animating ||
          // Picked-up beads and the spots that want them gently pulse.
          (game.selection != null && !_finished) ||
          (hintAt != null && now.difference(hintAt).inMilliseconds < 4000) ||
          (missAt != null && now.difference(missAt).inMilliseconds < 700)) {
        // Flying beads get every frame; the gentle pulses are fine at about
        // 30 a second, which matters on 120 Hz screens.
        final us = now.microsecondsSinceEpoch;
        if (game.animating || us - _lastFrameUs >= 30000) {
          _lastFrameUs = us;
          frame.value++;
        }
      } else {
        // Nothing moving: stop ticking until the next tap, shake or hint.
        frame.value++;
        _ticker.stop();
      }
    });
    clock.value = game.seconds;
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = game.seconds;
      if (game.timeUp && !_finished) _timeUp();
    });
    // The clock starts with the run, not with the first tap.
    if (_timed) game.resume();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.relaxed = SettingsScope.of(context).relaxed;
    if (_music == null) {
      _music = MusicScope.read(context);
      _music!.enterGame();
    }
    // Respect the system "remove animations" setting: the drills stay still.
    final animate = !MediaQuery.of(context).disableAnimations;
    if (animate != _animate) {
      _animate = animate;
      _shimmer.allowed = animate;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      game.pause();
      _save();
    } else if (state == AppLifecycleState.resumed && _timed && !_finished) {
      game.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pause();
    if (!_finished &&
        !widget.tutorial &&
        !_timed &&
        game.game.placed + game.game.shakes > 0 &&
        game.saveVersion != _savedVersion) {
      final state = game.toJson();
      final store = widget.store, id = widget.puzzle.id;
      Future.microtask(() => store.saveSort(id, state));
    }
    if (!widget.tutorial && !_timed && game.bestCombo > widget.store.bestCombo) {
      final store = widget.store, combo = game.bestCombo;
      Future.microtask(() => store.noteCombo(combo));
    }
    final music = _music;
    if (music != null) Future.microtask(music.leaveGame);
    _music = null;
    _glide?.dispose();
    _comboBar.dispose();
    _clockTick?.cancel();
    _ticker.dispose();
    clock.dispose();
    frame.dispose();
    _shimmer.dispose();
    game.dispose();
    view.dispose();
    super.dispose();
  }

  void _save() {
    // Only write when the board changed since the last save.
    if (_finished || widget.tutorial || _timed || game.saveVersion == _savedVersion) return;
    _savedVersion = game.saveVersion;
    _unsaved = 0;
    widget.store.saveSort(widget.puzzle.id, game.toJson());
  }

  /// Runs the per-frame ticker while beads fly or a hint pulses.
  void _wakeTicker() {
    if (!_ticker.isActive) _ticker.start();
  }

  /// On-screen bead size a canvas opens at, and that a hint zooms to.
  static const _comfyCell = 22.0;

  /// Below this bead size a tap zooms in instead of picking a bead.
  static const _minTapCell = 14.0;

  /// How far from the touch a bead still counts as under the fingertip.
  static const _fingerRadius = 18.0;

  void _tap(Offset local) {
    _wakeTicker();
    if (view.cellAt(local) == null) return;
    if (view.cellSize < _minTapCell) {
      view.zoomAt(local, _comfyCell / view.cellSize);
      return;
    }
    // A fingertip covers more than one bead, so aim among those under it.
    final w = widget.puzzle.width;
    _react(game.tapNear([for (final (x, y) in view.cellsNear(local, _fingerRadius)) y * w + x]));
  }

  void _tapTray(Offset local, Size size) {
    _wakeTicker();
    _react(game.tapTray(SortTrayPainter.slotAt(size, game.game.capacity, local)));
  }

  void _react(SortTapResult result) {
    _coachEvent(result);
    switch (result) {
      case SortTapResult.selected:
        _settings.selection();
        _music?.play(Sfx.place);
      case SortTapResult.deselected:
        _settings.selection();
      case SortTapResult.moved:
        _settings.light();
        _music?.play(Sfx.place);
        if (++_unsaved >= 10) _save();
      case SortTapResult.sorted:
        // The chime and the thump brighten as the combo grows.
        final level = Scoring.sortStreakLevel(game.combo);
        _settings.light();
        _music?.play(Sfx.place);
        // The chime lands with the beads flying into place.
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          if (level == 1) _settings.medium();
          if (level == 2) _settings.heavy();
          _music?.play(Sfx.landAt(level));
        });
        if (game.combo >= 2) _comboBar.forward(from: 0);
        if (++_unsaved >= 10) _save();
      case SortTapResult.wrong:
        _settings.medium();
        _music?.play(Sfx.wrong);
        _comboBar.value = 1;
      case SortTapResult.noBeads:
        _settings.light();
        _toast('No beads of that color in the tray yet. Pick up a misplaced one first.');
      case SortTapResult.trayFull:
        _settings.heavy();
        _music?.play(Sfx.wrong);
        _toast('The tray is full. Drop beads into empty spots, or shake the tray.');
      case SortTapResult.complete:
        _settings.heavy();
        Future.delayed(const Duration(milliseconds: 650), () => _music?.play(Sfx.complete));
        _finish();
      case SortTapResult.ignored:
        break;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ));
  }

  void _hint() {
    _wakeTicker();
    final step = game.hint();
    if (step == null) return;
    if (_timed) _toast('Hint: −${TimeAttack.helpCost} seconds');
    // On big canvases, zoom in a little so the hinted spot is easy to tap.
    final cell = step.fromCell ?? step.toCell;
    if (cell != null && view.cellSize < _comfyCell) {
      final w = widget.puzzle.width;
      final center = view.offset + Offset((cell % w + 0.5) * view.cellSize, (cell ~/ w + 0.5) * view.cellSize);
      view.zoomAt(center, _comfyCell / view.cellSize);
    }
  }

  /// Centre of a board cell, in the coordinates of the screen's stack.
  Offset? _cellCenter(int cell) {
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || stack == null) return null;
    final w = widget.puzzle.width;
    final local = view.offset + Offset((cell % w + 0.5) * view.cellSize, (cell ~/ w + 0.5) * view.cellSize);
    return stack.globalToLocal(board.localToGlobal(local));
  }

  Rect? _slotRect(int slot) {
    final tray = _trayKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (tray == null || stack == null) return null;
    final r = SortTrayPainter.slotRect(tray.size, game.game.capacity, slot);
    return Rect.fromCenter(
      center: stack.globalToLocal(tray.localToGlobal(r.center)),
      width: r.width,
      height: r.height,
    );
  }

  Future<void> _finish();

  Future<void> _timeUp();

  Future<void> _confirmRestart();
}
