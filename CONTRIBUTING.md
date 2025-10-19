Contribution guide

Thanks for taking interest in contributing to spookey-web. A few quick guidelines to get your PR accepted faster:

- File issues for bugs or feature requests.
- For code changes, open a Pull Request against the `main` branch.
- Keep commits small and focused. Use descriptive commit messages.
- Run `flutter analyze` and `flutter test` locally before opening a PR.
- Add or update tests for new behavior where applicable.
- Don't commit secrets or API keys. Use environment variables or CI secrets.

How to run locally

1. Install Flutter (https://flutter.dev/docs/get-started/install).
2. From the project root run:

```powershell
flutter pub get
flutter analyze
flutter run -d chrome
```

If you plan to contribute significant new features, open an Issue first to discuss the design.
