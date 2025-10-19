import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'audio_manager.dart';

class HauntedGame extends StatefulWidget {
  const HauntedGame({super.key});

  @override
  State<HauntedGame> createState() => _HauntedGameState();
}

class _Ghost {
  Offset pos;
  final String asset;
  final int id;
  final double size;
  _Ghost(this.pos, this.asset, this.size, this.id);
}

class _HauntedGameState extends State<HauntedGame>
    with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _countdownTimer;
  int _timeLeft = 0;
  int _score = 0;
  List<_Ghost> _ghosts = [];
  bool _running = false;
  int _countdown = 0;
  List<_HitPopup> _hitPopups = [];

  // level system
  int _level = 1;
  int get _levelTime => 15 * (1 << (_level - 1)); // 15 * 2^(level-1)
  // make target grow faster so game becomes harder: 30 * level * 2^(level-1)
  int get _levelTarget => 30 * _level * (1 << (_level - 1));

  // ghost asset pools - more assets added as level increases
  final List<String> _poolAll = [
    'assets/img/trick-treat6-img.png', // level 1 base
    'assets/img/footer1-img.png',
    'assets/img/category1-img.png',
    'assets/img/home3-img.png',
  ];

  @override
  void initState() {
    super.initState();
    _resetGame();
    _prepareStart();
  }

  void _resetGame() {
    setState(() {
      _timeLeft = 20;
      _score = 0;
      _ghosts = [];
      _hitPopups = [];
    });
  }

  void _prepareStart() {
    _countdown = 3;
    _running = false;
    // play haunted bgm (placeholder asset — add real file at assets/audio/haunted_bgm.mp3)
    AudioManager.instance.playBgm('assets/audio/haunted_bgm.mp3');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          t.cancel();
          _countdownTimer = null;
          _running = true;
          _startTimer();
          _spawnGhosts(3);
        }
      });
    });
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          // occasionally spawn new ghosts
          final spawnProb = (0.35 + (_level * 0.12)).clamp(0.0, 0.95);
          if (_rng.nextDouble() < spawnProb) {
            _spawnGhosts(1);
          }
        } else {
          t.cancel();
          _running = false;
        }
      });
    });
    // spawn timer to add ghosts more frequently
    final interval = (700 - (_level * 60)).clamp(300, 1000).toInt();
    _spawnTimer = Timer.periodic(Duration(milliseconds: interval), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_running) return;
      final spawnProb = (0.55 + (_level * 0.08)).clamp(0.0, 0.98);
      if (_rng.nextDouble() < spawnProb) _spawnGhosts(1);
    });
  }

  double get _progressPercent {
    if (_levelTarget <= 0) return 0.0;
    return (_score / _levelTarget).clamp(0.0, 1.0);
  }

  void _spawnGhosts(int count) {
    final assets = _poolAll.sublist(
      0,
      (_level <= _poolAll.length) ? _level : _poolAll.length,
    );
    for (var i = 0; i < count; i++) {
      final pos = Offset(_rng.nextDouble(), _rng.nextDouble());
      final asset = assets[_rng.nextInt(assets.length)];
      final size = 48.0 + _rng.nextInt(48);
      _ghosts.add(
        _Ghost(pos, asset, size, DateTime.now().microsecondsSinceEpoch + i),
      );
    }
  }

  void _hitGhost(int index) {
    final g = _ghosts[index];
    final tapPos = g.pos;
    setState(() {
      // award points based on ghost size: smaller ghosts are worth more
      final points =
          (g.size < 64)
              ? 15
              : (g.size < 88)
              ? 10
              : 5;
      _score += points;
      _hitPopups.add(
        _HitPopup(position: tapPos, id: DateTime.now().millisecondsSinceEpoch),
      );
      _ghosts.removeAt(index);
    });
    // sound effect for banish
    AudioManager.instance.playSfx('assets/audio/ghost_banish.wav');
    // schedule popup removal
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        final cutoff = DateTime.now().millisecondsSinceEpoch - 700;
        _hitPopups.removeWhere((p) => p.id < cutoff);
      });
    });
    // check level progression
    if (_score >= _levelTarget) {
      // advance
      _advanceLevel();
    }
  }

  void _advanceLevel() {
    setState(() {
      _level++;
      _running = false;
      _gameTimer?.cancel();
      _spawnTimer?.cancel();
    });
    // show level success overlay briefly and pause timers while modal is up
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: Text(
              'Level ${_level - 1} Cleared!',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              'Next: Level $_level\nTarget: $_levelTarget\nTime: $_levelTime s',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // return home
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Return Home',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // start next level
                  setState(() {
                    _timeLeft = _levelTime;
                    _ghosts.clear();
                    _startTimer();
                    _running = true;
                  });
                },
                child: const Text(
                  'Start',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    // stop bgm when leaving
    AudioManager.instance.stopBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haunted House'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('How to play — Haunted House'),
                      content: const Text(
                        'Tap ghosts to banish them and score points. Smaller ghosts are worth more. Reach the level target before time runs out.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _timeLeft = _levelTime;
                              _score = 0;
                              _ghosts.clear();
                              _startTimer();
                              _running = true;
                            });
                          },
                          child: const Text('Play'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level: $_level',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Target: $_levelTarget',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Time: $_timeLeft',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Score: $_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: LinearProgressIndicator(
                value: _progressPercent,
                backgroundColor: Colors.white24,
                color: Colors.deepOrangeAccent,
                minHeight: 6,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // spooky background
                      Positioned.fill(
                        child: Image.asset(
                          'assets/img/bkg-haunted-house.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // ghosts
                      for (var i = 0; i < _ghosts.length; i++)
                        Positioned(
                          left:
                              (() {
                                final raw =
                                    _ghosts[i].pos.dx *
                                    (constraints.maxWidth -
                                        _ghosts[i].size -
                                        8);
                                final maxLeft = (constraints.maxWidth -
                                        _ghosts[i].size -
                                        8)
                                    .clamp(0.0, double.infinity);
                                return raw.clamp(0.0, maxLeft).toDouble();
                              })(),
                          top:
                              (() {
                                final raw =
                                    _ghosts[i].pos.dy *
                                    (constraints.maxHeight -
                                        _ghosts[i].size -
                                        12);
                                final maxTop = (constraints.maxHeight -
                                        _ghosts[i].size -
                                        12)
                                    .clamp(0.0, double.infinity);
                                return raw.clamp(0.0, maxTop).toDouble();
                              })(),
                          child: GestureDetector(
                            onTap: _running ? () => _hitGhost(i) : null,
                            child: _GhostImage(
                              asset: _ghosts[i].asset,
                              size: _ghosts[i].size,
                            ),
                          ),
                        ),
                      // hit popups
                      for (var p in _hitPopups)
                        Positioned(
                          left: p.position.dx * (constraints.maxWidth - 80),
                          top:
                              p.position.dy * (constraints.maxHeight - 160) -
                              20,
                          child: _HitPopupWidget(text: '+10'),
                        ),
                      // countdown
                      if (!_running)
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              _countdown > 0 ? '$_countdown' : 'Go!',
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(color: Colors.white, fontSize: 72),
                            ),
                          ),
                        ),
                      // end overlay
                      if (_timeLeft == 0)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black87,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Time\'s up!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Final Score: $_score',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton(
                                    onPressed: () {
                                      _resetGame();
                                      _startTimer();
                                      _spawnGhosts(3);
                                    },
                                    child: const Text('Play Again'),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('Return Home'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hints: Tap ghosts to banish them',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Spawn'),
                    onPressed:
                        () => mounted ? setState(() => _spawnGhosts(1)) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Old generic ghost widget removed. Using image-based ghosts below.

class _HitPopup {
  final Offset position;
  final int id;
  _HitPopup({required this.position, required this.id});
}

class _HitPopupWidget extends StatefulWidget {
  final String text;
  const _HitPopupWidget({required this.text});

  @override
  State<_HitPopupWidget> createState() => _HitPopupWidgetState();
}

class _HitPopupWidgetState extends State<_HitPopupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
      child: ScaleTransition(
        scale: Tween(
          begin: 1.0,
          end: 1.4,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 87, 34, 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostImage extends StatefulWidget {
  final String asset;
  final double size;
  const _GhostImage({required this.asset, required this.size});

  @override
  State<_GhostImage> createState() => _GhostImageState();
}

class _GhostImageState extends State<_GhostImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final float = sin(_ctrl.value * 2 * pi) * 8;
        final scale = 0.94 + (_ctrl.value * 0.12);
        return Transform.translate(
          offset: Offset(0, float),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Image.asset(widget.asset),
            ),
          ),
        );
      },
    );
  }
}
