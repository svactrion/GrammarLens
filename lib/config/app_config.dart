/// Single place for build-time configuration read via `--dart-define`
/// (or `--dart-define-from-file`, see `config/dev.example.json`).
///
/// Today this only wraps the Anthropic API key used for direct client
/// calls. When that call moves behind a backend proxy (planned, not yet
/// built — see docs/roadmap.md), only this file needs to change: callers
/// read `AppConfig`, never `String.fromEnvironment` directly.
class AppConfig {
  const AppConfig._();

  static const String anthropicApiKey =
      String.fromEnvironment('ANTHROPIC_API_KEY');

  static bool get isConfigured => anthropicApiKey.isNotEmpty;
}
