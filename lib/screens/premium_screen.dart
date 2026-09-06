import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../utils/app_messenger.dart';
import '../utils/page_title.dart';

enum _PurchaseState { idle, purchasing, success, cancelled, error }

enum _PlanPeriod { monthly, annual }

/// The single Premium screen (PRD v2 §13.1): explains what's free/trial/paid
/// and sells the subscription in one place. Replaces two screens that used
/// to tell a different, incomplete story depending on which one a user
/// reached — an informational "Early Access" screen (the free/trial/paid
/// table, no purchase flow) and a separate Paywall (the purchase flow, no
/// context for what it was selling). "Early Access" never described a real
/// time-limited campaign and is retired along with the split.
///
/// Price and trial terms are read live from RevenueCat's current offering
/// ([SubscriptionService.getOfferings]), never hardcoded, so this screen
/// can't silently drift from whatever is actually configured in App Store
/// Connect. As of this commit no RevenueCat/App Store Connect product
/// exists yet, so that fetch always comes back empty — the "pricing
/// unavailable" state below, not a crash, is the expected result of
/// testing this screen today.
class PremiumScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  /// Called when the user is done here — either they dismissed via "Maybe
  /// later," or a trial just started and they tapped "Continue" — right
  /// before this screen pops itself. Null (the default, for every entry
  /// point except the Day-0 flow) means there's nothing extra to do beyond
  /// the pop itself: Home's locked-card tap and its own Premium-row tap
  /// both just want to return to whatever pushed this screen.
  final VoidCallback? onDone;

  /// Optional label for whatever prompted this screen — e.g. a specific
  /// weak spot's name, so a future caller can open this screen already
  /// naming what it's for ("Unlock personalized feedback on definite
  /// articles") instead of a screen-agnostic pitch (PRD v2 §13.5's planned
  /// weak-spot tap-through). Null for every caller today — mechanism only
  /// in this batch, nothing passes a value yet.
  final String? sourceContext;

  PremiumScreen({
    super.key,
    SubscriptionService? subscriptionService,
    this.onDone,
    this.sourceContext,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loadingOffer = true;
  Package? _monthlyPackage;
  Package? _annualPackage;
  // Annual preselected (PRD v2 §13.3) — it's the plan the "Save X%" badge
  // and the big/small price split are built to promote.
  _PlanPeriod _selectedPeriod = _PlanPeriod.annual;
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
    if (!mounted) return;
    setState(() {
      _monthlyPackage = offering?.monthly;
      _annualPackage = offering?.annual;
      _loadingOffer = false;
    });
  }

  /// Both plans need to exist for the picker below to mean anything — a
  /// one-sided offering (only monthly, or only annual configured) is
  /// treated the same as no offering at all, the honest "unavailable"
  /// state rather than a picker with one dead option.
  bool get _offeringsAvailable =>
      _monthlyPackage != null && _annualPackage != null;

  Package? get _selectedPackage => switch (_selectedPeriod) {
        _PlanPeriod.monthly => _monthlyPackage,
        _PlanPeriod.annual => _annualPackage,
      };

  Future<void> _startTrial() async {
    final package = _selectedPackage;
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
  /// mean "I'm done with this screen." Runs [PremiumScreen.onDone] first
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
    final monthly = _monthlyPackage;
    final annual = _annualPackage;

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Premium')),
      // A single flowing list, not a scrollable-region-plus-pinned-footer
      // split: an earlier pass on the old Paywall screen tried pinning
      // Restore Purchases/the legal links to the true bottom via Expanded,
      // which actually made the "floating in isolation" problem worse — it
      // turned a short gap into a large, deliberate-looking void. Keeping
      // everything in one Column means these elements stay tightly grouped
      // right after whatever precedes them either way.
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
        children: [
          _HeaderCard(theme: theme, colorScheme: colorScheme),
          const SizedBox(height: 16),
          _PitchCard(
            theme: theme,
            colorScheme: colorScheme,
            sourceContext: widget.sourceContext,
          ),
          const SizedBox(height: 28),
          const _SectionLabel("What's free, trial, and paid"),
          const SizedBox(height: 8),
          const _FeatureTile(
            icon: Icons.today_rounded,
            title: 'Daily Test',
            description:
                'A quick 5-question warm-up, refreshed every day — free, '
                'no trial or account needed.',
            status: 'Free',
          ),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description:
                'Personalized questions and plain-language feedback on '
                'your own recurring mistakes.',
            status: '${SubscriptionService.trialLengthDays}-day trial',
          ),
          const SizedBox(height: 16),
          Text(
            'Topic Practice generates a real AI call for every session, so '
            "it can't stay free at scale the way Daily Test's single "
            'shared, once-a-day generation can. The trial is there so you '
            'can try the personalized feedback before deciding.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Subscribe'),
          const SizedBox(height: 8),
          if (_loadingOffer)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_offeringsAvailable || monthly == null || annual == null)
            _UnavailableCard(
              theme: theme,
              colorScheme: colorScheme,
              onRetry: () {
                setState(() => _loadingOffer = true);
                _loadOffer();
              },
            )
          else ...[
            _PlanPicker(
              monthly: monthly,
              annual: annual,
              selected: _selectedPeriod,
              onChanged: (period) => setState(() => _selectedPeriod = period),
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            _TrialTermsCard(
              package: _selectedPackage!,
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
          // Required by App Store guidelines for any screen that sells a
          // subscription, regardless of whether pricing itself is
          // currently available — always present, never gated on
          // [package].
          Center(
            child: TextButton(
              // Explicit color: an unstyled TextButton defaults to Material
              // 3's colorScheme.primary, which in light mode *is* the
              // page's own vivid-orange background (see theme.dart's
              // filledButtonTheme comment — the same clash it already
              // works around for FilledButton) — without this, the button
              // renders orange-on-orange and disappears in light mode.
              style:
                  TextButton.styleFrom(foregroundColor: colorScheme.secondary),
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

/// The framing header (was the old Early Access screen's own top card):
/// states plainly that Daily Test is free forever and Topic Practice is a
/// trial. Deliberately never says "free forever"/unqualified "free" for
/// Topic Practice itself — that stopped being true once it moved to
/// trial-then-paid (PRD v2 §12.2/§6).
class _HeaderCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _HeaderCard({required this.theme, required this.colorScheme});

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
              child: const Icon(Icons.workspace_premium_rounded, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              "You're one of our first users — Daily Test is free, "
              'always, and Topic Practice starts with a free trial.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No credit card surprises — trial length, price, and '
              'billing terms are always shown clearly before you '
              'start anything.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The core sales pitch (was the old Paywall screen's own top card; PRD v2
/// §12.1, docs/prd.md §2.1 Theme 2 and §2.2 Theme 7): personalized,
/// plain-language feedback on the user's own mistakes — not a generic
/// feature list — since that's the specific thing every one of the three
/// usability testers praised unprompted, and the thing a fixed-answer-key
/// Daily Test structurally can't do. Swaps to a weak-spot-specific
/// headline when [sourceContext] is given (see [PremiumScreen.sourceContext]).
class _PitchCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? sourceContext;

  const _PitchCard({
    required this.theme,
    required this.colorScheme,
    this.sourceContext,
  });

  @override
  Widget build(BuildContext context) {
    final source = sourceContext;
    final headline = source != null
        ? 'Unlock personalized feedback on "$source"'
        : 'Personalized feedback, not a feature list';
    final body = source != null
        ? 'Topic Practice generates fresh questions targeting "$source" '
            "specifically, then explains what's wrong in plain English — "
            'never grammar terminology.'
        : 'Topic Practice generates fresh questions from your own '
            "recurring mistakes, then explains what's wrong in plain "
            "English — never grammar terminology. It's the part of "
            'GrammarLens people notice first.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: const Icon(Icons.auto_awesome_rounded, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? status;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(width: 8),
                        _Badge(label: status!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Monthly/annual toggle (PRD v2 §13.3), annual preselected, plus the
/// price line and "Save X%" badge for whichever is currently selected.
/// Every number here comes from the two real [Package.storeProduct]s —
/// nothing is computed from a hardcoded price or divided by a hardcoded
/// 12; see [_planPricing].
class _PlanPicker extends StatelessWidget {
  final Package monthly;
  final Package annual;
  final _PlanPeriod selected;
  final ValueChanged<_PlanPeriod> onChanged;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PlanPicker({
    required this.monthly,
    required this.annual,
    required this.selected,
    required this.onChanged,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final pricing = _planPricing(selected, monthly, annual);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_PlanPeriod>(
          segments: const [
            ButtonSegment(
              value: _PlanPeriod.monthly,
              label: Text('Monthly'),
            ),
            ButtonSegment(
              value: _PlanPeriod.annual,
              label: Text('Annual'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pricing.bigAmount,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    pricing.smallDetail,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (pricing.savingsLabel != null)
              _Badge(label: pricing.savingsLabel!),
          ],
        ),
      ],
    );
  }
}

/// The two numbers shown per plan: a large "big" figure (the annual
/// plan's own per-month equivalent when annual is selected, or the
/// monthly product's own price when monthly is selected) and a smaller
/// detail line underneath (the annual total, or "billed monthly").
class _PlanPricing {
  final String bigAmount;
  final String smallDetail;
  final String? savingsLabel;

  const _PlanPricing({
    required this.bigAmount,
    required this.smallDetail,
    this.savingsLabel,
  });
}

/// Computes [_PlanPricing] entirely from the two real products' own
/// fields — never a hardcoded number, never a manual divide-by-12.
///
/// The annual plan's monthly-equivalent price ([StoreProduct.pricePerMonth]/
/// [StoreProduct.pricePerMonthString]) is computed and formatted by
/// RevenueCat/StoreKit itself from the real annual price, already in the
/// viewer's own currency — this reads that directly rather than
/// reimplementing currency formatting by hand (which risks assuming a
/// "$" prefix that breaks for every other currency). The savings
/// percentage compares that same real monthly-equivalent against the
/// real standalone monthly product's price — both plain numbers already
/// in the same currency, so no manual currency handling is needed there
/// either.
///
/// Falls back to the plain annual price (no "per month" figure, no
/// savings badge) if the SDK doesn't supply a monthly-equivalent for some
/// reason, rather than inventing one.
_PlanPricing _planPricing(
  _PlanPeriod period,
  Package monthlyPackage,
  Package annualPackage,
) {
  final monthlyProduct = monthlyPackage.storeProduct;
  final annualProduct = annualPackage.storeProduct;

  if (period == _PlanPeriod.monthly) {
    return _PlanPricing(
      bigAmount: '${monthlyProduct.priceString} / month',
      smallDetail: 'Billed monthly.',
    );
  }

  final perMonth = annualProduct.pricePerMonth;
  final perMonthString = annualProduct.pricePerMonthString;
  if (perMonth == null || perMonthString == null) {
    return _PlanPricing(
      bigAmount: annualProduct.priceString,
      smallDetail: 'Billed annually.',
    );
  }

  String? savingsLabel;
  if (monthlyProduct.price > 0) {
    final savings =
        (monthlyProduct.price - perMonth) / monthlyProduct.price * 100;
    if (savings > 0) savingsLabel = 'Save ${savings.round()}%';
  }

  return _PlanPricing(
    bigAmount: '$perMonthString / month',
    smallDetail: 'Billed ${annualProduct.priceString} annually.',
    savingsLabel: savingsLabel,
  );
}

/// A small text link to a legal page, disabled (greyed out, non-
/// interactive) rather than shown as live and then failing silently or
/// erroring, whenever [url] is still the empty placeholder from
/// app_links.dart — see that file's doc comment. Once a real URL is set
/// (as of the custom-domain batch, both are), tapping opens it in the
/// system browser via `url_launcher`.
class _LegalLink extends StatelessWidget {
  final String label;
  final String url;

  const _LegalLink({required this.label, required this.url});

  Future<void> _open() async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppMessenger.show('Could not open $label.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Explicit color for the same reason Restore Purchases' button
      // needs one — see that TextButton's comment — even though this one
      // is disabled today; it stays correct once a real URL lands.
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
      ),
      onPressed: url.isEmpty ? null : _open,
      child: Text(label),
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
        message = "Something went wrong and the trial couldn't start. Please "
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
