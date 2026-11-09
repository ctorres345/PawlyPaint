part of '../sort_screen.dart';

/// The Sort screen's layout: app bar, stats, board, overlays and tray.
mixin _SortLayout on _SortStateBase {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _finished) return;
        _save();
        if (widget.tutorial) widget.store.markSortTutorialSeen();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: SettingsScope.of(context).theme.desk,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          title: Text(_timed
              ? (widget.dailyChallenge ? 'Daily · ${widget.timeAttack!.label}' : '${widget.timeAttack!.label} run')
              : _finished || widget.store.isDone(widget.puzzle.id)
                  ? widget.puzzle.title
                  : 'Sort the beads'),
          actions: [
            IconButton(
              tooltip: 'Hint',
              icon: const Icon(Icons.tips_and_updates_outlined),
              onPressed: _finished ? null : _hint,
            ),
            IconButton(
              tooltip: showWrong ? 'Hide misplaced beads' : 'Mark misplaced beads',
              icon: Icon(showWrong ? Icons.visibility_rounded : Icons.visibility_outlined),
              onPressed: () => setState(() => showWrong = !showWrong),
            ),
            const MusicButton(),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'restart') _confirmRestart();
                if (v == 'fit') view.fit(view.viewport, widget.puzzle.width, widget.puzzle.height);
                if (v == 'tips') setState(() => _showTips = true);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'fit', child: Text('Show whole canvas')),
                PopupMenuItem(value: 'tips', child: Text('How to play')),
                PopupMenuItem(value: 'restart', child: Text('Start over')),
              ],
            ),
          ],
        ),
        body: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                RepaintBoundary(
                    child: ListenableBuilder(
                  listenable: SettingsScope.of(context).relaxed && !_timed ? game : Listenable.merge([game, clock]),
                  builder: (context, _) => _SortStats(
                    relaxed: game.relaxed && !_timed,
                    progress: game.progress,
                    seconds: _timed ? game.timeLeft : clock.value,
                    countdown: _timed,
                    left: game.game.wrongCount,
                  ),
                )),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                              child: CustomPaint(painter: DeskPainter(SettingsScope.of(context).theme))),
                        ),
                        Positioned.fill(
                          child: Semantics(
                            label: 'Scrambled picture',
                            hint: 'Tap a misplaced bead to pick it up, then tap the tray or an empty spot.',
                            child: Listener(
                                onPointerDown: (_) => _shimmer.poke(),
                                child: RepaintBoundary(
                                    child: _SortBoard(
                                  key: _boardKey,
                                  game: game,
                                  view: view,
                                  shimmer: shimmer,
                                  frame: frame,
                                  paints: paints,
                                  showWrong: showWrong,
                                  peek: peeking,
                                  celebrate: _celebrate,
                                  sweepAt: _sweepAt,
                                  onTap: _tap,
                                ))),
                          ),
                        ),
                        if (!_showTips && !_finished)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: _PeekThumb(
                              puzzle: widget.puzzle,
                              onPeek: (on) {
                                setState(() => peeking = on);
                                if (on && widget.tutorial && _coach == 3) setState(() => _coach = 4);
                              },
                            ),
                          ),
                        if (!_showTips && !_finished)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: _ComboMeter(game: game, bar: _comboBar),
                          ),
                        if (!_showTips && !_finished && !widget.tutorial)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: MiniMap(
                              width: widget.puzzle.width,
                              height: widget.puzzle.height,
                              board: game,
                              version: () => game.boardVersion,
                              cellPaint: (i) {
                                final c = game.game.current[i];
                                return c < 0 ? null : paints[c].base;
                              },
                              view: view,
                            ),
                          ),
                        if (widget.tutorial && _coach < _SortStateBase._coachSteps.length)
                          Positioned(
                            left: 112,
                            right: 12,
                            top: 10,
                            child: CoachCard(
                              steps: _SortStateBase._coachSteps,
                              step: _coach,
                              onNext: () => setState(() => _coach++),
                              onSkip: _endTutorial,
                            ),
                          ),
                        if (_showTips)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: _SortTips(onDone: () {
                              setState(() => _showTips = false);
                              widget.store.markSortTutorialSeen();
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: _TrayPanel(
                    trayKey: _trayKey,
                    game: game,
                    paints: paints,
                    frame: frame,
                    onTap: _tapTray,
                    onShake: () {
                      if (game.shake()) {
                        _wakeTicker();
                        _settings.medium();
                        _music?.play(Sfx.shake);
                        if (_timed) _toast('Shake: −${TimeAttack.helpCost} seconds');
                      }
                    },
                    onUndo: () {
                      if (game.undo()) {
                        _settings.selection();
                        _music?.play(Sfx.place);
                      }
                    },
                  ),
                ),
              ],
            ),
            // Beads flying between the board and the tray.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlightPainter(
                    game: game,
                    frame: frame,
                    paints: paints,
                    view: view,
                    cellCenter: _cellCenter,
                    slotRect: _slotRect,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
