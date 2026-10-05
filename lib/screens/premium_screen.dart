import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/practice_length.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/legal_link.dart';
import '../utils/content_width.dart';
import '../theme.dart';

enum _PurchaseState { idle, purchasing, success, cancelled, error, pending }

enum _PlanPeriod { monthly, annual }

/// The single Premium screen (PRD v2 §13.1), the 1.2.0 paywall (the
/// additional screens package): the user's companion between two others,
/// "Turn your mistakes into progress.", three benefits in one card, the
/// Free/Premium comparison behind "Compare Free & Premium", the two plans
/// stacked as radio cards, and a fixed footer with the purchase button, the
/// renewal terms, Restore Purchases, Terms, Privacy and "Maybe later".
///
/// **Prices and trials come only from the store.** Every price, currency,
/// period and introductory offer is read from RevenueCat's current offering
/// ([SubscriptionService.getOfferings]), never hardcoded. A trial is only
/// promised when the selected product has an introductory offer **and**
/// RevenueCat says this user is eligible for it
/// ([SubscriptionService.checkTrialEligibility]); otherwise the button and
/// the terms state the price and period, and when eligibility is unknown
/// they promise no trial (1.2.0 fix: until then a user who had already used
/// a trial was still promised one). The button, the plan cards and the
/// terms always describe the same selected plan.
///
/// Redeem codes are deferred (owner, 2026-10-05): no "Have a code?" here,
/// and never a code check of the app's own (App Review 3.1.1).
class PremiumScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  /// For the hero group's centre avatar, the user's own: none of the call
  /// sites holds a `UserProfile`, and every one already has a
  /// `StorageService`.
  final StorageService storageService;

  final AnalyticsService analyticsService;

  /// Which of `AnalyticsService`'s `paywallSource*` constants this visit
  /// came from — required: every call site is a known entry point.
  final String analyticsSource;

  /// Called when the user is done here — "Maybe later", the close button,
  /// or "Continue" after a purchase — right before this screen pops itself.
  /// Null at every call site today: they only want the pop.
  final VoidCallback? onDone;

  /// The weak spot that prompted this screen. It replaces the supporting
  /// line, keeping the headline identical across entry points.
  final String? sourceContext;

  PremiumScreen({
    super.key,
    required this.storageService,
    required this.analyticsService,
    required this.analyticsSource,
    SubscriptionService? subscriptionService,
    this.onDone,
    this.sourceContext,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  /// The headline, the same from every entry point.
  static const String headline = 'Turn your mistakes into progress.';

  static const compareToggleKey = ValueKey('premium_compare_toggle');
  static const ctaKey = ValueKey('premium_cta');
  static const restoreKey = ValueKey('premium_restore');
  static const heroKey = ValueKey('premium_hero');

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loadingOffer = true;
  Package? _monthlyPackage;
  Package? _annualPackage;

  /// Trial eligibility by product id; empty until checked, which counts as
  /// unknown (no trial promised).
  Map<String, TrialEligibility> _eligibility = const {};

  // Annual preselected (PRD v2 §13.3).
  _PlanPeriod _selectedPeriod = _PlanPeriod.annual;
  _PurchaseState _purchaseState = _PurchaseState.idle;

  /// Whether the last purchase started a trial (the success message says
  /// so only then).
  bool _purchasedTrial = false;
  bool _restoring = false;
  String? _restoreMessage;
  bool _compareOpen = false;

  // Picked once per visit: a legacy profile with no avatar (or an unknown
  // id) still shows a real companion, the same one on every rebuild.
  late final Avatar _fallbackAvatar = Avatar.random();
  late Avatar _userAvatar = _fallbackAvatar;

  // Set by _dismiss() before it pops, so the PopScope observer can tell a
  // button's exit from a system back gesture.
  bool _exitHandled = false;

  @override
  void initState() {
    super.initState();
    widget.analyticsService.paywallViewed(widget.analyticsSource);
    _loadOffer();
    _loadAvatar();
  }

  Future<void> _loadOffer() async {
    final offering = await widget.subscriptionService.getOfferings();
    final ids = [
      if (offering?.monthly != null) offering!.monthly!.storeProduct.identifier,
      if (offering?.annual != null) offering!.annual!.storeProduct.identifier,
    ];
    final eligibility = ids.isEmpty
        ? const <String, TrialEligibility>{}
        : await widget.subscriptionService.checkTrialEligibility(ids);
    if (!mounted) return;
    setState(() {
      _monthlyPackage = offering?.monthly;
      _annualPackage = offering?.annual;
      _eligibility = eligibility;
      _loadingOffer = false;
    });
  }

  Future<void> _loadAvatar() async {
    UserProfile? profile;
    try {
      profile = await widget.storageService.getUserProfile();
    } catch (_) {
      // Decorative: falls back to the random companion above.
    }
    if (!mounted) return;
    setState(() => _userAvatar = profile?.avatar ?? _fallbackAvatar);
  }

  /// Both plans must exist for the picker to mean anything; one alone is
  /// treated as no offering at all.
  bool get _offeringsAvailable =>
      _monthlyPackage != null && _annualPackage != null;

  Package? get _selectedPackage => switch (_selectedPeriod) {
        _PlanPeriod.monthly => _monthlyPackage,
        _PlanPeriod.annual => _annualPackage,
      };

  String get _selectedPlanAnalyticsId => switch (_selectedPeriod) {
        _PlanPeriod.monthly => AnalyticsService.planMonthly,
        _PlanPeriod.annual => AnalyticsService.planAnnual,
      };

  _PlanTerms _termsFor(Package package, String label) => _PlanTerms.of(
        package,
        label: label,
        eligibility: _eligibility[package.storeProduct.identifier] ??
            TrialEligibility.unknown,
      );

  Future<void> _startPurchase() async {
    // One request at a time: a second tap before the first one's frame
    // disables the button must not open a second purchase.
    if (_purchaseState == _PurchaseState.purchasing) return;
    final package = _selectedPackage;
    if (package == null) return;
    final terms = _termsFor(package, '');
    final plan = _selectedPlanAnalyticsId;
    widget.analyticsService.purchaseStarted(plan);
    setState(() {
      _purchaseState = _PurchaseState.purchasing;
      _restoreMessage = null;
    });
    final outcome = await widget.subscriptionService.purchasePackage(package);
    if (!mounted) return;
    setState(() {
      _purchasedTrial = terms.hasTrial;
      _purchaseState = switch (outcome) {
        PurchaseOutcome.success => _PurchaseState.success,
        PurchaseOutcome.cancelled => _PurchaseState.cancelled,
        PurchaseOutcome.pending => _PurchaseState.pending,
        PurchaseOutcome.failure => _PurchaseState.error,
      };
    });
    // A pending purchase (Ask to Buy) is its own outcome (O10). Its later
    // approval arrives as an entitlement change and logs no second
    // purchase_result, so one attempt is counted once.
    final outcomeId = switch (outcome) {
      PurchaseOutcome.success => 'success',
      PurchaseOutcome.cancelled => 'cancelled',
      PurchaseOutcome.failure => 'error',
      PurchaseOutcome.pending => 'pending',
    };
    widget.analyticsService.purchaseResult(plan: plan, outcome: outcomeId);
  }

  Future<void> _restore() async {
    if (_restoring) return;
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

  /// "Maybe later", the close button and the post-purchase "Continue": the
  /// first two log `paywall_dismissed` with their method, "Continue" does
  /// not (a purchase is not an abandonment). Runs [PremiumScreen.onDone],
  /// then pops.
  void _dismiss({String? dismissMethod}) {
    _exitHandled = true;
    if (dismissMethod != null) {
      widget.analyticsService.paywallDismissed(
        source: widget.analyticsSource,
        method: dismissMethod,
      );
    }
    widget.onDone?.call();
    Navigator.of(context).pop();
  }

  String get _supportingText {
    final source = widget.sourceContext?.trim();
    return source == null || source.isEmpty
        ? 'Focused practice. Personal feedback. A little more confidence, '
            'every day.'
        : 'Practice $source.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthly = _monthlyPackage;
    final annual = _annualPackage;
    final offeringsReady =
        _offeringsAvailable && monthly != null && annual != null;
    final size = MediaQuery.sizeOf(context);
    final shortScreen = size.height < _shortScreenHeight;
    // The legal links belong in the fixed footer, but the footer grows with
    // text size; past height / text scale 400 they go back to the end of the
    // scrolling body, so the footer never takes over the screen.
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final linksInFooter = size.height / textScale >= _minHeightPerTextScale;
    // The mockup's page edge: 20, 15 under 360 pt (held to the iPad column).
    final hPad =
        ContentWidth.sidePaddingOf(context, base: size.width < 360 ? 15 : 20);
    final selectedTerms = offeringsReady
        ? _termsFor(_selectedPackage!,
            _selectedPeriod == _PlanPeriod.annual ? 'Annual' : 'Monthly')
        : null;

    return PopScope(
      // Observes rather than blocks: a pop that did not go through
      // _dismiss() is a system back gesture.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop || _exitHandled) return;
        widget.analyticsService.paywallDismissed(
          source: widget.analyticsSource,
          method: AnalyticsService.paywallDismissSystemBack,
        );
      },
      child: BrandScaffold(
        // The status bar only: the brand line and Close are in the page.
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
        ),
        body: Column(
          children: [
            _TopBar(
              horizontalPadding: ContentWidth.sidePaddingOf(context, base: 17),
              onClose: () => _dismiss(
                dismissMethod: AnalyticsService.paywallDismissCloseButton,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
                child: Column(
                  key: const Key('premiumBody'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Decorative, and 133 pt a short screen (an iPhone SE)
                    // cannot spare: dropped under 700 pt tall.
                    if (!shortScreen) ...[
                      _AvatarHero(centerAvatar: _userAvatar),
                      const SizedBox(height: 9),
                    ],
                    const Center(child: _PremiumLabel()),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        PremiumScreen.headline,
                        textAlign: TextAlign.center,
                        style: _headlineStyle(theme, size.width),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SupportingLine(text: _supportingText),
                    const SizedBox(height: 21),
                    const _BenefitsCard(),
                    const SizedBox(height: 4),
                    _CompareToggle(
                      open: _compareOpen,
                      onTap: () => setState(() => _compareOpen = !_compareOpen),
                    ),
                    if (_compareOpen) ...[
                      _ComparisonTable(theme: theme, colorScheme: colorScheme),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 13),
                    Semantics(
                      header: true,
                      child: Text(
                        'Choose your plan',
                        style: theme.textTheme.titleSmall
                            ?.withWeight(FontWeight.w900)
                            .copyWith(color: colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingOffer)
                      _PlanCardsSkeleton(colorScheme: colorScheme)
                    else if (!offeringsReady)
                      _UnavailableCard(
                        theme: theme,
                        colorScheme: colorScheme,
                        onRetry: () {
                          setState(() => _loadingOffer = true);
                          _loadOffer();
                        },
                      )
                    else
                      _PlanCards(
                        annual: _termsFor(annual, 'Annual'),
                        monthly: _termsFor(monthly, 'Monthly'),
                        savingsLabel: _savingsLabel(monthly, annual),
                        selected: _selectedPeriod,
                        onChanged: (period) =>
                            setState(() => _selectedPeriod = period),
                      ),
                    if (!linksInFooter) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: _FooterLinks(
                          restoring: _restoring,
                          onRestore: _restore,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _PremiumFooter(
              key: const Key('premiumFooter'),
              loading: _loadingOffer,
              offeringsReady: offeringsReady,
              purchaseState: _purchaseState,
              purchasedTrial: _purchasedTrial,
              restoreMessage: _restoreMessage,
              terms: selectedTerms,
              showLinks: linksInFooter,
              restoring: _restoring,
              onRestore: _restore,
              onPurchase: _startPurchase,
              onContinue: _dismiss,
              onMaybeLater: () => _dismiss(
                dismissMethod: AnalyticsService.paywallDismissMaybeLater,
              ),
              horizontalPadding: hPad,
              maxHeight: (size.height - MediaQuery.paddingOf(context).top) * .5,
            ),
          ],
        ),
      ),
    );
  }
}

/// The line under the headline, at least two lines tall: the default
/// line and a weak spot's one-line "Practice …." take the same room, so every
/// entry point lays the page out the same (the earlier paywall's rule).
class _SupportingLine extends StatelessWidget {
  final String text;

  const _SupportingLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium!
        .copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5);
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: line * 2),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}

/// 28 / 900 at Medium (the theme's 26 / 900 question title scaled, so it
/// follows the text size), 26 under 360 pt.
TextStyle _headlineStyle(ThemeData theme, double width) {
  final base = theme.textTheme.headlineMedium!;
  return base.copyWith(
    fontSize: base.fontSize! * (width < 360 ? 26 : 28) / 26,
    height: 1.14,
    letterSpacing: -.7,
    color: theme.colorScheme.onSurface,
  );
}

/// The annual plan's saving against twelve months of the monthly plan, from
/// the two products' own prices (never the rounded per-month figure), or
/// null when it does not save anything.
String? _savingsLabel(Package monthlyPackage, Package annualPackage) {
  final monthly = monthlyPackage.storeProduct.price;
  final annual = annualPackage.storeProduct.price;
  if (monthly <= 0) return null;
  final yearlyIfMonthly = monthly * 12;
  final savings = (yearlyIfMonthly - annual) / yearlyIfMonthly * 100;
  return savings > 0 ? 'Save ${savings.floor()}%' : null;
}

/// What one plan says, everywhere it is said (its card, the button, the
/// renewal terms), from the store product and this user's eligibility.
class _PlanTerms {
  final String label;
  final String price;

  /// "year", "month", or "3 months"; null if the store gave no period.
  final String? period;

  /// The trial's length ("7-day"), only when the product has an
  /// introductory offer and the user is eligible for it.
  final String? trialLength;

  /// The same trial as a span of time ("7 days").
  final String? trialSpan;
  final TrialEligibility eligibility;

  const _PlanTerms({
    required this.label,
    required this.price,
    required this.period,
    required this.trialLength,
    required this.trialSpan,
    required this.eligibility,
  });

  factory _PlanTerms.of(Package package,
      {required String label, required TrialEligibility eligibility}) {
    final product = package.storeProduct;
    final intro = product.introductoryPrice;
    String? length;
    String? span;
    if (intro != null && eligibility == TrialEligibility.eligible) {
      final (count, unit) = _trialDurationInDays(intro);
      length = _hyphenatedDuration(count, unit);
      span = _durationSpan(count, unit);
    }
    return _PlanTerms(
      label: label,
      price: product.priceString,
      period: _formatSubscriptionPeriod(product.subscriptionPeriod),
      trialLength: length,
      trialSpan: span,
      eligibility: eligibility,
    );
  }

  bool get hasTrial => trialLength != null;

  /// "$49.99 per year", or the price alone without a period.
  String get pricePerPeriod => period == null ? price : '$price per $period';

  /// The card's detail line: the trial, or how it is billed.
  String get detail {
    if (hasTrial) return '$trialLength free trial';
    return switch (period) {
      'year' => 'Billed yearly',
      'month' => 'Billed monthly',
      null => 'Billed per period',
      _ => 'Billed every $period',
    };
  }

  /// The purchase button: the trial when there is one for this user; the
  /// price and period when there is none; neutral when it is unknown.
  String get cta {
    if (hasTrial) return 'Start my $trialLength free trial';
    if (eligibility == TrialEligibility.unknown) return 'Continue with $label';
    return 'Subscribe for $pricePerPeriod';
  }

  /// The renewal terms under the button (App Store 3.1.2), always for the
  /// selected plan: the trial and then the price, or the price alone.
  String get disclosure => hasTrial
      ? '$trialSpan free, then $pricePerPeriod, auto-renews unless cancelled.'
      : '$pricePerPeriod, auto-renews unless cancelled.';
}

/// "7 days", "1 month": a trial as a span of time.
String _durationSpan(int count, PeriodUnit unit) {
  final singular = switch (unit) {
    PeriodUnit.day => 'day',
    PeriodUnit.week => 'week',
    PeriodUnit.month => 'month',
    PeriodUnit.year => 'year',
    PeriodUnit.unknown => 'period',
  };
  return '$count ${count == 1 ? singular : '${singular}s'}';
}

/// Below this screen height the decorative companion group is dropped.
const double _shortScreenHeight = 700;

/// The legal links go in the fixed footer while screen height divided by the
/// system text scale is at least this many points (see the screen's `build`).
const double _minHeightPerTextScale = 400;

/// The height of every text-button target in the footer: 44 pt, the
/// smallest Apple recommends, shrink-wrapped so the drawn button and the
/// target are the same.
const double _footerTargetHeight = 44;

final ButtonStyle _footerTextButtonStyle = TextButton.styleFrom(
  minimumSize: const Size(44, _footerTargetHeight),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// "GrammarLens" and Close (44 × 44).
class _TopBar extends StatelessWidget {
  final double horizontalPadding;
  final VoidCallback onClose;

  const _TopBar({required this.horizontalPadding, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 0),
      child: Row(
        children: [
          Expanded(
            child: BrandWordmark(
              style: theme.textTheme.titleMedium
                  ?.withWeight(FontWeight.w900)
                  .copyWith(color: colorScheme.onSurface, letterSpacing: -.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Close',
            color: colorScheme.onSurface,
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// The user's companion in the middle (124 pt) between two others (66 pt),
/// picked by fixed offsets from its own place in [Avatar.values] (owner
/// decision O11): the same visitor always sees the same three. Decorative
/// apart from saying whose companion it is; no `Hero`, so nothing collides
/// with Home's or Profile's avatar heroes.
List<Avatar> _otherAvatarsFor(Avatar center) {
  const offsets = [4, 6];
  return offsets
      .map(
          (offset) => Avatar.values[(center.index - 1 + offset) % Avatar.count])
      .toList();
}

class _AvatarHero extends StatelessWidget {
  final Avatar centerAvatar;

  const _AvatarHero({required this.centerAvatar});

  static const double centerSize = 124;
  static const double sideSize = 66;

  @override
  Widget build(BuildContext context) {
    final others = _otherAvatarsFor(centerAvatar);
    return Semantics(
      key: PremiumScreen.heroKey,
      label: 'Your companion: ${centerAvatar.semanticLabel}',
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: centerSize,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AvatarTile(avatar: others[0], radius: sideSize / 2),
                  ),
                  const SizedBox(width: 8),
                  AvatarTile(avatar: centerAvatar, radius: centerSize / 2),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AvatarTile(avatar: others[1], radius: sideSize / 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "GRAMMARLENS PREMIUM" on the warm surface.
class _PremiumLabel extends StatelessWidget {
  const _PremiumLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: palette.warm,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: palette.onWarm),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'GRAMMARLENS PREMIUM',
              style: theme.textTheme.labelSmall
                  ?.withWeight(FontWeight.w900)
                  .copyWith(color: palette.onWarm, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// "one" for 1: small counts in words, for the benefit lines.
String _countWord(int n) {
  const words = ['no', 'one', 'two', 'three', 'four', 'five'];
  return n >= 0 && n < words.length ? words[n] : '$n';
}

/// The three benefits, true to what each tier really has: a free user has
/// the Daily Test, AI feedback on one weak-spot practice a day, and Review;
/// so Premium's lines say "more" and "every topic", never "AI only in
/// Premium", and the session cap is stated rather than any "unlimited".
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static List<(IconData, String, String)> get benefits {
    const free = StorageService.freeDailyPracticeLimit;
    final lengthText = _joinWithOr(
        PracticeLength.values.map((l) => '${l.questionCount}').toList());
    return [
      (
        Icons.chat_bubble_outline_rounded,
        'Understand your mistakes',
        'AI feedback on every topic you practice, not just your free daily '
            'practice.'
      ),
      (
        Icons.track_changes_rounded,
        'Practice your weak spots',
        'Go beyond your ${_countWord(free)} free daily '
            'practice${free == 1 ? '' : 's'}.'
      ),
      (
        Icons.menu_book_rounded,
        'Every topic, your own pace',
        'All ${kTopics.length} topics · $lengthText questions · up to '
            '${StorageService.dailySessionLimit} sessions a day.'
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final items = benefits;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(23),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, thickness: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(items[i].$1,
                        size: 18, color: colorScheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$2,
                          style: theme.textTheme.bodyMedium
                              ?.withWeight(FontWeight.w800)
                              .copyWith(
                                  color: colorScheme.onSurface, height: 1.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          style: theme.textTheme.labelMedium
                              ?.withWeight(FontWeight.w400)
                              .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Compare Free & Premium": opens and closes the comparison table below
/// it. A 44 pt target; screen readers hear whether it is open.
class _CompareToggle extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _CompareToggle({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return MergeSemantics(
      child: Semantics(
        expanded: open,
        child: TextButton(
          key: PremiumScreen.compareToggleKey,
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: colorScheme.secondary,
            textStyle: theme.textTheme.labelMedium?.withWeight(FontWeight.w800),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text('Compare Free & Premium')),
              const SizedBox(width: 6),
              Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Restore Purchases, Terms of Service and Privacy Policy on one row,
/// wrapping when narrow; each a 44 pt target.
class _FooterLinks extends StatelessWidget {
  final bool restoring;
  final VoidCallback onRestore;

  /// In the footer: the row is only [_footerRowHeight] tall and each
  /// target reaches 44 pt upward, into the terms above (see [_TapArea]).
  final bool compact;

  const _FooterLinks({
    required this.restoring,
    required this.onRestore,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The three at the mockup's 11 / 700, so they share one row on a phone.
    final row = TextButtonTheme(
      data: TextButtonThemeData(
        style: _footerTextButtonStyle.copyWith(
          textStyle: WidgetStatePropertyAll(
              theme.textTheme.labelSmall?.withWeight(FontWeight.w700)),
          minimumSize: compact
              ? const WidgetStatePropertyAll(Size(44, _footerRowHeight))
              : null,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        // When the three wrap (narrow or large text), a second row's
        // targets reach up into this gap (see below).
        runSpacing: compact ? _footerTargetHeight - _footerRowHeight : 0,
        children: [
          _link(TextButton(
            key: PremiumScreen.restoreKey,
            // Required wherever a subscription is sold (App Store), in
            // every state, whether or not prices loaded.
            onPressed: restoring ? null : onRestore,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.secondary,
            ),
            child: Text(restoring ? 'Restoring…' : 'Restore Purchases'),
          )),
          _link(const LegalLink(
              label: 'Terms of Service', url: AppLinks.termsUrl)),
          _link(const LegalLink(
              label: 'Privacy Policy', url: AppLinks.privacyPolicyUrl)),
        ],
      ),
    );
    // The whole row reaches up over the terms (for the first row); each
    // link reaches up into the run gap (for a second row, if any).
    return compact ? _RowTapArea(child: row) : row;
  }

  Widget _link(Widget button) =>
      compact ? _TapArea(extendUp: true, child: button) : button;
}

/// The footer's text rows (the links, "Maybe later") are drawn this tall,
/// so the gaps between them match the gap above them (owner, after
/// Batch 12); [_TapArea] keeps each target 44 pt.
const double _footerRowHeight = 30;

/// Keeps a short footer button's target [_footerTargetHeight] tall by
/// taking taps in the empty or non-interactive space right above
/// ([extendUp]) or below it: the links take the renewal terms' lower edge
/// and the small gap above them (or the gap between two rows when they
/// wrap); "Maybe later" takes the empty margin under it. A tap there is
/// handed on as if it landed on the nearest edge, so the button under that
/// point gets it; the drawn size, and so the visible rhythm, does not
/// change. A tap is only seen where every ancestor contains it: the links'
/// row passes the space above itself through with [_RowTapArea], and the
/// bottom margin is a spacer inside the footer's column.
class _TapArea extends SingleChildRenderObjectWidget {
  final bool extendUp;

  const _TapArea({required this.extendUp, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapArea(extendUp);

  @override
  void updateRenderObject(BuildContext context, _RenderTapArea renderObject) {
    renderObject.extendUp = extendUp;
  }
}

class _RenderTapArea extends RenderProxyBox {
  _RenderTapArea(this.extendUp);

  bool extendUp;

  double get _extension =>
      (_footerTargetHeight - size.height).clamp(0, _footerTargetHeight);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final top = extendUp ? -_extension : 0.0;
    final bottom = size.height + (extendUp ? 0 : _extension);
    if (position.dx < 0 ||
        position.dx >= size.width ||
        position.dy < top ||
        position.dy >= bottom) {
      return false;
    }
    final inside = Offset(
        position.dx, position.dy.clamp(0.5, size.height - 0.5).toDouble());
    if (child != null && child!.hitTest(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// Lets taps in the [_footerTargetHeight] − [_footerRowHeight] points above
/// the links' row reach the links themselves (their own [_TapArea]s decide
/// which one); a [Wrap] alone ignores any point outside its box.
class _RowTapArea extends SingleChildRenderObjectWidget {
  const _RowTapArea({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRowTapArea();
}

class _RenderRowTapArea extends RenderProxyBox {
  static const double _reach = _footerTargetHeight - _footerRowHeight;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dy >= 0) return super.hitTest(result, position: position);
    if (position.dy < -_reach ||
        position.dx < 0 ||
        position.dx >= size.width ||
        child == null) {
      return false;
    }
    if (child!.hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// The fixed bottom area: never scrolls away.
///
/// - **loading**: a disabled button with a spinner, then the links and
///   "Maybe later".
/// - **prices ready**: the last purchase's or restore's result, the button
///   (its label from the selected plan's [_PlanTerms]), the renewal terms,
///   the links, and "Maybe later" (gone once a purchase succeeded: the
///   button becomes "Continue").
/// - **prices unavailable**: no button and no terms, which mean nothing
///   without a price; the links and "Maybe later". The retry is in the
///   body.
class _PremiumFooter extends StatelessWidget {
  final bool loading;
  final bool offeringsReady;
  final _PurchaseState purchaseState;
  final bool purchasedTrial;
  final String? restoreMessage;
  final _PlanTerms? terms;
  final bool showLinks;
  final bool restoring;
  final VoidCallback onRestore;
  final VoidCallback onPurchase;
  final VoidCallback onContinue;
  final VoidCallback onMaybeLater;
  final double horizontalPadding;

  /// Half the screen, applied only when the text is large enough that the
  /// links have moved to the body (screen height / text scale under 400;
  /// e.g. 375 × 667 at 2x and 3x). Past it the footer scrolls inside
  /// itself, the button first, so the body above still has room to scroll.
  final double maxHeight;

  Widget _capped(Widget content) => showLinks
      ? content
      : ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: content),
        );

  const _PremiumFooter({
    super.key,
    required this.loading,
    required this.offeringsReady,
    required this.purchaseState,
    required this.purchasedTrial,
    required this.restoreMessage,
    required this.terms,
    required this.showLinks,
    required this.restoring,
    required this.onRestore,
    required this.onPurchase,
    required this.onContinue,
    required this.onMaybeLater,
    required this.horizontalPadding,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showMaybeLater = purchaseState != _PurchaseState.success;
    return DecoratedBox(
      // A permanent edge between the scrolling body and this fixed area.
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        // The bottom inset is a spacer inside the column instead, so
        // "Maybe later"'s target can reach into it.
        bottom: false,
        child: _capped(
          Padding(
            padding:
                EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusMessage(
                  state: purchaseState,
                  purchasedTrial: purchasedTrial,
                  restoreMessage: restoreMessage,
                ),
                if (loading) ...[
                  const _Cta(
                    onPressed: null,
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(height: 6),
                ] else if (offeringsReady && terms != null) ...[
                  _Cta(
                    onPressed: switch (purchaseState) {
                      _PurchaseState.purchasing => null,
                      _PurchaseState.success => onContinue,
                      _ => onPurchase,
                    },
                    arrow: purchaseState != _PurchaseState.purchasing,
                    child: purchaseState == _PurchaseState.purchasing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            purchaseState == _PurchaseState.success
                                ? 'Continue'
                                : terms!.cta,
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      // Never cut: at large text it wraps and the footer grows.
                      terms!.disclosure,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall
                          ?.withWeight(FontWeight.w400)
                          .copyWith(
                              color: colorScheme.onSurfaceVariant, height: 1.6),
                    ),
                  ),
                ],
                // One rhythm under the button: the terms, the links and
                // "Maybe later" each about 14 pt apart (owner, after Batch
                // 12; "Maybe later" used to sit 27.5 pt under the links).
                if (showLinks) ...[
                  const SizedBox(height: 7),
                  _FooterLinks(
                      restoring: restoring,
                      onRestore: onRestore,
                      compact: true),
                ],
                if (showMaybeLater)
                  _TapArea(
                    extendUp: false,
                    child: Center(
                      child: TextButton(
                        style: _footerTextButtonStyle.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                              Size(44, _footerRowHeight)),
                          foregroundColor: WidgetStatePropertyAll(
                              colorScheme.onSurfaceVariant),
                        ),
                        onPressed: onMaybeLater,
                        child: const Text('Maybe later'),
                      ),
                    ),
                  ),
                // The bottom margin: the home indicator's inset plus 4, and
                // never less than "Maybe later"'s target needs below it.
                SizedBox(
                  height: (MediaQuery.paddingOf(context).bottom + 4)
                      .clamp(_footerTargetHeight - _footerRowHeight,
                          double.infinity)
                      .toDouble(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The purchase button: brandOrange with the onOrange text (the mockup's
/// colour), at least 52 tall, radius 17, an arrow after the label; the
/// app's opaque disabled pairing; no navy edge (Batch 8).
class _Cta extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool arrow;

  const _Cta(
      {required this.onPressed, required this.child, this.arrow = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return FilledButton(
      key: PremiumScreen.ctaKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        disabledBackgroundColor: palette.disabledFill,
        disabledForegroundColor: palette.disabledLabel,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: theme.textTheme.bodyLarge
            ?.withWeight(FontWeight.w900)
            .copyWith(height: 1.3),
      ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: child),
          if (arrow) ...[
            const SizedBox(width: 9),
            const Icon(Icons.arrow_forward_rounded, size: 17),
          ],
        ],
      ),
    );
  }
}

/// The result of the last purchase or restore, above the button; nothing
/// while idle or purchasing (the button shows that).
class _StatusMessage extends StatelessWidget {
  final _PurchaseState state;
  final bool purchasedTrial;
  final String? restoreMessage;

  const _StatusMessage({
    required this.state,
    required this.purchasedTrial,
    required this.restoreMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (IconData, String, Color)? content = switch (state) {
      _PurchaseState.success => (
          Icons.check_circle_rounded,
          purchasedTrial
              ? 'Trial started — Topic Practice is unlocked.'
              : 'Premium is active — Topic Practice is unlocked.',
          colorScheme.onSurface,
        ),
      _PurchaseState.cancelled => (
          Icons.info_outline_rounded,
          'Purchase cancelled — no charge was made.',
          colorScheme.onSurfaceVariant,
        ),
      _PurchaseState.pending => (
          Icons.hourglass_top_rounded,
          'Waiting for approval — Premium starts once the purchase is '
              'approved. No charge until then.',
          colorScheme.onSurfaceVariant,
        ),
      _PurchaseState.error => (
          Icons.error_outline_rounded,
          "Something went wrong and the purchase couldn't start. Please try "
              'again.',
          colorScheme.error,
        ),
      _PurchaseState.idle || _PurchaseState.purchasing => restoreMessage == null
          ? null
          : (
              Icons.info_outline_rounded,
              restoreMessage!,
              colorScheme.onSurfaceVariant,
            ),
    };
    if (content == null) return const SizedBox.shrink();
    final (icon, message, color) = content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        liveRegion: true,
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
      ),
    );
  }
}

class _ComparisonRow {
  final String label;
  final bool free;
  final String? freeLabel;
  final bool premium;

  const _ComparisonRow({
    required this.label,
    required this.free,
    this.freeLabel,
    required this.premium,
  });
}

/// Row 4's question counts, joined the way a sentence would ("3, 5 or 10"
/// — no Oxford comma) rather than a plain comma list, and read off
/// [PracticeLength] so this can't drift from what session lengths the app
/// actually offers.
String _joinWithOr(List<String> items) {
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} or ${items.last}';
}

/// Four rows (down from five): "Questions from your own mistakes" and
/// "Targeted weak-spot practice" used to describe the same underlying
/// capability twice, both showing free as "—" — which was also wrong.
/// `launchPracticeSet` (practice_launch.dart) genuinely grants a free user
/// [StorageService.freeDailyPracticeLimit] such sessions per day; merged
/// into one row with that real value, read from the constant rather than
/// retyped, so it can't drift from the actual quota again.
///
/// [weakSpotFreeLabel] is the only piece [_ComparisonTable] varies at
/// build time — it picks between the full "N a day" phrasing and an
/// abbreviated "N/day" once it's measured whether the full phrase fits
/// the free-value column on one line at the current width (see that
/// class's own doc comment on the overlap this replaced).
List<_ComparisonRow> _buildComparisonRows(String weakSpotFreeLabel) => [
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
      _ComparisonRow(
        label: 'Practice your weak spots',
        free: false,
        freeLabel: weakSpotFreeLabel,
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

/// Measures a single line of [text] in [style] at the context's current
/// [TextScaler] — the shared primitive behind every fixed-but-Dynamic-
/// Type-aware column width in [_ComparisonTable], so none of them drift
/// out of sync with each other or need a `FittedBox(scaleDown)` safety
/// net (the previous design's actual bug: a fixed-pixel column didn't fit
/// its own header word at the *default* text scale, let alone a larger
/// one).
///
/// Measured in the style the text is *drawn* in — [style] merged over the
/// ambient [DefaultTextStyle], which carries the app font — not in the
/// platform default font, which is narrower and shorter than Nunito Sans.
double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

final TextStyle _freeValueStyle =
    const TextStyle(fontSize: 12).withWeight(FontWeight.w700);

/// The Free/Premium comparison table. The Premium column reads as one
/// continuous, rounded, highlighted strip running from the header down to
/// the last row — not per-cell coloring — built from each row independently
/// painting its own [_PremiumStripCell] flush against its neighbors (zero
/// gap, matching fill color, only the very first/last corners rounded) so
/// adjacent cells visually fuse into one strip regardless of how tall any
/// individual row happens to be (a wrapped label at large Dynamic Type
/// grows only *that* row — see [_ComparisonRowLine]'s own doc comment).
///
/// Strip color is `colorScheme.secondaryContainer`/`onSecondaryContainer`
/// in light mode — not `colorScheme.secondary`, which the previous
/// per-cell-icon design used and which measures only 2.53:1 against
/// `secondaryContainer` in dark mode (fails the 3:1 non-text minimum).
/// Dark mode uses `colorScheme.surfaceContainerHighest` for the fill
/// instead of `secondaryContainer` (visual-polish batch, same date as
/// this comment): the saturated navy read as too dominant a block of
/// color against the dark body, and `onSecondaryContainer` still holds
/// 9.34:1 against this calmer neutral fill (measured, up from 7.13:1 —
/// still comfortably clears both the 4.5:1 text and 3:1 icon minimums).
/// Light mode is untouched — its 9.79:1 pairing was never the complaint.
class _ComparisonTable extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ComparisonTable({required this.theme, required this.colorScheme});

  /// The Premium column's width — enough for "PREMIUM" at the *current*
  /// text scale, measured directly via [_measureTextWidth] rather than a
  /// fixed constant, so this is correct at any Dynamic Type setting.
  double _premiumColumnWidth(BuildContext context) {
    final width = _measureTextWidth(context, 'PREMIUM', _headerStyle);
    // Horizontal padding inside the strip on each side, plus a floor so a
    // single small checkmark icon never makes the strip look pinched.
    return (width + 28).clamp(56, double.infinity);
  }

  /// Row heights are computed up front (measured, not `IntrinsicHeight`) —
  /// `IntrinsicHeight` combined with an `Expanded` child is a known
  /// unreliable pairing (Flutter asks a flex child for its "intrinsic"
  /// height independent of the width it will actually be allocated, which
  /// can under-measure badly): this surfaced as a real overflow at 2.0x
  /// text scale during this batch's own testing, not a hypothetical
  /// concern. A fixed, measured height per row type — enough for the
  /// header's own single line, or two lines for a data row's label — is
  /// simpler and doesn't have that failure mode; a label short enough to
  /// need only one line just centers within the extra room.
  double _measuredHeight(BuildContext context, TextStyle style, int maxLines) {
    final painter = TextPainter(
      text:
          TextSpan(text: List.filled(maxLines, 'Mg').join('\n'), style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height + 10; // 5 top + 5 bottom padding, both row types
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowDividerColor =
            colorScheme.outlineVariant.withValues(alpha: 0.4);
        final premiumWidth = _premiumColumnWidth(context);

        // The free-value column ("FREE" header, checkmark/dash, and the
        // weak-spot row's own quota text) used to share a flex factor with
        // the row label in one Row — which split the row 50/50 regardless
        // of how much either side actually needed, squeezed "1 a day" into
        // a narrow sliver that wrapped to two lines, and let that second
        // line silently paint outside the row's fixed height (a *vertical*
        // RenderFlex overflow, which Flutter doesn't report the way it
        // does a horizontal one — the exact reason ordinary overflow tests
        // never caught this). Giving the free-value column its own
        // measured, non-flexible width instead — sized to fit its own
        // longest real content on one line — makes that vertical overflow
        // structurally impossible: the label gets every remaining pixel
        // to itself and wraps only within its own column, and the
        // free-value column never needs more than one line because it was
        // sized for exactly the text it holds.
        const freeColumnHorizontalPadding = 24.0; // 12 each side
        // Below this much room for the label column, a two-line wrapped
        // label stops being legible — the threshold this table falls back
        // to the shorter "N/day" phrasing at, rather than an untested
        // guess: PRD copy review confirmed 96pt is the narrowest a label
        // like "Practice your weak spots" reads comfortably at 2 lines,
        // 13sp, on this table's own font.
        const minLabelWidth = 96.0;
        final freeHeaderWidth =
            _measureTextWidth(context, 'FREE', _headerStyle);
        // The checkmark icon (_ComparisonCell's `included` branch) is 20pt
        // square — included as a width candidate so the column is never
        // narrower than the icon itself even if every text candidate
        // measures smaller (not the case today, but keeps this correct if
        // the header/quota text ever gets shorter than that).
        const checkmarkWidth = 20.0;
        const limit = StorageService.freeDailyPracticeLimit;
        const longFreeText = '$limit a day';
        const shortFreeText = '$limit/day';
        final longFreeWidth =
            _measureTextWidth(context, longFreeText, _freeValueStyle);
        final shortFreeWidth =
            _measureTextWidth(context, shortFreeText, _freeValueStyle);

        double columnWidthFor(double freeTextWidth) =>
            [freeHeaderWidth, checkmarkWidth, freeTextWidth]
                .reduce((a, b) => a > b ? a : b) +
            freeColumnHorizontalPadding;

        var freeText = longFreeText;
        var freeColumnWidth = columnWidthFor(longFreeWidth);
        var availableForLabel =
            constraints.maxWidth - premiumWidth - freeColumnWidth;
        if (availableForLabel < minLabelWidth) {
          freeText = shortFreeText;
          freeColumnWidth = columnWidthFor(shortFreeWidth);
          availableForLabel =
              constraints.maxWidth - premiumWidth - freeColumnWidth;
        }

        // The table only counts as fitting if every label reads in full in
        // the two lines a row is sized for. A label that needs a third line
        // would be cut off with an ellipsis, and a sales table must not clip
        // what it sells. Measured exactly as drawn: same style, same text
        // scale, and the label cell's width minus its own padding.
        final labelStyle =
            theme.textTheme.bodySmall?.copyWith(fontSize: 13) ?? _headerStyle;
        bool everyLabelFitsInTwoLines() {
          final textWidth = availableForLabel - _labelCellHorizontalPadding;
          if (textWidth <= 0) return false;
          for (final row in _buildComparisonRows(freeText)) {
            final painter = TextPainter(
              text: TextSpan(
                text: row.label,
                style: DefaultTextStyle.of(context).style.merge(labelStyle),
              ),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 2,
            )..layout(maxWidth: textWidth);
            if (painter.didExceedMaxLines) return false;
          }
          return true;
        }

        // Even the shortest phrasing leaves the label less than
        // [minLabelWidth], or a label would be clipped: three columns no
        // longer fit (a narrow screen or a large text size). Rather than
        // squeeze, clip or scroll, stack each row: label on top at full
        // width, its Free and Premium values on one line below. No content
        // is dropped and nothing scrolls sideways.
        if (availableForLabel < minLabelWidth || !everyLabelFitsInTwoLines()) {
          return _StackedComparison(
            key: const Key('comparisonStacked'),
            rows: _buildComparisonRows(longFreeText),
            theme: theme,
            colorScheme: colorScheme,
          );
        }

        final rows = _buildComparisonRows(freeText);
        final headerHeight = _measuredHeight(context, _headerStyle, 1);
        final dataRowHeight = _measuredHeight(context, labelStyle, 2);

        return Container(
          key: const Key('comparisonTable'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _ComparisonHeaderRow(
                colorScheme: colorScheme,
                freeColumnWidth: freeColumnWidth,
                premiumWidth: premiumWidth,
                height: headerHeight,
              ),
              for (var i = 0; i < rows.length; i++)
                _ComparisonRowLine(
                  // Identifies each row's own rendered rect for the
                  // geometry regression tests guarding the vertical-
                  // overflow class of bug this table used to have — see
                  // this class's own doc comment.
                  key: ValueKey('comparisonRow_${rows[i].label}'),
                  row: rows[i],
                  theme: theme,
                  colorScheme: colorScheme,
                  freeColumnWidth: freeColumnWidth,
                  premiumWidth: premiumWidth,
                  height: dataRowHeight,
                  showDivider: i != rows.length - 1,
                  dividerColor: rowDividerColor,
                  isLastRow: i == rows.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The label cell's own horizontal padding in [_ComparisonRowLine]; the
/// table's fit check subtracts it from the label column to get the text width.
const double _labelCellLeftPadding = 20;
const double _labelCellRightPadding = 8;
const double _labelCellHorizontalPadding =
    _labelCellLeftPadding + _labelCellRightPadding;

final TextStyle _headerStyle =
    const TextStyle(fontSize: 12).withWeight(FontWeight.w700);

/// The comparison table's fallback when its three columns do not fit (see
/// [_ComparisonTable]): the same four rows, the same Free/Premium facts, laid
/// out top to bottom. Each row is a label with its full width and natural
/// height (no ellipsis, no fixed height), then a [Wrap] of two tier chips so
/// they fall onto separate lines instead of overflowing at the largest text
/// sizes. The Premium chip keeps the table's Premium-strip colors, so the
/// two layouts read as one visual language.
class _StackedComparison extends StatelessWidget {
  final List<_ComparisonRow> rows;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _StackedComparison({
    super.key,
    required this.rows,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              key: ValueKey('comparisonRow_${rows[i].label}'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].label,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StackedTierChip(
                        tier: 'Free',
                        included: rows[i].free,
                        valueLabel: rows[i].freeLabel,
                        fill: colorScheme.surfaceContainerHighest,
                        foreground: colorScheme.onSurfaceVariant,
                        dashColor: colorScheme.outline,
                      ),
                      _StackedTierChip(
                        tier: 'Premium',
                        included: rows[i].premium,
                        fill: colorScheme.brightness == Brightness.dark
                            ? colorScheme.surfaceContainerHighest
                            : colorScheme.secondaryContainer,
                        foreground: colorScheme.onSecondaryContainer,
                        dashColor: colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One "Free" or "Premium" value in [_StackedComparison]: the tier name in
/// the header style, then the same glyph the table uses (or [valueLabel]
/// when the row has a specific free quota such as "1 a day").
class _StackedTierChip extends StatelessWidget {
  final String tier;
  final bool included;
  final String? valueLabel;
  final Color fill;
  final Color foreground;
  final Color dashColor;

  const _StackedTierChip({
    required this.tier,
    required this.included,
    this.valueLabel,
    required this.fill,
    required this.foreground,
    required this.dashColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      // A Wrap, not a Row: at the largest text sizes the tier name and its
      // value must be free to fall onto two lines inside the chip rather
      // than overflow it.
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tier.toUpperCase(),
            style: _headerStyle.copyWith(color: foreground),
          ),
          if (valueLabel != null)
            // The quota is part of the visible text; screen readers get the
            // whole phrase from it, so it needs no separate semantics label.
            Text(
              valueLabel!,
              style: _freeValueStyle.copyWith(color: foreground),
            )
          else
            _ComparisonCell(
              included: included,
              includedColor: foreground,
              dashColor: dashColor,
              tier: tier,
            ),
        ],
      ),
    );
  }
}

class _ComparisonHeaderRow extends StatelessWidget {
  final ColorScheme colorScheme;
  final double freeColumnWidth;
  final double premiumWidth;
  final double height;

  const _ComparisonHeaderRow({
    required this.colorScheme,
    required this.freeColumnWidth,
    required this.premiumWidth,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Purely a spacer matching the label column's own left padding —
          // "FREE" itself now lives in the fixed-width column below, the
          // same one every row's checkmark/dash/quota-text renders in, so
          // the header centers on exactly the same x-position as what it
          // labels (docs/design-audit.md's own "FREE should share a center
          // with the ticks and dividers below it" finding).
          const Expanded(child: SizedBox.shrink()),
          SizedBox(
            width: freeColumnWidth,
            child: Center(
              child: Text(
                'FREE',
                style: _headerStyle.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          _PremiumStripCell(
            key: const Key('premiumStripHeader'),
            colorScheme: colorScheme,
            width: premiumWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Text(
              'PREMIUM',
              maxLines: 1,
              style: _headerStyle.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One data row, split into three siblings sharing one [Row]: the label
/// (an [Expanded] carrying its own bottom divider, with the whole
/// remaining width to itself), the free-value column (a fixed
/// [freeColumnWidth] — see [_ComparisonTable]'s own doc comment for why
/// this is measured rather than flexed), and the Premium strip cell.
/// [CrossAxisAlignment.stretch] plus a fixed, pre-measured [height] (see
/// [_ComparisonTable._measuredHeight] — deliberately *not*
/// `IntrinsicHeight`, which doesn't combine reliably with an `Expanded`
/// child; that pairing under-measured badly enough to genuinely overflow
/// at 2.0x text scale during this batch's own testing) makes every column
/// match the row's own height. The label itself is capped at two lines
/// with an ellipsis rather than wrapping indefinitely, since [height] is
/// sized for exactly two lines; the free-value text is capped at one —
/// [freeColumnWidth] is sized so it never actually needs to wrap.
class _ComparisonRowLine extends StatelessWidget {
  final _ComparisonRow row;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final double freeColumnWidth;
  final double premiumWidth;
  final double height;
  final bool showDivider;
  final Color dividerColor;
  final bool isLastRow;

  const _ComparisonRowLine({
    super.key,
    required this.row,
    required this.theme,
    required this.colorScheme,
    required this.freeColumnWidth,
    required this.premiumWidth,
    required this.height,
    required this.showDivider,
    required this.dividerColor,
    required this.isLastRow,
  });

  @override
  Widget build(BuildContext context) {
    final divider =
        showDivider ? Border(bottom: BorderSide(color: dividerColor)) : null;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: divider),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _labelCellLeftPadding, 5, _labelCellRightPadding, 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    row.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: freeColumnWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(border: divider),
              child: Center(
                child: row.freeLabel != null
                    ? Text(
                        row.freeLabel!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.withWeight(FontWeight.w700)
                            .copyWith(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant),
                      )
                    : _ComparisonCell(
                        included: row.free,
                        includedColor: colorScheme.onSurfaceVariant,
                        dashColor: colorScheme.outline,
                        tier: 'Free',
                      ),
              ),
            ),
          ),
          _PremiumStripCell(
            colorScheme: colorScheme,
            width: premiumWidth,
            borderRadius: isLastRow
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  )
                : null,
            child: _ComparisonCell(
              included: row.premium,
              includedColor: colorScheme.onSecondaryContainer,
              dashColor: colorScheme.onSecondaryContainer,
              tier: 'Premium',
            ),
          ),
        ],
      ),
    );
  }
}

/// One segment of the continuous Premium strip — see [_ComparisonTable]'s
/// own doc comment for why this is built as N adjacent same-color cells
/// (one per row) rather than a single overlay spanning the table: it
/// makes per-row height (a wrapped label at large Dynamic Type) a
/// non-issue, since each cell simply fills whatever height its own row
/// turns out to need.
class _PremiumStripCell extends StatelessWidget {
  final ColorScheme colorScheme;
  final double width;
  final BorderRadius? borderRadius;
  final Widget child;

  const _PremiumStripCell({
    super.key,
    required this.colorScheme,
    required this.width,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Dark mode's own calmer fill — see _ComparisonTable's doc comment.
    final fillColor = colorScheme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.secondaryContainer;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: child,
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
              style: TextStyle(color: dashColor, fontSize: 16)
                  .withWeight(FontWeight.w600),
            ),
    );
  }
}

/// The plan's saving ("Save 24%"), on the warm surface (the mockup's
/// colours, O1): onWarm on warm, 7.96:1 (light) and 7.82:1 (dark).
class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: palette.warm,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.withWeight(FontWeight.w800)
            .copyWith(color: palette.onWarm),
      ),
    );
  }
}

/// The two plans stacked as radio cards (the 1.2.0 mockup): Annual (with the
/// saving, when there is one) above Monthly; annual preselected. Every word
/// and number comes from [_PlanTerms] and [_savingsLabel], so nothing is
/// hardcoded and the cards never disagree with the button.
class _PlanCards extends StatelessWidget {
  final _PlanTerms annual;
  final _PlanTerms monthly;
  final String? savingsLabel;
  final _PlanPeriod selected;
  final ValueChanged<_PlanPeriod> onChanged;

  const _PlanCards({
    required this.annual,
    required this.monthly,
    required this.savingsLabel,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(
          terms: annual,
          savingsLabel: savingsLabel,
          selected: selected == _PlanPeriod.annual,
          onTap: () => onChanged(_PlanPeriod.annual),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          terms: monthly,
          savingsLabel: null,
          selected: selected == _PlanPeriod.monthly,
          onTap: () => onChanged(_PlanPeriod.monthly),
        ),
      ],
    );
  }
}

/// One plan: the radio mark, the name (and the saving), the trial or how it
/// is billed, and the price with its period. Radius 19, at least 87 tall;
/// selected: a 2 pt link-coloured edge on the info surface.
class _PlanCard extends StatelessWidget {
  final _PlanTerms terms;
  final String? savingsLabel;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.terms,
    required this.savingsLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final edge = selected ? 2.0 : 1.0;
    final radius = BorderRadius.circular(19);
    final savings = savingsLabel;
    final muted = theme.textTheme.labelSmall
        ?.withWeight(FontWeight.w600)
        .copyWith(color: colorScheme.onSurfaceVariant);

    return Semantics(
      key: ValueKey('planCard_${terms.label}'),
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label: '${terms.label} plan, ${terms.pricePerPeriod}, ${terms.detail}'
          '${savings != null ? ', $savings' : ''}',
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 87),
            padding: EdgeInsets.symmetric(
                horizontal: 14 - edge, vertical: 16 - edge),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? colorScheme.secondary
                    : colorScheme.outlineVariant,
                width: edge,
              ),
              boxShadow: selected ? null : palette.cardShadow,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            terms.label,
                            style: theme.textTheme.titleSmall
                                ?.withWeight(FontWeight.w900)
                                .copyWith(color: colorScheme.onSurface),
                          ),
                          if (savings != null) _Badge(label: savings),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(terms.detail, style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      terms.price,
                      style: theme.textTheme.titleLarge
                          ?.withWeight(FontWeight.w900)
                          .copyWith(
                              color: colorScheme.onSurface,
                              height: 1.3,
                              letterSpacing: -.5),
                    ),
                    if (terms.period != null)
                      Text('per ${terms.period}', style: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when [SubscriptionService.getOfferings] comes back empty — no
/// RevenueCat/App Store Connect product connected (expected right now, see
/// this file's class doc comment) or a transient failure. Either way, a
/// clear non-crashing state rather than a blank or broken screen — this is
/// also a launch blocker, not just a nicety: App Review rejects a paywall
/// it opens that can't fetch products.
///
/// One compact row — icon, a single short sentence, an inline retry — not
/// the earlier title-plus-paragraph-plus-full-width-button card. This
/// state replaces the plan cards one-for-one in the layout, so it stays
/// close to their own footprint instead of the page growing taller
/// specifically for the unhappy path.
class _UnavailableCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onRetry;

  const _UnavailableCard({
    required this.theme,
    required this.colorScheme,
    required this.onRetry,
  });

  static const _message = "Prices aren't available right now";

  /// A TextButton's own horizontal padding is 12 on each side and its
  /// minimum width 64; the label is measured, not guessed, so this follows
  /// Dynamic Type.
  double _retryButtonWidth(BuildContext context) {
    final label = _measureTextWidth(
      context,
      'Try again',
      theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14),
    );
    return (label + 24).clamp(64, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20);
    final message = Text(_message, style: theme.textTheme.bodyMedium);
    final retry =
        TextButton(onPressed: onRetry, child: const Text('Try again'));

    return Container(
      key: const Key('pricingUnavailableCard'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Room the sentence gets on the one-row layout: what is left after
          // the icon, its gap, the gap before the button, and the button.
          final roomForMessage =
              constraints.maxWidth - 20 - 10 - 8 - _retryButtonWidth(context);
          final painter = TextPainter(
            text: TextSpan(text: _message, style: theme.textTheme.bodyMedium),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
          )..layout(maxWidth: roomForMessage > 0 ? roomForMessage : 0);
          final fitsOnOneRow = roomForMessage > 0 && !painter.didExceedMaxLines;

          if (fitsOnOneRow) {
            return Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: message),
                const SizedBox(width: 8),
                retry,
              ],
            );
          }
          // Too big for one row (a narrow screen at a large text size): the
          // sentence keeps the full width and the retry drops below it.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Expanded(child: message),
                ],
              ),
              Align(alignment: Alignment.centerRight, child: retry),
            ],
          );
        },
      ),
    );
  }
}

/// The loading state's placeholder — shaped like the two plan cards it
/// will become, rather than a spinner unrelated to what's arriving. Plain
/// muted boxes, not an animated shimmer: this app has no shimmer/skeleton
/// package today and this batch doesn't add one, so the "skeleton" here is
/// static shape only.

/// The loading state's placeholder, shaped like the two stacked plan cards
/// it will become: static muted boxes, no shimmer.
class _PlanCardsSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _PlanCardsSkeleton({required this.colorScheme});

  Widget _bar({required double height, required double width}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _card() => Container(
        constraints: const BoxConstraints(minHeight: 87),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(height: 14, width: 64),
                const SizedBox(height: 10),
                _bar(height: 12, width: 104),
              ],
            ),
            const Spacer(),
            _bar(height: 22, width: 70),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading pricing',
      child: Column(
        children: [
          _card(),
          const SizedBox(height: 10),
          _card(),
        ],
      ),
    );
  }
}

/// Normalizes a trial's (count, unit) pair to days when it's expressed in
/// weeks, so the disclosure line reads in comparable units regardless of
/// how the store happens to model a given plan's introductory offer —
/// App Store Connect models the annual trial as a "1 Week" duration, which
/// StoreKit/RevenueCat report back as `PeriodUnit.week`/1, not as 7 days
/// (PRD v2 §13.2). Every other unit passes through unchanged; this is
/// display-only and never touches [_formatSubscriptionPeriod] (the
/// separate renewal-period text), which has its own independent input
/// (the product's ISO subscription period, not the introductory offer).
(int, PeriodUnit) _trialDurationInDays(IntroductoryPrice trial) {
  if (trial.periodUnit == PeriodUnit.week) {
    return (trial.periodNumberOfUnits * 7, PeriodUnit.day);
  }
  return (trial.periodNumberOfUnits, trial.periodUnit);
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
