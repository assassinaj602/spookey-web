import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'audio_manager.dart';

class Mission3Game extends StatefulWidget {
  const Mission3Game({super.key});

  @override
  State<Mission3Game> createState() => _Mission3GameState();
}

class _CardModel {
  final int id;
  final String asset; // we will use asset names as identifiers
  bool revealed = false;
  bool matched = false;
  _CardModel(this.id, this.asset);
}

class _Mission3GameState extends State<Mission3Game> {
  final Random _rng = Random();
  List<_CardModel> _cards = [];
  int _level = 1;
  int _timeLeft = 0;
  Timer? _timer;
  int _score = 0;
  bool _busy = false;
  // particle triggers per card id
  final Map<int, bool> _showParticles = {};

  int get _pairs => 4 + (_level - 1) * 1; // start with 4 pairs, +1 per level
  int get _levelTime => 30 + (_level - 1) * 8; // more time each level
  int get _levelTarget => (_pairs * 10);

  @override
  void initState() {
    super.initState();
    // play memory mansion bgm (placeholder asset — add real file at assets/audio/memory_bgm.mp3)
    AudioManager.instance.playBgm('assets/audio/memory_bgm.mp3');
    _startLevel();
  }

  void _startLevel() {
    _timer?.cancel();
    _score = 0;
    _timeLeft = _levelTime;
    _busy = false;
    _generateCards();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          t.cancel();
          // time expired — show dialog with retry/home
          WidgetsBinding.instance.addPostFrameCallback((_) => _onTimeExpired());
        }
      });
    });
  }

  void _onTimeExpired() {
    // If already all matched, ignore (other dialog handles it)
    if (_cards.every((c) => c.matched)) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: Text(
              "Time's up!",
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              'You scored $_score. Try again or go Home?',
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _startLevel();
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  void _generateCards() {
    // create _pairs pairs of matching labels (we'll use some built-in icons as assets)
    final icons = [
      '🍂',
      '🕸️',
      '🦇',
      '🎃',
      '🕯️',
      '👻',
      '🧙',
      '🦉',
      '🪦',
      '🔮',
    ];
    final used = icons.sublist(0, _pairs);
    final list = <_CardModel>[];
    int id = 0;
    for (var a in used) {
      list.add(_CardModel(id++, a));
      list.add(_CardModel(id++, a));
    }
    list.shuffle(_rng);
    setState(() {
      _cards = list;
    });
  }

  void _revealCard(int idx) async {
    if (_busy || _cards[idx].revealed || _cards[idx].matched || _timeLeft == 0)
      return;
    setState(() => _cards[idx].revealed = true);
    final revealed = _cards.where((c) => c.revealed && !c.matched).toList();
    if (revealed.length == 2) {
      _busy = true;
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() {
        if (revealed[0].asset == revealed[1].asset) {
          revealed[0].matched = true;
          revealed[1].matched = true;
          _score += 10;
          // play match SFX
          AudioManager.instance.playSfx('assets/audio/match.wav');
          // show particle bursts on both matched cards
          _showParticles[revealed[0].id] = true;
          _showParticles[revealed[1].id] = true;
          Timer(const Duration(milliseconds: 650), () {
            setState(() {
              _showParticles[revealed[0].id] = false;
              _showParticles[revealed[1].id] = false;
            });
          });
        } else {
          revealed[0].revealed = false;
          revealed[1].revealed = false;
        }
      });
      _busy = false;
      _checkLevelComplete();
    }
  }

  void _checkLevelComplete() {
    if (_cards.every((c) => c.matched)) {
      _timer?.cancel();
      // show level success
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
                'You matched all pairs! Score: $_score',
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
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _level++;
                      _startLevel();
                    });
                  },
                  child: const Text(
                    'Next',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    AudioManager.instance.stopBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // choose crossAxisCount so the grid remains compact and avoids scrolling on typical demo widths
    final cardCount = _pairs * 2;
    // We'll pick columns based on available width inside the LayoutBuilder so tiles can be small and fit on screen
    return Scaffold(
      appBar: AppBar(
        title: Text('Mission 3 — Memory Match'),
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
                        'How to play — Memory Mansion',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Tap cards to reveal them. Match pairs quickly to score. Try to match all pairs before time runs out. Use memory and speed!',
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
        backgroundColor: Colors.deepPurple.shade800,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/img/mission-3.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black54)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level: $_level',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Pairs: $_pairs',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Time: $_timeLeft',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Score: $_score',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (_score / (_levelTarget)).clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    color: Colors.purpleAccent,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // calculate a compact tile size so the whole grid fits both horizontally and vertically
                        final reservedHeight =
                            100.0; // header, progress and buttons
                        final availableHeight = max(
                          80.0,
                          constraints.maxHeight - reservedHeight,
                        );
                        // prefer more columns on wider screens so tiles stay small and all cards fit
                        int gridCount = max(
                          2,
                          min(10, (constraints.maxWidth / 64).floor()),
                        );
                        // ensure gridCount doesn't exceed cardCount
                        gridCount = min(gridCount, max(1, cardCount));
                        final rows = (cardCount / gridCount).ceil();
                        final widthBased =
                            (constraints.maxWidth - (gridCount - 1) * 8) /
                            gridCount;
                        final heightBased =
                            (availableHeight - (rows - 1) * 8) / rows;
                        // allow smaller tiles but keep a reasonable minimum so icons/text remain legible
                        final tileSize = max(
                          40.0,
                          min(widthBased, heightBased),
                        );
                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cards.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCount,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                          itemBuilder: (context, idx) {
                            final c = _cards[idx];
                            return SizedBox(
                              width: tileSize,
                              height: tileSize,
                              child: GestureDetector(
                                onTap: () => _revealCard(idx),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color:
                                            c.matched
                                                ? Colors.green.shade700
                                                : const Color.fromRGBO(
                                                  255,
                                                  255,
                                                  255,
                                                  0.06,
                                                ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              c.matched
                                                  ? Colors.greenAccent
                                                  : Colors.white12,
                                        ),
                                      ),
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          child:
                                              c.revealed || c.matched
                                                  ? Text(
                                                    c.asset,
                                                    key: ValueKey(
                                                      c.asset + c.id.toString(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: tileSize * 0.36,
                                                    ),
                                                  )
                                                  : Icon(
                                                    Icons.help_outline,
                                                    color: Colors.white24,
                                                    size: tileSize * 0.22,
                                                  ),
                                        ),
                                      ),
                                    ),
                                    if (_showParticles[c.id] == true)
                                      Positioned.fill(
                                        child: Center(
                                          child: _ParticleBurst(size: tileSize),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _startLevel();
                          });
                        },
                        child: const Text('Restart'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Home'),
                      ),
                    ],
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

// Simple particle burst used for match feedback
class _ParticleBurst extends StatefulWidget {
  final double size;
  const _ParticleBurst({required this.size, Key? key}) : super(key: key);

  @override
  State<_ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<_ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
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
          final t = Curves.easeOut.transform(_ctrl.value);
          final dots = List.generate(6, (i) {
            final angle = (i / 6) * pi * 2;
            final radius = widget.size * 0.35 * t;
            final dx = (widget.size / 2) + cos(angle) * radius;
            final dy = (widget.size / 2) + sin(angle) * radius;
            final alpha = (1.0 - t).clamp(0.0, 1.0);
            return Positioned(
              left: dx - 6,
              top: dy - 6,
              child: Opacity(
                opacity: alpha,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.9 * alpha),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          });
          return Stack(children: dots);
        },
      ),
    );
  }
}
