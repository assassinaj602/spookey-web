import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

/// Simple app-wide audio manager for background music and short SFX.
///
/// Usage:
///   await AudioManager.instance.playBgm('assets/audio/menu_bgm.mp3');
///   AudioManager.instance.playSfx('assets/audio/match.wav');
///
/// Notes:
/// - Uses audioplayers package which works on Web and Mobile.
/// - For web you should use small compressed files (mp3/ogg) and keep SFX short.
class AudioManager {
  AudioManager._internal();
  static final AudioManager instance = AudioManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'bgm');

  String? _currentBgm;
  double bgmVolume = 0.6;
  double sfxVolume = 1.0;
  // small pool of low-latency players for SFX to reduce playback delay
  final List<AudioPlayer> _sfxPlayers = [];
  int _sfxIndex = 0;

  void _ensureSfxPool() {
    if (_sfxPlayers.isNotEmpty) return;
    for (var i = 0; i < 4; i++) {
      final p = AudioPlayer(playerId: 'sfx_$i');
      _sfxPlayers.add(p);
    }
  }

  // simple in-memory buffer cache for assets to reduce latency and platform differences
  final Map<String, Uint8List> _buffers = {};

  /// Ensure core assets are loaded and start main BGM after a user gesture.
  /// Call this from the first real user gesture (tap) to satisfy browser autoplay rules.
  Future<void> ensureStartedFromUserGesture({
    String mainBgm = 'assets/audio/main_screen.mp3',
    List<String>? preloadSfx,
  }) async {
    try {
      // preload main bgm
      if (!_buffers.containsKey(mainBgm)) {
        final data = await rootBundle.load(mainBgm);
        _buffers[mainBgm] = data.buffer.asUint8List();
      }
      // preload provided sfx list
      if (preloadSfx != null) {
        for (var s in preloadSfx) {
          if (!_buffers.containsKey(s)) {
            try {
              final data = await rootBundle.load(s);
              _buffers[s] = data.buffer.asUint8List();
            } catch (_) {}
          }
        }
      }
      // start main bgm (looped)
      await playBgm(mainBgm, useBuffer: true);
    } catch (_) {}
  }

  /// Play background music (looped). Path should be an asset path, e.g. 'assets/audio/haunted_bgm.mp3'
  Future<void> playBgm(String assetPath, {bool useBuffer = false}) async {
    try {
      if (_currentBgm == assetPath) return;
      _currentBgm = assetPath;
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmVolume);
      try {
        if (_buffers.containsKey(assetPath)) {
          await _bgmPlayer.play(BytesSource(_buffers[assetPath]!));
          return;
        }
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        _buffers[assetPath] = bytes;
        await _bgmPlayer.play(BytesSource(bytes));
        return;
      } catch (_) {
        // if bytes playback fails, fall back to AssetSource (mobile-friendly) then UrlSource
      }

      try {
        final assetRelative =
            assetPath.startsWith('assets/')
                ? assetPath.substring('assets/'.length)
                : assetPath;
        await _bgmPlayer.play(AssetSource(assetRelative));
        return;
      } catch (_) {}

      try {
        await _bgmPlayer.play(UrlSource(assetPath));
        return;
      } catch (_) {}
    } catch (e) {
      // ignore audio errors for now
    }
  }

  /// Stop background music
  Future<void> stopBgm() async {
    _currentBgm = null;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  /// Set BGM volume immediately (applies to any currently playing BGM)
  Future<void> setBgmVolume(double v) async {
    bgmVolume = v.clamp(0.0, 1.0);
    try {
      await _bgmPlayer.setVolume(bgmVolume);
    } catch (_) {}
  }

  /// Pause background music
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  /// Resume background music
  Future<void> resumeBgm() async {
    try {
      await _bgmPlayer.resume();
      // ensure volume is applied when resuming
      await _bgmPlayer.setVolume(bgmVolume);
    } catch (_) {}
  }

  /// Whether the BGM player is currently playing
  bool get isBgmPlaying {
    try {
      return _bgmPlayer.state == PlayerState.playing;
    } catch (_) {
      return false;
    }
  }

  /// Play a short sound effect once. Input is an asset path like 'assets/audio/match.wav'
  Future<void> playSfx(String assetPath) async {
    try {
      _ensureSfxPool();
      final player = _sfxPlayers[_sfxIndex % _sfxPlayers.length];
      _sfxIndex = (_sfxIndex + 1) % _sfxPlayers.length;
      try {
        await player.setVolume(sfxVolume);
        // Try AssetSource first (Android-friendly)
        try {
          final rel =
              assetPath.startsWith('assets/')
                  ? assetPath.substring('assets/'.length)
                  : assetPath;
          await player.play(AssetSource(rel));
          return;
        } catch (_) {}

        if (_buffers.containsKey(assetPath)) {
          await player.play(BytesSource(_buffers[assetPath]!));
        } else {
          try {
            final data = await rootBundle.load(assetPath);
            final bytes = data.buffer.asUint8List();
            _buffers[assetPath] = bytes;
            await player.play(BytesSource(bytes));
          } catch (_) {
            await player.play(UrlSource(assetPath));
          }
        }
      } catch (_) {
        // fallback: create a transient player
        final fresh = AudioPlayer();
        await fresh.setVolume(sfxVolume);
        try {
          // try AssetSource first
          try {
            final rel =
                assetPath.startsWith('assets/')
                    ? assetPath.substring('assets/'.length)
                    : assetPath;
            await fresh.play(AssetSource(rel));
            fresh.onPlayerComplete.listen((_) async {
              try {
                await fresh.dispose();
              } catch (_) {}
            });
            return;
          } catch (_) {}

          if (_buffers.containsKey(assetPath)) {
            await fresh.play(BytesSource(_buffers[assetPath]!));
          } else {
            final data = await rootBundle.load(assetPath);
            final bytes = data.buffer.asUint8List();
            _buffers[assetPath] = bytes;
            await fresh.play(BytesSource(bytes));
          }
        } catch (_) {
          await fresh.play(UrlSource(assetPath));
        }
        fresh.onPlayerComplete.listen((_) async {
          try {
            await fresh.dispose();
          } catch (_) {}
        });
      }
    } catch (e) {
      // ignore audio errors for now
    }
  }

  /// Set SFX volume immediately (applies to pooled players)
  Future<void> setSfxVolume(double v) async {
    sfxVolume = v.clamp(0.0, 1.0);
    try {
      _ensureSfxPool();
      for (var p in _sfxPlayers) {
        try {
          await p.setVolume(sfxVolume);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
