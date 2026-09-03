import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../utils/page_title.dart';

enum _PurchaseState { idle, purchasing, success, cancelled, error }

/// Topic Practice's trial-then-paid paywall (PRD v2 §12.2/§12.6). Reachable
/// from [PremiumScreen] as of this commit — **not yet** wired to actually
/// gate Topic Practice, or into the Day-0 onboarding flow (§12.3's "Daily
/// Test result -> paywall pitch" step). Both are a later batch; see
/// docs/roadmap.md.
///
/// Price and trial terms are read live from RevenueCat's current offering
/// ([SubscriptionService.getOfferings]), never hardcoded, so this screen
/// can't silently drift from whatever is actually configured in App Store
/// Connect. As of this commit no RevenueCat/App Store Connect product
/// exists yet, so that fetch always comes back empty — the "pricing
/// unavailable" state below, not a crash, is the expected result of
/// testing this screen today.
class PaywallScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  /// Called when the user is done here — either they dismissed via "Maybe
  /// later," or a trial just started and they tapped "Continue" — right
  /// before this screen pops itself. Null (the default, for every entry
  /// point except the Day-0 flow) means there's nothing extra to do beyond
  /// the pop itself: Home's locked-card tap and the Premium screen's CTA
  /// both just want to return to whatever pushed this screen.
  final VoidCallback? onDone;

  PaywallScreen({
    super.key,
    SubscriptionService? subscriptionService,
    this.onDone,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loadingOffer = true;
  Package? _package;
  _PurchaseState _purchaseState = _PurchaseState.idle;
  bool _restoring = false;
  String? _restoreMessage;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    final offering = await widget.subscriptionService.getOfferings();
    final packages = offering?.availablePackages ?? const <Package>[];
    if (!mounted) return;
    setState(() {
      _package =
          packages.isEmpty ? null : (offering!.monthly ?? packages.first);
      _loadingOffer = false;
    });
  }

  Future<void> _startTrial() async {
    final package = _package;
    if (package == null) return;
    setState(() {
      _purchaseState = _PurchaseState.purchasing;
      _restoreMessage = null;
    });
    final outcome = await widget.subscriptionService.purchasePackage(package);
    if (!mounted) return;
    setState(() {
      if (outcome == PurchaseOutcome.success) {
        _purchaseState = _PurchaseState.success;
      } else if (outcome == PurchaseOutcome.cancelled) {
        _purchaseState = _PurchaseState.cancelled;
      } else {
        _purchaseState = _PurchaseState.error;
      }
    });
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _restoreMessage = null;
    });
    final restored = await widget.subscriptionService.restorePurchases();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _restoreMessage = restored
          ? 'Purchases restored — full access is active.'
          : 'No previous purchases found to restore.';
    });
  }

  /// Shared by "Maybe later" and the post-success "Continue" button — both
  /// mean "I'm done with this screen." Runs [PaywallScreen.onDone] first
  /// (e.g. the Day-0 flow's own onboarding-completion step) so its side
  /// effects are in flight before this route disappears, then pops.
  void _dismiss() {
    widget.onDone?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final package = _package;

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Topic Practice')),
      // A single flowing list, not a scrollable-region-plus-pinned-footer
      // split: an earlier pass here tried pinning Restore Purchases/the
      // legal links to the true bottom of the screen via Expanded, which
      // actually made the "floating in isolation" problem *worse* — it
      // turned a short gap into a large, deliberate-looking void between
      // the error card and the actions below it. Keeping everything in one
      // Column means these elements stay tightly grouped right after
      // whatever pricing content precedes them, and any leftover space
      // simply trails at the very bottom of the screen — normal for a
      // short scrollable screen, not an isolated floating cluster.
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
        children: [
          _PitchCard(theme: theme, colorScheme: colorScheme),
          const SizedBox(height: 24),
          if (_loadingOffer)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (package == null)
            _UnavailableCard(
              theme: theme,
              colorScheme: colorScheme,
              onRetry: () {
                setState(() => _loadingOffer = true);
                _loadOffer();
              },
            )
          else ...[
            _TrialTermsCard(
              package: package,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            _PurchaseStatusBanner(
              state: _purchaseState,
              theme: theme,
              colorScheme: colorScheme,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Once the trial has actually started, this button's job
                // changes from "start it" to "acknowledge and move on" —
                // reusing the same primary button for that rather than
                // adding a separate one keeps a single, consistent
                // continuation point regardless of outcome.
                onPressed: switch (_purchaseState) {
                  _PurchaseState.purchasing => null,
                  _PurchaseState.success => _dismiss,
                  _ => _startTrial,
                },
                child: _purchaseState == _PurchaseState.purchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_purchaseState == _PurchaseState.success
                        ? 'Continue'
                        : 'Start free trial'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Required by App Store guidelines for any paywall, regardless
          // of whether pricing itself is currently available — always
          // present, never gated on [package].
          Center(
            child: TextButton(
              // Explicit color: an unstyled TextButton defaults to Material
              // 3's colorScheme.primary, which in light mode *is* the
              // page's own vivid-orange background (see theme.dart's
              // filledButtonTheme comment — the same clash it already
              // works around for FilledButton) — without this, the button
              // renders orange-on-orange and disappears in light mode.
              style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
              onPressed: _restoring ? null : _restore,
              child: Text(_restoring ? 'Restoring…' : 'Restore Purchases'),
            ),
          ),
          if (_restoreMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  _restoreMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _LegalLink(
                  label: 'Privacy Policy',
                  url: AppLinks.privacyPolicyUrl,
                ),
                _LegalLink(
                  label: 'Terms of Service',
                  url: AppLinks.termsUrl,
                ),
              ],
            ),
          ),
          // Low-emphasis skip, below everything else the App Store
          // requires — not shown once a trial has actually started (the
          // primary button already covers "I'm done" via "Continue" then,
          // so a second identical exit here would be redundant).
          if (_purchaseState != _PurchaseState.success) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: _dismiss,
                child: const Text('Maybe later'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small text link to a legal page, disabled (greyed out, non-
/// interactive) rather than shown as live and then failing silently or
/// erroring, whenever [url] is still the empty placeholder from
/// app_links.dart — see that file's pre-launch-blocker comment. Once a
/// real URL is set, this starts launching it; that launch itself isn't
/// implemented yet (no url_launcher dependency), since there's nothing
/// real to launch to until then.
class _LegalLink extends StatelessWidget {
  final String label;
  final String url;

  const _LegalLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Explicit color for the same reason Restore Purchases' button
      // needs one — see that TextButton's comment — even though this one
      // is disabled today; it stays correct once a real URL lands.
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
      ),
      // TODO: launch `url` (e.g. via url_launcher) once AppLinks has a
      // real value — see app_links.dart.
      onPressed: url.isEmpty ? null : () {},
      child: Text(label),
    );
  }
}

/// The core pitch (PRD v2 §12.1; docs/prd.md §2.1 Theme 2 and §2.2 Theme 7):
/// personalized, plain-language feedback on the user's own mistakes — not a
/// generic feature list — since that's the specific thing every one of the
/// three usability testers praised unprompted, and the thing a fixed-
/// answer-key Daily Test structurally can't do.
class _PitchCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PitchCard({required this.theme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.auto_awesome_rounded, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Personalized feedback, not a feature list',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Topic Practice generates fresh questions from your own '
              "recurring mistakes, then explains what's wrong in plain "
              "English — never grammar terminology. It's the part of "
              'GrammarLens people notice first.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when [SubscriptionService.getOfferings] comes back empty — no
/// RevenueCat/App Store Connect product connected (expected right now, see
/// this file's class doc comment) or a transient failure. Either way, a
/// clear non-crashing state rather than a blank or broken screen.
class _UnavailableCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onRetry;

  const _UnavailableCard({
    required this.theme,
    required this.colorScheme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Trial pricing isn't available right now",
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't reach the subscription service. Please check "
              'back soon.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// App Store Connect's required auto-renewable-subscription disclosure:
/// trial length, price + billing period after it, and that it auto-renews
/// unless cancelled — all three read live off [package], never hardcoded.
class _TrialTermsCard extends StatelessWidget {
  final Package package;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _TrialTermsCard({
    required this.package,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final trial = product.introductoryPrice;
    final trialText = trial != null
        ? '${_hyphenatedDuration(trial.periodNumberOfUnits, trial.periodUnit)} '
            'free trial'
        : 'Free trial';
    final billingPeriod = _formatSubscriptionPeriod(product.subscriptionPeriod);
    final priceLine = billingPeriod == null
        ? 'Then ${product.priceString}, billed automatically unless you '
            'cancel before the trial ends.'
        : 'Then ${product.priceString} / $billingPeriod, billed '
            'automatically unless you cancel before the trial ends.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trialText,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              priceLine,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Auto-renews until cancelled. Manage or cancel anytime in '
              'your App Store account settings.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline result of the last [SubscriptionService.purchasePackage] call —
/// nothing shown for [_PurchaseState.idle]/[_PurchaseState.purchasing],
/// since those already have their own affordance (the button itself).
class _PurchaseStatusBanner extends StatelessWidget {
  final _PurchaseState state;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PurchaseStatusBanner({
    required this.state,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String message;
    Color color;
    switch (state) {
      case _PurchaseState.success:
        icon = Icons.check_circle_rounded;
        message = 'Trial started — Topic Practice is unlocked.';
        color = colorScheme.primary;
        break;
      case _PurchaseState.cancelled:
        icon = Icons.info_outline_rounded;
        message = 'Purchase cancelled — no charge was made.';
        color = colorScheme.onSurfaceVariant;
        break;
      case _PurchaseState.error:
        icon = Icons.error_outline_rounded;
        message =
            "Something went wrong and the trial couldn't start. Please "
            'try again.';
        color = colorScheme.error;
        break;
      case _PurchaseState.idle:
      case _PurchaseState.purchasing:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _hyphenatedDuration(int count, PeriodUnit unit) {
  final singular = switch (unit) {
    PeriodUnit.day => 'day',
    PeriodUnit.week => 'week',
    PeriodUnit.month => 'month',
    PeriodUnit.year => 'year',
    PeriodUnit.unknown => 'period',
  };
  return '$count-$singular';
}

/// Parses RevenueCat's ISO-8601 subscription period ("P1M", "P3D", ...)
/// into a short billing-period word ("month", "3 days"), or null if absent
/// or unparseable — callers should omit the "/ period" suffix entirely
/// then, rather than showing a raw ISO string to the user.
String? _formatSubscriptionPeriod(String? iso) {
  if (iso == null) return null;
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso);
  if (match == null) return null;
  final count = int.parse(match.group(1)!);
  String? unit;
  switch (match.group(2)) {
    case 'D':
      unit = 'day';
      break;
    case 'W':
      unit = 'week';
      break;
    case 'M':
      unit = 'month';
      break;
    case 'Y':
      unit = 'year';
      break;
  }
  if (unit == null) return null;
  return count == 1 ? unit : '$count ${unit}s';
}
