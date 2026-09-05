/// Externally-hosted legal page URLs referenced from the app.
///
/// **Pre-launch blocker (see docs/roadmap.md, docs/prd-v2.md §10.1/§12.6):**
/// both URLs are empty — no Privacy Policy or Terms of Service page exists
/// yet (confirmed, not an oversight). PremiumScreen must not ship publicly
/// until both are filled in: the App Store requires a working Privacy
/// Policy link for any app that collects data, and a Terms link
/// specifically for auto-renewable subscriptions. `scripts/preflight.sh`
/// checks this before a release build.
class AppLinks {
  static const String privacyPolicyUrl = '';
  static const String termsUrl = '';
}
