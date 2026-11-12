part of '../sort_screen.dart';

/// How a Sort round ends: finishing, running out of time, or starting over.
mixin _SortFlow on _SortStateBase {
  /// A wide shine sweeps once across the finished picture.
  void _startSweep() {
    if (MediaQuery.of(context).disableAnimations) return;
    _shimmer.poke();
    setState(() => _sweepAt = DateTime.now());
  }

  @override
  Future<void> _finish() async {
    _finished = true;
    if (widget.tutorial) {
      setState(() => _coach = _SortStateBase._coachSteps.length);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _celebrate = true);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC107), size: 40),
          title: const Text("You're ready!"),
          content: const Text('Every Sort picture works just like this one. Keep your combo going and have fun!'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Let's go"))],
        ),
      );
      _endTutorial();
      return;
    }
    final difficulty = widget.timeAttack;
    final relaxed = difficulty == null && (game.relaxed || game.excusedMistakes);
    final stars = relaxed ? 0 : game.stars;
    if (widget.daily) recordDailyIfToday(widget.store, widget.puzzle);
    final secondsLeft = game.timeLeft;
    final Future<bool> best;
    if (difficulty != null) {
      final overall = widget.store
          .recordTimeAttack(difficulty, won: true, score: game.score, combo: game.bestCombo, secondsLeft: secondsLeft);
      best = widget.dailyChallenge
          ? widget.store.recordDailyTimeAttack(DateTime.now(),
              won: true, score: game.score, combo: game.bestCombo, secondsLeft: secondsLeft)
          : overall;
    } else {
      widget.store.noteCombo(game.bestCombo);
      best = widget.store.recordCompletion(
        PlayMode.sort.key(widget.puzzle.id),
        score: relaxed ? 0 : game.score,
        stars: stars,
        seconds: game.seconds,
      );
    }
    // Let the last beads land, then glide out to the whole picture.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _celebrate = true);
    final (toScale, toOffset) = view.fitTransform();
    final fromScale = view.scale, fromOffset = view.offset;
    final glide = _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final curve = CurvedAnimation(parent: glide, curve: Curves.easeInOutCubic);
    glide.addListener(() => view.setTransform(
          lerpDouble(fromScale, toScale, curve.value)!,
          Offset.lerp(fromOffset, toOffset, curve.value)!,
        ));
    await glide.forward();
    if (!mounted) return;
    _startSweep();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final isBest = await best;
    if (!mounted) return;
    final badges = takeNewAchievements(allCourses, widget.store);
    await showCompletionSheet(
      context,
      puzzle: widget.puzzle,
      score: game.score,
      stars: stars,
      seconds: game.seconds,
      mistakes: game.game.mistakes + game.game.shakes,
      isBest: isBest,
      relaxed: relaxed,
      badges: badges,
      unlocked: takeNewUnlocks(widget.store, allCourses),
      bestCombo: game.bestCombo,
      secondsLeft: difficulty == null ? null : secondsLeft,
      title: difficulty == null ? 'Masterpiece complete!' : 'You beat the clock!',
      done: difficulty == null ? 'Back to the course' : 'Back to Time Attack',
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Time Attack ran out: count the round and offer another go.
  /// The board for another try: a fresh scramble, except today's challenge
  /// which stays the same.
  int get _nextSeed => widget.dailyChallenge ? widget.seed : widget.seed + 1;

  @override
  Future<void> _timeUp() async {
    _finished = true;
    _settings.heavy();
    _music?.play(Sfx.wrong);
    setState(() {});
    await widget.store
        .recordTimeAttack(widget.timeAttack!, won: false, score: game.score, combo: game.bestCombo, secondsLeft: 0);
    if (widget.dailyChallenge) {
      await widget.store
          .recordDailyTimeAttack(DateTime.now(), won: false, score: game.score, combo: game.bestCombo, secondsLeft: 0);
    }
    if (!mounted) return;
    final badges = takeNewAchievements(allCourses, widget.store);
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.timer_off_rounded, size: 40),
        title: const Text("Time's up!"),
        content: Text([
          'You sorted ${(game.progress * 100).floor()}% of ${widget.puzzle.title}.',
          if (game.bestCombo > 1) 'Best combo: ×${game.bestCombo}.',
          for (final b in badges) 'New badge: ${b.title}!',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Try again')),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SortScreen(
          puzzle: widget.puzzle,
          store: widget.store,
          timeAttack: widget.timeAttack,
          seed: _nextSeed,
          dailyChallenge: widget.dailyChallenge,
        ),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('The picture gets scrambled again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start over')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _finished = true;
    if (!_timed) await widget.store.resetPuzzle(PlayMode.sort.key(widget.puzzle.id));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => SortScreen(
                puzzle: widget.puzzle,
                store: widget.store,
                daily: widget.daily,
                tutorial: widget.tutorial,
                timeAttack: widget.timeAttack,
                seed: _nextSeed,
                dailyChallenge: widget.dailyChallenge,
              )),
    );
  }
}
