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

  /// Third-party pages named in the Credits screen's avatar attribution.
  static const String avatarSetUrl =
      'https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons';
  static const String ccBy4Url = 'https://creativecommons.org/licenses/by/4.0/';
}
