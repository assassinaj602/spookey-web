Haunted Mini-Game — Spookey Web

What I added

- A new haunted mini-game page: `lib/haunted_game.dart`.
- Wired route `/haunted` in `lib/main.dart` and a button on the home page to enter the game.
- Gameplay: 20-second survival where you tap ghosts to gain points. Simple animated ghosts and a spooky background image.
 - Polished home screen with game tiles and thumbnails (uses assets in `assets/img/`).
 - Added a second mini-game: Pumpkin Pick (`lib/pumpkin_game.dart`) — collect pumpkins quickly for points.

Why this helps win

- It's beginner-friendly, polished, and fits the "Survive the Night" or "Cursed Code" tracks: interactive, spooky, and demoable in under 4 minutes.
- Web-friendly: no native plugins used, so it runs in Flutter Web.

How to run locally (Windows PowerShell)

1. Ensure Flutter is installed and web is enabled: `flutter channel stable; flutter upgrade; flutter config --enable-web`
2. From project root (where `pubspec.yaml` is):

```powershell
flutter pub get
flutter run -d chrome
```

Or to build a release web bundle:

```powershell
flutter build web
```

Notes

- The haunted game uses a network image for background so an internet connection is required.
 - The haunted game uses a network image for background so an internet connection is required. The rest of the UI uses bundled images from `assets/img/` (e.g., `home1-img.png`, `trick-treat1-img.png`, `trick-treat3-img.png`).
- It's intentionally simple so you can extend it: add sounds, animations, spawn waves, or a leaderboard.

Files changed

- `lib/main.dart` — updated home title, added route `/haunted` and button to enter.
- `lib/haunted_game.dart` — new game screen.

Next steps (optional)

- Add audio (background music + SFX) using `audioplayers` (web-compatible).
- Add persistent leaderboard (use Firebase or a simple REST endpoint).
- Improve art assets and add a short demo script for the 4-minute submission video.
