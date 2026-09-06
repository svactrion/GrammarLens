/// Externally-hosted legal page URLs referenced from the app.
///
/// The pages themselves currently carry placeholder content — the real
/// text is being written separately — but the URLs are permanent, so
/// they're filled in now rather than left empty. `scripts/preflight.sh`
/// still gates a release build on these being non-empty.
class AppLinks {
  static const String privacyPolicyUrl =
      'https://ahmettayfur.com/products/grammarlens/privacy/';
  static const String termsUrl =
      'https://ahmettayfur.com/products/grammarlens/terms/';
  static const String supportUrl =
      'https://ahmettayfur.com/products/grammarlens/support/';
}
