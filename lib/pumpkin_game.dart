import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'audio_manager.dart';

class PumpkinGame extends StatefulWidget {
  const PumpkinGame({super.key});

  @override
  State<PumpkinGame> createState() => _PumpkinGameState();
}

class _Pumpkin {
  Offset position;
  final String asset;
  final double size;
  final int id;

  // spawnTime used for lifetime pruning
  final int spawnTime = DateTime.now().millisecondsSinceEpoch;

  _Pumpkin(this.position, this.asset, this.size, this.id);
}

class _PumpkinGameState extends State<PumpkinGame>
    with TickerProviderStateMixin {
  final Random _rng = Random();
  int _timeLeft = 0;
  int _score = 0;
  Timer? _timer;
  Timer? _spawnTimer;
  final List<_Pumpkin> _pumpkins = [];
  int _nextId = 0;
  int _level = 1;

  int get _levelTime => 15 * (1 << (_level - 1));
  int get _levelTarget => 30 * _level * (1 << (_level - 1));

  final List<String> _assets = [
    'assets/img/trick-treat1-img.png',
    'assets/img/trick-treat2-img.png',
    'assets/img/trick-treat3-img.png',
    'assets/img/trick-treat4-img.png',
    'assets/img/trick-treat5-img.png',
    'assets/img/trick-treat6-img.png',
    'assets/img/new1-img.png',
    'assets/img/new2-img.png',
    'assets/img/new3-img.png',
    'assets/img/new4-img.png',
  ];

  @override
  void initState() {
    super.initState();
    _prepareStart();
    // play pumpkin bgm (placeholder asset — add real file at assets/audio/pumpkin_bgm.mp3)
    AudioManager.instance.playBgm('assets/audio/pumpkin_bgm.mp3');
  }

  // tutorial is handled from the home screen; no in-game overlay

  void _prepareStart() {
    _timeLeft = _levelTime;
    _score = 0;
    _pumpkins.clear();
    _nextId = 0;
    _timer?.cancel();
    _spawnTimer?.cancel();
    // start directly
    _start();
  }

  void _pauseGame() {
    _timer?.cancel();
    _spawnTimer?.cancel();
  }

  void _resumeGame() {
    if (_timeLeft > 0) _start();
  }

  void _start() {
    _timeLeft = _levelTime;
    _score = 0;
    _pumpkins.clear();
    _nextId = 0;
    _timer?.cancel();
    _spawnTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          t.cancel();
          _spawnTimer?.cancel();
        }
      });
    });

    // spawn pumpkins at varying intervals and prune expired pumpkins
    // harder tuning: slightly faster spawn and higher density
    final baseInterval = (560 - (_level * 48)).clamp(220, 820).toInt();
    _spawnTimer = Timer.periodic(Duration(milliseconds: baseInterval), (t) {
      if (_timeLeft <= 0) return;
      // increase chance of spawn with level, but capped
      final spawnProb = (0.65 + _level * 0.14).clamp(0.0, 0.99);
      if (_rng.nextDouble() < spawnProb) {
        setState(() {
          _spawnRandomPumpkin();
        });
      }
      // prune oldest pumpkins when list too large
      if (_pumpkins.length > 18)
        _pumpkins.removeRange(0, _pumpkins.length - 18);
      // also prune pumpkins older than 6500ms (harder)
      final now = DateTime.now().millisecondsSinceEpoch;
      _pumpkins.removeWhere((p) => (now - p.spawnTime) > 6500);
    });
  }

  void _spawnRandomPumpkin() {
    final asset = _assets[_rng.nextInt(_assets.length)];
    final size = 40 + _rng.nextInt(64); // 40..104 for more variety
    final pos = Offset(_rng.nextDouble(), _rng.nextDouble());
    _pumpkins.add(_Pumpkin(pos, asset, size.toDouble(), _nextId++));
    // keep list manageable
    if (_pumpkins.length > 22) _pumpkins.removeAt(0);
  }

  void _collectPumpkin(int id) {
    setState(() {
      final idx = _pumpkins.indexWhere((p) => p.id == id);
      if (idx != -1) {
        // award points based on size (smaller = more)
        final p = _pumpkins[idx];
        final points =
            (p.size < 64)
                ? 24
                : (p.size < 88)
                ? 14
                : 6;
        _score += points;
        _pumpkins.removeAt(idx);
        // play collect sfx
        AudioManager.instance.playSfx('assets/audio/collect.wav');
      }
      // check level success
      if (_score >= _levelTarget) {
        _onLevelComplete();
      }
    });
  }

  void _onLevelComplete() {
    // pause and show modal, resume only when dialog closed
    _pauseGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: Text(
              'Level $_level Cleared!',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              'Score: $_score\nNext Level: ${_level + 1}\nTarget: ${_levelTarget * 2}\nTime: ${_levelTime * 2}s',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
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
                  // retry same level
                  setState(() {
                    _prepareStart();
                  });
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _level++;
                    _prepareStart();
                  });
                },
                child: const Text(
                  'Next',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    ).then((_) => _resumeGame());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spawnTimer?.cancel();
    // stop bgm when leaving pumpkin game
    AudioManager.instance.stopBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pumpkin Pick'),
        backgroundColor: Colors.deepOrange.shade700,
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('How to play — Pumpkin Pick'),
                      content: const Text(
                        'Tap pumpkins to collect points. Smaller pumpkins are worth more. Reach the target before time runs out to clear the level.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() => _prepareStart());
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
      body: Column(
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
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Target: $_levelTarget',
                      style: const TextStyle(
                        color: Colors.black87,
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
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      'Score: $_score',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remaining: ${(_levelTarget - _score).clamp(0, _levelTarget)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orangeAccent,
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
              value:
                  (_levelTarget > 0)
                      ? (_score / _levelTarget).clamp(0.0, 1.0)
                      : 0.0,
              backgroundColor: Colors.white24,
              color: Colors.orangeAccent,
              minHeight: 6,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // background image
                    Positioned.fill(
                      child: Image.asset(
                        'assets/img/pumpkin-pick.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // pumpkins
                    for (var p in List<_Pumpkin>.from(_pumpkins))
                      _AnimatedPumpkin(
                        key: ValueKey('pumpkin-${p.id}'),
                        pumpkin: p,
                        parentSize: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        onCollected: () => _collectPumpkin(p.id),
                      ),

                    // tutorial overlay removed; use home-screen How-to dialog instead
                    if (_timeLeft == 0)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Time's up!",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Final Score: $_score',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => _prepareStart(),
                                  child: const Text('Retry Level'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _level = 1;
                                    });
                                    Navigator.of(context).pop();
                                  },
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
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _start(),
                  child: const Text('Restart'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Home'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPumpkin extends StatefulWidget {
  final _Pumpkin pumpkin;
  final Size parentSize;
  final VoidCallback onCollected;

  const _AnimatedPumpkin({
    super.key,
    required this.pumpkin,
    required this.parentSize,
    required this.onCollected,
  });

  @override
  State<_AnimatedPumpkin> createState() => _AnimatedPumpkinState();
}

class _AnimatedPumpkinState extends State<_AnimatedPumpkin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = Offset(
      widget.pumpkin.position.dx *
          (widget.parentSize.width - widget.pumpkin.size),
      widget.pumpkin.position.dy *
          (widget.parentSize.height - widget.pumpkin.size - 40),
    );
  }

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
        final float = sin(_ctrl.value * pi * 2) * 6; // small float motion
        return Positioned(
          left: _pos.dx,
          top: _pos.dy + float,
          child: _PumpkinTouchable(
            size: widget.pumpkin.size,
            asset: widget.pumpkin.asset,
            onTap: () async {
              // play quick pop animation before collecting
              await showDialog(
                context: context,
                barrierColor: Colors.transparent,
                builder:
                    (ctx) => Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 0.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, v, child) {
                          return Transform.scale(
                            scale: 1.2 - v,
                            child: Opacity(opacity: 1.0 - v, child: child),
                          );
                        },
                        child: SizedBox(
                          width: widget.pumpkin.size,
                          height: widget.pumpkin.size,
                          child: Image.asset(widget.pumpkin.asset),
                        ),
                      ),
                    ),
              );
              widget.onCollected();
            },
          ),
        );
      },
    );
  }
}

class _PumpkinTouchable extends StatelessWidget {
  final double size;
  final String asset;
  final VoidCallback onTap;
  const _PumpkinTouchable({
    required this.size,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: size, height: size, child: Image.asset(asset)),
    );
  }
}
