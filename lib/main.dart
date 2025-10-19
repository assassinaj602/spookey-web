import 'package:flutter/material.dart';
import 'haunted_game.dart';
import 'pumpkin_game.dart';
import 'mission3_game.dart';
import 'mission4_game.dart';
import 'audio_manager.dart';
import 'screenshot_viewer.dart';

// A RouteObserver to notify the home page when it becomes visible again
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'spookey web',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const MyHomePage(title: 'spookey web'),
      navigatorObservers: [routeObserver],
      routes: {
        '/haunted': (context) => const HauntedGame(),
        '/pumpkin': (context) => const PumpkinGame(),
        '/mission3': (context) => const Mission3Game(),
        '/mission4': (context) => const Mission4Game(),
        '/screenshots': (context) => const ScreenshotViewer(),
      },
    );
  }
}

class StyledTitle extends StatelessWidget {
  final String text;
  const StyledTitle({this.text = 'spookey web', super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final baseSize = isMobile ? 48.0 : 72.0;
    final grad = const LinearGradient(
      colors: [Color(0xFFFF7043), Color(0xFFD84315)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final stroke = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: baseSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        foreground:
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = baseSize * 0.10
              ..color = Colors.white,
      ),
    );

    final fill = ShaderMask(
      shaderCallback:
          (bounds) => grad.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: baseSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );

    return SizedBox(
      height: isMobile ? 64 : 92,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(alignment: Alignment.center, children: [stroke, fill]),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback onTap;

  const _GameTile({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Card(
      color: const Color.fromRGBO(33, 33, 33, 0.45),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // image panel: fixed-width square to avoid vertical overflow
            SizedBox(
              width: isMobile ? 88 : 120,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.asset(asset, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 8.0 : 12.0,
                  horizontal: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: isMobile ? 16 : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.play_arrow,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  bool _isVisible = false;
  bool _showEnableAudio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // attempt to preload and start main screen bgm (will still be subject to platform autoplay rules)
    AudioManager.instance.ensureStartedFromUserGesture(
      mainBgm: 'assets/audio/main_screen.mp3',
    );
    // also attempt to play directly (some platforms will allow it)
    AudioManager.instance.playBgm('assets/audio/main_screen.mp3');
    // check shortly whether autoplay succeeded; if not, show a small banner to let user enable audio
    Future.delayed(const Duration(milliseconds: 600), () {
      final blocked =
          !AudioManager.instance.isBgmPlaying &&
          AudioManager.instance.bgmVolume > 0.0;
      if (blocked) setState(() => _showEnableAudio = true);
    });
    _isVisible = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    AudioManager.instance.stopBgm();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // subscribe to route changes so we can resume bgm when navigating back here
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Returned to this route (another route was popped). Resume bgm.
    // try resume first, if not playing try to restart the bgm (some platforms stop on navigation)
    AudioManager.instance.resumeBgm();
    Future.delayed(const Duration(milliseconds: 200), () async {
      if (!AudioManager.instance.isBgmPlaying &&
          AudioManager.instance.bgmVolume > 0.0) {
        await AudioManager.instance.playBgm('assets/audio/main_screen.mp3');
        setState(() => _showEnableAudio = !AudioManager.instance.isBgmPlaying);
      }
    });
  }

  @override
  void didPushNext() {
    // Another route was pushed above this one. Pause bgm.
    AudioManager.instance.pauseBgm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // pause music when app inactive
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioManager.instance.pauseBgm();
    } else if (state == AppLifecycleState.resumed && _isVisible) {
      AudioManager.instance.resumeBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final gridCols = isMobile ? 1 : 2;
    final tileAspect = isMobile ? 2.6 : 3.6;
    final contentWidth = isMobile ? double.infinity : 900.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => _SoundSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/img/bkg.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.28)),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12.0 : 28.0,
                vertical: isMobile ? 8.0 : 18.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stylized single-line title
                  const StyledTitle(text: 'spookey web'),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: GridView.count(
                          crossAxisCount: gridCols,
                          shrinkWrap: true,
                          // make tiles wider than tall so they occupy less vertical space
                          childAspectRatio: tileAspect,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          physics:
                              isMobile
                                  ? const AlwaysScrollableScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                          children: [
                            _GameTile(
                              title: 'Haunted House',
                              subtitle: 'Tap ghosts to survive',
                              asset: 'assets/img/category1-img.png',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        backgroundColor: Colors.black87,
                                        title: const Text(
                                          'How to play — Haunted House',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: const Text(
                                          'Tap appearing ghosts to banish them. Smaller ghosts are worth more — reach the target before time runs out to clear the level.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepOrange,
                                            ),
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              await AudioManager.instance
                                                  .stopBgm();
                                              await AudioManager.instance.playBgm(
                                                'assets/audio/haunted_bgm.mp3',
                                              );
                                              Navigator.of(
                                                context,
                                              ).pushNamed('/haunted');
                                            },
                                            child: const Text('Play'),
                                          ),
                                        ],
                                      ),
                                );
                              },
                            ),
                            _GameTile(
                              title: 'Pumpkin Pick',
                              subtitle: 'Collect pumpkins quickly',
                              asset: 'assets/img/home1-img.png',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        backgroundColor: Colors.black87,
                                        title: const Text(
                                          'How to play — Pumpkin Pick',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: const Text(
                                          'Tap pumpkins to collect points. Smaller pumpkins are worth more. Reach the target before time runs out to clear the level.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepOrange,
                                            ),
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              await AudioManager.instance
                                                  .stopBgm();
                                              await AudioManager.instance.playBgm(
                                                'assets/audio/pumpkin_bgm.mp3',
                                              );
                                              Navigator.of(
                                                context,
                                              ).pushNamed('/pumpkin');
                                            },
                                            child: const Text('Play'),
                                          ),
                                        ],
                                      ),
                                );
                              },
                            ),
                            _GameTile(
                              title: 'Memory Mansion',
                              subtitle: 'Match pairs quickly',
                              asset: 'assets/img/new5-img.png',
                              onTap: () {
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
                                          'Flip cards to reveal images and find matching pairs. Match all pairs before time runs out. Smaller cards award bonus points — try to finish quickly!',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepOrange,
                                            ),
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              await AudioManager.instance
                                                  .stopBgm();
                                              await AudioManager.instance.playBgm(
                                                'assets/audio/memory_bgm.mp3',
                                              );
                                              Navigator.of(
                                                context,
                                              ).pushNamed('/mission3');
                                            },
                                            child: const Text('Play'),
                                          ),
                                        ],
                                      ),
                                );
                              },
                            ),
                            _GameTile(
                              title: 'Candle Keepers',
                              subtitle: 'Relight the flame',
                              asset: 'assets/img/new2-img.png',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.black87,
                                    title: const Text(
                                      'How to play — Candle Keepers',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Candles slowly go out. Tap a candle to relight it and earn points. Use the "Relight All" power-up when available to quickly restore many candles. Reach the target score before time runs out to win.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepOrange,
                                        ),
                                        onPressed: () async {
                                          Navigator.of(ctx).pop();
                                          await AudioManager.instance.stopBgm();
                                          await AudioManager.instance.playBgm(
                                            'assets/audio/candle_bgm.mp3',
                                          );
                                          Navigator.of(context).pushNamed('/mission4');
                                        },
                                        child: const Text('Play'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            _GameTile(
                              title: 'Gallery',
                              subtitle: 'View screenshots',
                              asset: 'assets/img/nav-img.png',
                              onTap: () {
                                Navigator.of(context).pushNamed('/screenshots');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showEnableAudio)
            Positioned(
              left: 12,
              right: 12,
              bottom: 18,
              child: GestureDetector(
                onTap: () async {
                  // user gesture fallback to enable audio
                  await AudioManager.instance.ensureStartedFromUserGesture(
                    mainBgm: 'assets/audio/main_screen.mp3',
                  );
                  await AudioManager.instance.playBgm(
                    'assets/audio/main_screen.mp3',
                  );
                  setState(
                    () =>
                        _showEnableAudio = !AudioManager.instance.isBgmPlaying,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.volume_up, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Enable audio',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// subtle colored glow

class _SoundSettingsDialog extends StatefulWidget {
  @override
  State<_SoundSettingsDialog> createState() => _SoundSettingsDialogState();
}

class _SoundSettingsDialogState extends State<_SoundSettingsDialog> {
  bool _soundOn = true;
  double _volume = 0.6;
  double _prevVolume = 0.6;

  @override
  void initState() {
    super.initState();
    // consider sound on when bgm volume is > 0
    _soundOn = AudioManager.instance.bgmVolume > 0.0;
    _volume = AudioManager.instance.bgmVolume;
  }

  void _setSoundOn(bool on) {
    setState(() {
      _soundOn = on;
      if (!_soundOn) {
        AudioManager.instance.pauseBgm();
        // store previous volume and mute
        _prevVolume = _volume > 0.0 ? _volume : _prevVolume;
        AudioManager.instance.setBgmVolume(0.0);
        AudioManager.instance.setSfxVolume(0.0);
        _volume = 0.0;
      } else {
        // restore previous volume
        final restore = _prevVolume > 0.0 ? _prevVolume : 0.6;
        AudioManager.instance.setBgmVolume(restore);
        AudioManager.instance.setSfxVolume(restore);
        AudioManager.instance.resumeBgm();
        _volume = restore;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      title: const Text('Settings', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sound', style: TextStyle(color: Colors.white70)),
              Switch(value: _soundOn, onChanged: (v) => _setSoundOn(v)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: _volume.clamp(0.0, 1.0),
                  onChanged: (v) async {
                    setState(() {
                      _volume = v;
                      _soundOn = v > 0.0;
                    });
                    // apply volumes immediately
                    await AudioManager.instance.setBgmVolume(v);
                    await AudioManager.instance.setSfxVolume(v);
                    if (v == 0.0) {
                      await AudioManager.instance.pauseBgm();
                    } else {
                      await AudioManager.instance.resumeBgm();
                    }
                  },
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white70),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
