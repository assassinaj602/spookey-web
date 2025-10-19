import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'audio_manager.dart';

// Mission 4: Candle Keeper — single clean implementation

class Mission4Game extends StatefulWidget {
  const Mission4Game({Key? key}) : super(key: key);
  @override
  State<Mission4Game> createState() => _Mission4GameState();
}

class _Candle {
  final int id;
  bool lit;
  int lastChanged; // ms
  _Candle(this.id, {this.lit = true})
    : lastChanged = DateTime.now().millisecondsSinceEpoch;
}

class _Mission4GameState extends State<Mission4Game>
    with TickerProviderStateMixin {
  final Random _rng = Random();
  List<_Candle> _candles = [];
  Timer? _tick;
  int _timeLeft = 0;
  int _level = 1;
  int _score = 0;
  bool _running = false;
  int _relightCooldown = 0; // ms

  // give players more time and a lower target to make early levels easier
  int get _levelTime => 30 + (_level - 1) * 6;
  int get _targetScore => 40 * _level;

  @override
  void initState() {
    super.initState();
    // play candle keepers bgm (placeholder asset — add real file at assets/audio/candle_bgm.mp3)
    AudioManager.instance.playBgm('assets/audio/candle_bgm.mp3');
    _startLevel();
  }

  void _startLevel() {
    _tick?.cancel();
    _timeLeft = _levelTime;
    _score = 0;
    _relightCooldown = 0;
    // start with more candles and bias them to lit so early levels are forgiving
    final initialCount = max(8, 6 + (_level - 1));
    _candles = List.generate(
      initialCount,
      // higher lit probability at start to make the level easier (~85% lit)
      (i) => _Candle(i, lit: _rng.nextDouble() > 0.15),
    );
    // ensure we never start already failed: relight randomly until fewer than half are out
    int out = _candles.where((c) => !c.lit).length;
    final threshold = (initialCount / 2).ceil();
    while (out >= threshold) {
      final outs = _candles.where((c) => !c.lit).toList();
      if (outs.isEmpty) break;
      outs[_rng.nextInt(outs.length)].lit = true;
      out = _candles.where((c) => !c.lit).length;
    }
    _running = true;
    _tick = Timer.periodic(const Duration(seconds: 1), _onTick);
    setState(() {});
  }

  void _onTick(Timer t) {
    if (_timeLeft <= 0) {
      t.cancel();
      setState(() => _running = false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showTimeExpiredDialog(),
      );
      return;
    }
    setState(() {
      _timeLeft--;
      if (_relightCooldown > 0)
        _relightCooldown = max(0, _relightCooldown - 1000);

      // tuned extinguish chance: lower base and milder scaling for easier recovery
      final chance = (0.06 + _level * 0.02).clamp(0.03, 0.5);
      // each tick, a random candle may go out (probability scaled by level)
      if (_rng.nextDouble() < chance) {
        final lit = _candles.where((c) => c.lit).toList();
        if (lit.isNotEmpty) {
          final pick = lit[_rng.nextInt(lit.length)];
          pick.lit = false;
          pick.lastChanged = DateTime.now().millisecondsSinceEpoch;
          // reduced penalty when a candle goes out so players can recover
          _score = max(0, _score - 2 * _level);
          // candle extinguish sound
          AudioManager.instance.playSfx('assets/audio/candle_out.wav');
        }
      }

      // incremental scoring: keep score as an accumulated resource so players can reach a target
      // reward for each lit candle each tick (kept small — target is higher)
      final litCount = _candles.where((c) => c.lit).length;
      // slightly higher per-tick reward per lit candle to help reach target
      _score += litCount * (3 * _level);

      // lose if too many candles are out
      final out = _candles.where((c) => !c.lit).length;
      if (out >= (_candles.length / 2).ceil()) {
        t.cancel();
        _running = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showTimeExpiredDialog(),
        );
        return;
      }

      // win condition: reach target score before time expires
      if (_score >= _targetScore) {
        t.cancel();
        _running = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
        return;
      }
    });
  }

  void _relight(int id) {
    if (!_running) return;
    setState(() {
      final c = _candles.firstWhere((c) => c.id == id);
      if (!c.lit) {
        c.lit = true;
        c.lastChanged = DateTime.now().millisecondsSinceEpoch;
        // reward relighting with a larger burst to help recovery
        _score += 10 * _level;
        AudioManager.instance.playSfx('assets/audio/relight.wav');
      } else {
        // small reward for tapping an already-lit candle
        _score += 1;
        AudioManager.instance.playSfx('assets/audio/tap.wav');
      }
    });
  }

  void _relightAll() {
    if (!_running || _relightCooldown > 0) return;
    setState(() {
      for (var c in _candles) {
        c.lit = true;
        c.lastChanged = DateTime.now().millisecondsSinceEpoch;
      }
      // stronger reward for Relight All but reasonable cooldown
      _score += 20 * _level;
      _relightCooldown = 10000; // ms
      AudioManager.instance.playSfx('assets/audio/relight_all.wav');
    });
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'You Win!',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'You reached the target score: $_score',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Home',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _level++;
                    _startLevel();
                  });
                },
                child: const Text('Next'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    AudioManager.instance.stopBgm();
    super.dispose();
  }

  void _showTimeExpiredDialog() {
    final outCount = _candles.where((c) => !c.lit).length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: Text(
              outCount >= (_candles.length / 2).ceil()
                  ? 'You lost'
                  : "Time's up!",
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              outCount >= (_candles.length / 2).ceil()
                  ? 'Too many candles went out.'
                  : 'You scored $_score.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Home',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _startLevel();
                  });
                },
                child: const Text('Retry'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _level++;
                    _startLevel();
                  });
                },
                child: const Text('Next'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outCount = _candles.where((c) => !c.lit).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission 4 — Candle Keeper'),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor: Colors.black87,
                      title: const Text(
                        'How to play — Candle Keepers',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Tap an out candle to relight it. Keep as many candles lit as possible to accumulate score. Use Relight All sparingly — it has a cooldown.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/img/mission-4.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black45)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Level: $_level',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Time: $_timeLeft',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Score: $_score',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_score / _targetScore).clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.count(
                      // compute a responsive grid count and tile size to keep candles compact
                      crossAxisCount: max(
                        2,
                        min(
                          6,
                          (MediaQuery.of(context).size.width / 110).floor(),
                        ),
                      ),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children:
                          _candles.map((c) {
                            return LayoutBuilder(
                              builder: (ctx, cons) {
                                final tileSize = min(
                                  cons.maxWidth,
                                  cons.maxHeight,
                                ).clamp(48.0, 140.0);
                                return SizedBox(
                                  width: tileSize,
                                  height: tileSize,
                                  child: GestureDetector(
                                    onTap: () => _relight(c.id),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient:
                                            c.lit
                                                ? RadialGradient(
                                                  colors: [
                                                    const Color.fromRGBO(
                                                      255,
                                                      183,
                                                      77,
                                                      0.16,
                                                    ),
                                                    Colors.transparent,
                                                  ],
                                                  radius: 0.9,
                                                )
                                                : null,
                                        color:
                                            c.lit
                                                ? const Color.fromRGBO(
                                                  30,
                                                  20,
                                                  10,
                                                  0.10,
                                                )
                                                : Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow:
                                            c.lit
                                                ? [
                                                  BoxShadow(
                                                    color: const Color.fromRGBO(
                                                      255,
                                                      140,
                                                      0,
                                                      0.12,
                                                    ),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                                : null,
                                        border: Border.all(
                                          color:
                                              c.lit
                                                  ? Colors.orangeAccent
                                                  : Colors.grey.shade800,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                c.lit
                                                    ? Icons
                                                        .local_fire_department
                                                    : Icons.air,
                                                size: tileSize * 0.38,
                                                color:
                                                    c.lit
                                                        ? Colors.orangeAccent
                                                        : Colors.grey,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                c.lit ? 'Lit' : 'Out',
                                                style: TextStyle(
                                                  color:
                                                      c.lit
                                                          ? Colors.white
                                                          : Colors.white70,
                                                  fontSize: tileSize * 0.12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (DateTime.now()
                                                      .millisecondsSinceEpoch -
                                                  c.lastChanged <
                                              700)
                                            Positioned.fill(
                                              child: Center(
                                                child: _Spark(
                                                  size: tileSize * 0.7,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // use Wrap so buttons wrap on small screens instead of overflowing
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _relightAll,
                        icon: const Icon(Icons.flash_on),
                        label: Text(
                          _relightCooldown > 0
                              ? 'Relight (${(_relightCooldown / 1000).ceil()}s)'
                              : 'Relight All',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _level = 1;
                            _startLevel();
                          });
                        },
                        child: const Text('Restart'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Home'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_running)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black87,
                      child: Column(
                        children: [
                          Text(
                            outCount >= (_candles.length / 2).ceil()
                                ? 'You lost — too many candles went out'
                                : "Time's up!",
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _level++;
                                _startLevel();
                              });
                            },
                            child: const Text('Next Level'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatefulWidget {
  final double size;
  const _Spark({required this.size, Key? key}) : super(key: key);
  @override
  State<_Spark> createState() => _SparkState();
}

class _SparkState extends State<_Spark> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;
          return Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 1 + t * 0.6,
              child: Center(
                child: Container(
                  width: widget.size * 0.2,
                  height: widget.size * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(
                          255,
                          140,
                          0,
                          (0.6 * (1 - t)).clamp(0.0, 1.0),
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
