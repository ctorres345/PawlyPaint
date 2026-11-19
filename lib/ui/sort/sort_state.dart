part of '../sort_screen.dart';

/// The Sort screen's state: the game, its timers and what each tap does.
/// The end-of-round flow and the layout are mixed in from [_SortFlow] and
/// [_SortLayout].
abstract class _SortStateBase extends State<_SortPage>
    with TickerProviderStateMixin, WidgetsBindingObserver
    implements PlayTimers {
  AppSettings get _settings => SettingsScope.read(context);

  /// A star just dropped on the meter: one firmer buzz, a beat after the
  /// wrong-tap or shake buzz so the two don't merge.
  void _onStarLost() => Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _settings.heavy();
      });

  late final SortController game;
  late List<GemPaints> paints;
  final view = BoardView();

  /// Paces the shimmer and the gentle pulses at about 30 frames a second.
  late final EffectClock _effects;
  ValueListenable<double> get shimmer => _effects;

  @override
  EffectClock get effects => _effects;

  @override
  bool get clockTicking => _clockTick != null;

  @override
  bool get lapsePending => _lapse != null;
  late final Ticker _ticker;
  final clock = ValueNotifier<int>(0);

  /// Ticks every frame while beads fly between the board and the tray.
  final frame = ValueNotifier<int>(0);

  /// What the tray repaints on: flying beads and the paced pulses.
  late final Listenable _trayRepaint = Listenable.merge([frame, _pulse]);

  /// Ticks with the effect clock only while something pulses, so the tray
  /// and the combo bar skip the shimmer's frames.
  final _pulse = ValueNotifier(0);
  late final Listenable _comboTick = Listenable.merge([_pulse, _lapsed]);
  Timer? _clockTick;
  bool _covered = false;

  /// Fires when a hint, miss or combo window ends, so they clear even with
  /// no effects running.
  Timer? _lapse;
  final _lapsed = ValueNotifier(0);
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

  /// How much of the combo bar has drained, 0..1 (1: no live combo). It
  /// refills on every good drop and empties after [Scoring.comboWindow].
  double get _comboDrained {
    final at = game.comboAt;
    if (at == null || game.combo < 2) return 1;
    final ms = EffectClock.wallNow().difference(at).inMilliseconds;
    return (ms / Scoring.comboWindow.inMilliseconds).clamp(0.0, 1.0);
  }

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
    DisplayRate.hold();
    game = _timed
        ? SortController.timed(widget.puzzle, seed: widget.seed, clock: EffectClock.wallNow)
        : SortController(
            widget.puzzle,
            resume: widget.tutorial ? null : widget.store.sortSaved(widget.puzzle.id),
            clock: EffectClock.wallNow,
          );
    paints = GemPaints.forPuzzle(widget.puzzle, _settings.shape);
    _effects = EffectClock()
      ..keepAliveWhile = _pulsing
      ..addListener(() {
        if (_pulsing()) _pulse.value++;
      })
      ..poke();
    // Flying beads get every frame; everything else runs on [_effects].
    _ticker = createTicker((_) {
      game.tick();
      frame.value++;
      // The tap that woke the ticker may have started a pulse.
      _effects.wake();
      if (!game.animating) _ticker.stop();
    });
    clock.value = game.seconds;
    _startClockTick();
    // The clock starts with the run, not with the first tap.
    if (_timed) game.resume();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.relaxed = SettingsScope.of(context).relaxed;
    final shape = SettingsScope.of(context).shape;
    if (paints.first.shape != shape) paints = GemPaints.forPuzzle(widget.puzzle, shape);
    if (_music == null) {
      _music = MusicScope.read(context);
      _music!.enterGame();
    }
    // Still with "remove animations", resting while another screen covers this one.
    _effects.follow(context);
    // The clock text rests too while covered.
    final covered = !TickerMode.valuesOf(context).enabled;
    if (covered != _covered) {
      _covered = covered;
      if (covered) {
        _stopClockTick();
        _lapse?.cancel();
        _lapse = null;
      } else {
        _maybeStartClockTick();
        _armLapse();
      }
    }
  }

  /// Picked-up beads and the spots that want them gently pulse, as do a
  /// hint, a miss and a live combo bar.
  bool _pulsing() {
    if (_finished) return false;
    final now = EffectClock.wallNow();
    final hintAt = game.hintAt, missAt = game.mistakeAt;
    return game.selection != null ||
        (hintAt != null && now.difference(hintAt) < _hintShows) ||
        (missAt != null && now.difference(missAt) < _missShows) ||
        _comboDrained < 1;
  }

  /// Without effects ("remove animations") nothing else redraws a hint, a
  /// miss cross or the combo bar when its window ends, so a timer does.
  void _armLapse() {
    _lapse?.cancel();
    _lapse = null;
    final now = EffectClock.wallNow();
    DateTime? next;
    void until(DateTime? at, Duration window) {
      if (at == null) return;
      final end = at.add(window);
      if (end.isAfter(now) && (next == null || end.isBefore(next!))) next = end;
    }

    if (game.combo >= 2) until(game.comboAt, Scoring.comboWindow);
    until(game.hintAt, _hintShows);
    until(game.mistakeAt, _missShows);
    final at = next;
    if (at == null) return;
    _lapse = Timer(at.difference(now), () {
      frame.value++;
      _lapsed.value++;
      _armLapse();
    });
  }

  /// Starts the clock text's timer unless the round is over, the app is in
  /// the background or another screen covers this one.
  void _maybeStartClockTick() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_finished || _covered || (state != null && state != AppLifecycleState.resumed)) return;
    _startClockTick();
  }

  void _stopClockTick() {
    _clockTick?.cancel();
    _clockTick = null;
  }

  void _startClockTick() {
    _clockTick?.cancel();
    void tick() {
      clock.value = game.seconds;
      if (game.timeUp && !_finished) _timeUp();
    }

    // Back from the background or another screen, time may have run out.
    tick();
    if (!_finished) _clockTick = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_timed && !_finished) game.resume();
      _maybeStartClockTick();
      if (!_covered) _armLapse();
      return;
    }
    // Inactive, hidden or paused: nothing ticks in the background.
    _stopClockTick();
    _lapse?.cancel();
    _lapse = null;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      game.pause();
      _save();
    }
  }

  @override
  void dispose() {
    // First, so a throwing dispose below cannot leave the cap on (PAP-59).
    DisplayRate.release();
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
    _lapse?.cancel();
    _lapsed.dispose();
    _pulse.dispose();
    _clockTick?.cancel();
    _ticker.dispose();
    clock.dispose();
    frame.dispose();
    _effects.dispose();
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
        // A good drop to the tray feeds the combo too.
        _effects.wake();
        _armLapse();
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
        _effects.wake();
        _armLapse();
        if (++_unsaved >= 10) _save();
      case SortTapResult.wrong:
        _settings.medium();
        _music?.play(Sfx.wrong);
        _armLapse();
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
    _armLapse();
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
