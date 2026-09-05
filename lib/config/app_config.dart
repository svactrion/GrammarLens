/// Single place for build-time configuration read via `--dart-define`
/// (or `--dart-define-from-file`, see `config/dev.example.json`).
///
/// The Anthropic API key itself is not here, and never in the client at
/// all (see docs/build-log.md for the Cloudflare Workers proxy decision)
/// — `ClaudeService` talks to that proxy instead, and these are the only
/// two values it needs to do that: where the proxy is, and the app token
/// that identifies this as a real GrammarLens build (not proof against
/// extraction, just filters casual scanning — see the proxy's own
/// `src/auth.ts`).
class AppConfig {
  const AppConfig._();

  static const String proxyBaseUrl = String.fromEnvironment('PROXY_BASE_URL');
  static const String appToken = String.fromEnvironment('APP_TOKEN');

  static bool get isConfigured => proxyBaseUrl.isNotEmpty && appToken.isNotEmpty;
}
