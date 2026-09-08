import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/practice_length.dart';
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
/// Layout order (the differentiator and the price, in as few beats as
/// possible — see the reordering batch's diagnosis in build-log.md/the
/// commit that introduced this ordering): headline, comparison table, plan
/// cards, the required trial/renewal disclosure, then the primary button.
/// The two long description cards that used to sit above all of this are
/// gone — the table already carries that differentiation, and duplicating
/// it in prose only delayed reaching the price.
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

  /// Shared by "Maybe later," the top-right close button, and the
  /// post-success "Continue" button — all three mean "I'm done with this
  /// screen." Runs [PremiumScreen.onDone] first (e.g. the Day-0 flow's own
  /// onboarding-completion step) so its side effects are in flight before
  /// this route disappears, then pops.
  void _dismiss() {
    widget.onDone?.call();
    Navigator.of(context).pop();
  }

  String get _headline {
    final source = widget.sourceContext;
    return source != null
        ? 'Unlock personalized feedback on "$source"'
        : 'Personalized feedback, not a feature list';
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
      appBar: AppBar(
        title: const PageTitle('Premium'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: _dismiss,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
        children: [
          Text(
            _headline,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel("What's free, trial, and paid"),
          const SizedBox(height: 8),
          _ComparisonTable(theme: theme, colorScheme: colorScheme),
          const SizedBox(height: 20),
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
            _PlanCards(
              monthly: monthly,
              annual: annual,
              selected: _selectedPeriod,
              onChanged: (period) => setState(() => _selectedPeriod = period),
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            Text(
              _disclosureText(_selectedPackage!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
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
          // [package]. Not one of the reordering batch's eight named
          // steps; kept here, right after the primary action, since
          // restoring is functionally an alternative path to the same
          // thing that button does.
          Center(
            child: TextButton(
              // No explicit style: theme.dart's textButtonTheme now covers
              // the orange-on-orange contrast fix this call site used to
              // patch individually.
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
          const SizedBox(height: 8),
          // Low-emphasis skip — not shown once a trial has actually
          // started (the primary button already covers "I'm done" via
          // "Continue" then, so a second identical exit here would be
          // redundant).
          if (_purchaseState != _PurchaseState.success)
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: _dismiss,
                child: const Text('Maybe later'),
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
        ],
      ),
    );
  }
}

/// The App Store's required auto-renewable-subscription disclosure,
/// compressed to a single sentence (at most two lines once wrapped):
/// trial length, price + billing period after it, and that it auto-renews
/// unless cancelled. Reuses [_hyphenatedDuration] and
/// [_formatSubscriptionPeriod] — the same parsing the old, three-line
/// _TrialTermsCard used — so every number here still comes from
/// [package]'s own live StoreKit/RevenueCat data, never hardcoded.
String _disclosureText(Package package) {
  final product = package.storeProduct;
  final trial = product.introductoryPrice;
  final trialPart = trial != null
      ? '${_hyphenatedDuration(trial.periodNumberOfUnits, trial.periodUnit)} '
          'free trial'
      : 'Free trial';
  final billingPeriod = _formatSubscriptionPeriod(product.subscriptionPeriod);
  final priceStr = billingPeriod == null
      ? product.priceString
      : '${product.priceString} / $billingPeriod';
  return '$trialPart, then $priceStr, auto-renews unless cancelled.';
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

/// One row of the Free/Premium comparison table. Text only, so the table
/// itself (see [_ComparisonTable]) can render every row from one list
/// instead of hand-laying-out each one — PRD v2 §13.4: exactly these five
/// features, nothing today's app doesn't actually have.
class _ComparisonRow {
  final String label;
  final bool free;
  final bool premium;

  const _ComparisonRow({
    required this.label,
    required this.free,
    required this.premium,
  });
}

/// Row 5's question counts, joined the way a sentence would ("3, 5 or 10"
/// — no Oxford comma) rather than a plain comma list, and read off
/// [PracticeLength] so this can't drift from what session lengths the app
/// actually offers.
String _joinWithOr(List<String> items) {
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} or ${items.last}';
}

final List<_ComparisonRow> _comparisonRows = [
  const _ComparisonRow(
    label: 'Daily Test, refreshed every day',
    free: true,
    premium: true,
  ),
  const _ComparisonRow(
    label: 'Topic Practice, all five topics',
    free: false,
    premium: true,
  ),
  const _ComparisonRow(
    label: 'Questions from your own mistakes',
    free: false,
    premium: true,
  ),
  const _ComparisonRow(
    label: 'Targeted weak-spot practice',
    free: false,
    premium: true,
  ),
  _ComparisonRow(
    label: 'Sessions of '
        '${_joinWithOr(PracticeLength.values.map((l) => '${l.questionCount}').toList())} '
        'questions',
    free: false,
    premium: true,
  ),
];

/// The Free/Premium comparison table (replaces the old two-tile benefit
/// list — docs/design-audit.md S3, both of its blue icon circles go with
/// it). Purely presentational: purchase logic, product/price sourcing, the
/// App Store disclosure block, and the restore flow are all elsewhere on
/// this screen, unchanged.
class _ComparisonTable extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ComparisonTable({required this.theme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    // Matches the 20px padding every other card on this screen uses —
    // not a new number.
    const contentPadding = EdgeInsets.symmetric(horizontal: 20);
    final rowDividerColor = colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: contentPadding,
            child: _ComparisonHeaderRow(colorScheme: colorScheme),
          ),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          for (var i = 0; i < _comparisonRows.length; i++) ...[
            Padding(
              padding: contentPadding,
              child: _ComparisonDataRow(
                row: _comparisonRows[i],
                theme: theme,
                colorScheme: colorScheme,
              ),
            ),
            if (i != _comparisonRows.length - 1)
              Divider(height: 1, thickness: 1, color: rowDividerColor),
          ],
        ],
      ),
    );
  }
}

class _ComparisonHeaderRow extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ComparisonHeaderRow({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      // 0.04em at a 12px size — CSS-style relative tracking rather than a
      // literal 0.04 logical pixel, which would be imperceptible.
      letterSpacing: 12 * 0.04,
    );
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          const Expanded(child: SizedBox.shrink()),
          SizedBox(
            width: 56,
            child: Center(
              // "PREMIUM" at 12px/w700/tracked doesn't quite fit 56px in
              // the system font — FittedBox keeps both header words on
              // one line at their specified size whenever there's room,
              // only scaling down the one that needs it, rather than
              // wrapping or clipping.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'FREE',
                  maxLines: 1,
                  style: style.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PREMIUM',
                  maxLines: 1,
                  style: style.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonDataRow extends StatelessWidget {
  final _ComparisonRow row;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ComparisonDataRow({
    required this.row,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                row.label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: _ComparisonCell(
                included: row.free,
                includedColor: colorScheme.onSurfaceVariant,
                dashColor: colorScheme.outline,
                tier: 'Free',
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: _ComparisonCell(
                included: row.premium,
                includedColor: colorScheme.secondary,
                dashColor: colorScheme.outline,
                tier: 'Premium',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One table cell: a checkmark or an em-dash, standing in for a boolean a
/// screen reader can't read visually. [Semantics.excludeSemantics] replaces
/// whatever VoiceOver/TalkBack would otherwise announce for the glyph
/// itself (a checkmark icon is normally silent; an em-dash would be read
/// literally) with an actual sentence — never two cells in a row both
/// announcing as an unqualified "checkmark."
class _ComparisonCell extends StatelessWidget {
  final bool included;
  final Color includedColor;
  final Color dashColor;
  final String tier;

  const _ComparisonCell({
    required this.included,
    required this.includedColor,
    required this.dashColor,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: included ? 'Included in $tier' : 'Not included in $tier',
      excludeSemantics: true,
      // Forces this into its own semantics node instead of merging its
      // label into whatever ancestor node it would otherwise combine
      // with (the row's label text, in this layout) — each cell needs to
      // be independently reachable by its own exact label.
      container: true,
      child: included
          ? Icon(Icons.check_rounded, size: 20, color: includedColor)
          : Text(
              '—',
              style: TextStyle(
                color: dashColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
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

/// Two side-by-side selectable plan cards (PRD v2 §13.3) — replaces the
/// old Annual/Monthly SegmentedButton. That component was this batch's H1
/// finding: the design called for two price cards, but the thing actually
/// in the tree was a segmented toggle with a single price line underneath
/// it, not two cards at all. Annual is preselected and carries the
/// "Save N%" badge; both cards' prices come from [_planPricing] — the
/// exact same helper the old segmented picker used, called once per
/// period — so nothing about where the numbers come from changes here.
class _PlanCards extends StatelessWidget {
  final Package monthly;
  final Package annual;
  final _PlanPeriod selected;
  final ValueChanged<_PlanPeriod> onChanged;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PlanCards({
    required this.monthly,
    required this.annual,
    required this.selected,
    required this.onChanged,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PlanCard(
            label: 'Annual',
            pricing: _planPricing(_PlanPeriod.annual, monthly, annual),
            selected: selected == _PlanPeriod.annual,
            onTap: () => onChanged(_PlanPeriod.annual),
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            label: 'Monthly',
            pricing: _planPricing(_PlanPeriod.monthly, monthly, annual),
            selected: selected == _PlanPeriod.monthly,
            onTap: () => onChanged(_PlanPeriod.monthly),
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final _PlanPricing pricing;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PlanCard({
    required this.label,
    required this.pricing,
    required this.selected,
    required this.onTap,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? colorScheme.secondary : colorScheme.outlineVariant;
    final bgColor =
        selected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow;
    final onBg = selected ? colorScheme.onSecondaryContainer : colorScheme.onSurface;
    final mutedOnBg = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final savings = pricing.savingsLabel;

    return Semantics(
      key: ValueKey('planCard_$label'),
      button: true,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label: '$label plan, ${pricing.bigAmount}, ${pricing.smallDetail}'
          '${savings != null ? ', $savings' : ''}',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (savings != null) ...[
                  _Badge(label: savings),
                  const SizedBox(height: 8),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: onBg),
                ),
                const SizedBox(height: 6),
                Text(
                  pricing.bigAmount,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: onBg),
                ),
                const SizedBox(height: 2),
                Text(
                  pricing.smallDetail,
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedOnBg),
                ),
              ],
            ),
          ),
        ),
      ),
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
/// clear non-crashing state rather than a blank or broken screen — this is
/// also a launch blocker, not just a nicety: App Review rejects a paywall
/// it opens that can't fetch products.
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
