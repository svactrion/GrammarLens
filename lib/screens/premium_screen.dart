import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../motion.dart';
import '../utils/haptics.dart';
import '../widgets/companion_dialog.dart';
import '../widgets/companion_view.dart';
import '../widgets/pressable_button.dart';
import '../widgets/rest_scene.dart';
import 'premium_on_screen.dart';
import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/practice_length.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/legal_link.dart';
import '../utils/content_width.dart';
import '../utils/monthly_equivalent.dart';
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

  /// V13r (SPEC §1.15): opened from the free users' rest scene. Only the
  /// top changes (the evening camp with the awake companion, "<Hero> is
  /// wide awake", today's weak spot, the benefits in V13r's order); after a
  /// trial starts PW05r sends the user straight into that practice: the
  /// screen pops with `true` when they choose it.
  final PaywallRest? rest;

  PremiumScreen({
    super.key,
    required this.storageService,
    required this.analyticsService,
    required this.analyticsSource,
    SubscriptionService? subscriptionService,
    this.onDone,
    this.sourceContext,
    this.rest,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  // The headline, the same from every entry point: `paywallHeadline`.

  static const compareToggleKey = ValueKey('premium_compare_toggle');
  static const ctaKey = ValueKey('premium_cta');
  static const restoreKey = ValueKey('premium_restore');
  static const heroKey = ValueKey('premium_hero');

  /// V13 (v11): "Compare plans" under the first view.
  static const comparePlansKey = ValueKey('premium_compare_plans');

  /// V13c (v11): "Choose your plan" under the comparison.
  static const choosePlanHintKey = ValueKey('premium_choose_plan_hint');
  static const closeKey = ValueKey('premium_close');
  static const exitStartKey = ValueKey('premium_exit_start');
  static const exitContinueFreeKey = ValueKey('premium_exit_continue_free');
  static const selectedPlanKey = ValueKey('premium_selected_plan');
  static const timelineKey = ValueKey('premium_trial_timeline');
  static const compareKey = ValueKey('premium_compare');

  /// V13r: the rest-scene top, its awake companion and its weak spot card.
  static const restTopKey = ValueKey('premium_rest_top');
  static const restCompanionKey = ValueKey('premium_rest_companion');
  static const restSpotKey = ValueKey('premium_rest_spot');

  /// V13c (fix round 2): the one-piece Premium column, the companion beside
  /// the heading, and the green note under the table.
  static const premiumColumnKey = ValueKey('premium_compare_column');
  static const compareCompanionKey = ValueKey('premium_compare_companion');
  static const compareNoteKey = ValueKey('premium_compare_note');

  /// V13a / V13c: a plan's and a comparison row's entrance.
  static ValueKey<String> planRevealKey(int i) =>
      ValueKey('premium_plan_reveal_$i');
  static ValueKey<String> rowRevealKey(int i) =>
      ValueKey('premium_row_reveal_$i');

  /// For tests: lets the next close show V13b (once per session) again.
  @visibleForTesting
  static void resetExitReminder() =>
      _PremiumScreenState._exitReminderShown = false;

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

  // Picked once per visit: a legacy profile with no avatar (or an unknown
  // id) still shows a real companion, the same one on every rebuild.
  late final Avatar _fallbackAvatar = Avatar.random();
  late Avatar _userAvatar = _fallbackAvatar;

  // Set by _dismiss() before it pops, so the PopScope observer can tell a
  // button's exit from a system back gesture.
  bool _exitHandled = false;

  /// The user's name, for the headline and the exit pop-up (V13, V13b).
  String _userName = '';

  /// V13b opens once per app session, on the first close.
  static bool _exitReminderShown = false;

  final _scroll = ScrollController();
  final _plansKey = GlobalKey();
  final _compareKey = GlobalKey();

  /// The plans have scrolled up out of view (V13c): their name sits above
  /// the pinned button.
  bool _plansPassed = false;

  @override
  void initState() {
    super.initState();
    widget.analyticsService.paywallViewed(widget.analyticsSource);
    _loadOffer();
    _loadAvatar();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final plans = _plansKey.currentContext?.findRenderObject() as RenderBox?;
    final body = context.findRenderObject() as RenderBox?;
    if (plans == null || !plans.hasSize || body == null) return;
    final bottom = plans.localToGlobal(Offset(0, plans.size.height)).dy;
    final passed = bottom < MediaQuery.paddingOf(context).top + 60;
    if (passed != _plansPassed) setState(() => _plansPassed = passed);
  }

  /// V13 (v11): "Compare plans" scrolls Free vs Premium into view.
  void _toCompare() {
    final compare = _compareKey.currentContext;
    if (compare == null) return;
    Scrollable.ensureVisible(compare,
        alignment: .05,
        duration: AppMotion.orInstant(context, AppMotion.slow),
        curve: AppMotion.enter);
  }

  /// V13c (v11): "Choose your plan" scrolls the plans into view.
  void _seePlans() {
    final plans = _plansKey.currentContext;
    if (plans == null) return;
    Scrollable.ensureVisible(plans,
        alignment: .05,
        duration: AppMotion.orInstant(context, AppMotion.slow),
        curve: AppMotion.enter);
  }

  /// The close button: the first time in an app session, V13b asks once
  /// (no discount); otherwise, and on "Continue with free", the paywall
  /// closes as before.
  Future<void> _onClose() async {
    final terms = _offeringsAvailable && _selectedPackage != null
        ? _termsFor(_selectedPackage!,
            _selectedPeriod == _PlanPeriod.annual ? 'Annual' : 'Monthly')
        : null;
    if (_exitReminderShown ||
        terms == null ||
        _purchaseState == _PurchaseState.purchasing ||
        _purchaseState == _PurchaseState.success) {
      _dismiss(dismissMethod: AnalyticsService.paywallDismissCloseButton);
      return;
    }
    _exitReminderShown = true;
    HapticMap.light();
    final l10n = context.l10n;
    final result = await showCompanionDialog(
      context: context,
      hero: _userAvatar,
      mood: CompanionMood.sad,
      title: _userName.trim().isEmpty
          ? l10n.paywallExitTitleNoName
          : l10n.paywallExitTitle(_userName.trim()),
      body: l10n.paywallExitBody,
      primaryLabel: terms.cta,
      primaryTone: ButtonTone.orange,
      secondaryLabel: l10n.paywallExitContinueFree,
      primaryKey: PremiumScreen.exitStartKey,
      secondaryKey: PremiumScreen.exitContinueFreeKey,
    );
    if (!mounted) return;
    switch (result) {
      case CompanionDialogResult.primary:
        await _startPurchase();
      case CompanionDialogResult.secondary:
        _dismiss(dismissMethod: AnalyticsService.paywallDismissCloseButton);
      case null:
        break;
    }
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
    setState(() {
      _userAvatar = profile?.avatar ?? _fallbackAvatar;
      _userName = profile?.name ?? '';
    });
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

  _PlanTerms _termsFor(Package package, String id) => _PlanTerms.of(
        package,
        id: id,
        label: switch (id) {
          'Annual' => context.l10n.paywallPlanAnnual,
          'Monthly' => context.l10n.paywallPlanMonthly,
          _ => id,
        },
        l10n: context.l10n,
        eligibility: _eligibility[package.storeProduct.identifier] ??
            TrialEligibility.unknown,
        locale: View.of(context).platformDispatcher.locale.toString(),
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
    if (outcome == PurchaseOutcome.success && mounted) {
      await _showPremiumOn(terms);
    }
  }

  /// PW05: the celebration after a purchase or trial start; its Continue
  /// closes the paywall as the footer's Continue does.
  Future<void> _showPremiumOn(_PlanTerms terms) async {
    final trialDays = _trialDays(terms.trial);
    final done = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        transitionDuration: AppMotion.orInstant(context, AppMotion.slow),
        pageBuilder: (_, __, ___) => PremiumOnScreen(
          hero: widget.rest?.hero ?? _userAvatar,
          topics: practiceTopics().length,
          sessions: StorageService.dailySessionLimit,
          trialEnds: trialDays == null
              ? null
              : DateTime.now().add(Duration(days: trialDays)),
          rest: widget.rest == null
              ? null
              : PremiumOnRest(weakSpot: widget.rest!.weakSpot),
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (done == true && mounted) {
      _practiseNext = widget.rest != null;
      _dismiss();
    }
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
          ? context.l10n.paywallRestored
          : context.l10n.paywallNothingToRestore;
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
    Navigator.of(context).pop(_practiseNext ? true : null);
  }

  /// PW05r's "Practise <weak spot>" was chosen (V13r only): the rest
  /// scene opens that practice once this screen has closed.
  bool _practiseNext = false;

  String get _supportingText {
    final source = widget.sourceContext?.trim();
    return source == null || source.isEmpty
        ? context.l10n.paywallSupporting
        : context.l10n.paywallSupportingSource(source);
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
              onClose: _onClose,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
                child: Column(
                  key: const Key('premiumBody'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Decorative, and 133 pt a short screen (an iPhone SE)
                    // cannot spare: dropped under 700 pt tall.
                    if (widget.rest case final rest?)
                      _RestTop(
                        rest: rest,
                        hero: rest.hero ?? _userAvatar,
                        name: (rest.name ?? _userName).trim(),
                        trial: _trialDays(selectedTerms?.trial) != null,
                        headlineStyle: _headlineStyle(theme, size.width),
                        compact: shortScreen,
                      )
                    else ...[
                      if (!shortScreen) ...[
                        _AvatarHero(centerAvatar: _userAvatar),
                        const SizedBox(height: 9),
                      ],
                      const Center(child: _PremiumLabel()),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          _userName.trim().isEmpty
                              ? context.l10n.paywallHeadline
                              : context.l10n
                                  .paywallHeadlineName(_userName.trim()),
                          textAlign: TextAlign.center,
                          style: _headlineStyle(theme, size.width),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SupportingLine(text: _supportingText),
                      const SizedBox(height: 21),
                      const _BenefitsCard(),
                    ],
                    const SizedBox(height: 8),
                    // V13 (v11): no price boxes on the first view; value
                    // before price: "Compare plans" leads to Free vs Premium
                    // (13c), then the plans and the trial (13a), one page.
                    Center(
                      child: _ScrollHint(
                        key: PremiumScreen.comparePlansKey,
                        label: context.l10n.paywallComparePlans,
                        onTap: _toCompare,
                      ),
                    ),
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: PremiumScreen.compareKey,
                      child: KeyedSubtree(
                        key: _compareKey,
                        child: _ComparisonTable(
                            theme: theme,
                            colorScheme: colorScheme,
                            hero: _userAvatar,
                            reveal: _scroll),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: _ScrollHint(
                        key: PremiumScreen.choosePlanHintKey,
                        label: context.l10n.paywallChoosePlan,
                        onTap: _seePlans,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // V13a (v11): the plans and the trial at the page's end.
                    // The selected plan (yearly by default) drives the
                    // pinned button from the first view on.
                    Semantics(
                      key: _plansKey,
                      header: true,
                      child: Text(
                        context.l10n.paywallChoosePlan,
                        style: theme.textTheme.titleLarge
                            ?.withWeight(FontWeight.w900)
                            .copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                height: 1.4),
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
                        reveal: _scroll,
                        annual: _termsFor(annual, 'Annual'),
                        monthly: _termsFor(monthly, 'Monthly'),
                        savingsLabel:
                            _savingsLabel(monthly, annual, context.l10n),
                        referencePrice: _referencePrice(
                            monthly,
                            annual,
                            View.of(context)
                                .platformDispatcher
                                .locale
                                .toString()),
                        selected: _selectedPeriod,
                        onChanged: (period) =>
                            setState(() => _selectedPeriod = period),
                      ),
                    if (_trialDays(selectedTerms?.trial) case final days?) ...[
                      const SizedBox(height: 18),
                      _TrialTimeline(days: days),
                    ],
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
              planLabel: _plansPassed && selectedTerms != null
                  ? context.l10n.paywallSelectedPlan(selectedTerms.label)
                  : null,
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
    // Two lines as the engine draws them, not fontSize × height × 2: with a
    // fractional font size the two differ by a fraction of a point, and a
    // weak spot's one-line text would then not take the default's place.
    final painter = TextPainter(
      // l10n-guard: a two-line measuring probe, never shown
      text: TextSpan(text: 'A\nA', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final twoLines = painter.height;
    painter.dispose();
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: twoLines),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}

/// 28 / 900 at Small (the theme's 26 / 900 question title scaled, so it
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
String? _savingsLabel(
    Package monthlyPackage, Package annualPackage, AppLocalizations l10n) {
  final percent = _savingsPercent(monthlyPackage, annualPackage);
  return percent == null ? null : l10n.paywallSave(percent);
}

/// The saving in whole percent, or null when there is none.
int? _savingsPercent(Package monthlyPackage, Package annualPackage) {
  final monthly = monthlyPackage.storeProduct.price;
  final annual = annualPackage.storeProduct.price;
  if (monthly <= 0) return null;
  final yearlyIfMonthly = monthly * 12;
  final savings = (yearlyIfMonthly - annual) / yearlyIfMonthly * 100;
  return savings > 0 ? savings.floor() : null;
}

/// Twelve months of the monthly plan, shown struck through on the annual
/// card, only when the saving badge shows too (otherwise it would compare
/// against nothing); null when either is missing or it cannot be formatted.
String? _referencePrice(
    Package monthlyPackage, Package annualPackage, String locale) {
  if (_savingsPercent(monthlyPackage, annualPackage) == null) return null;
  // An annual price that is not a price (0) is no reference to strike
  // against, whatever the badge says.
  if (annualPackage.storeProduct.price <= 0) return null;
  final product = monthlyPackage.storeProduct;
  return twelveMonthsPrice(
    monthlyPrice: product.price,
    currencyCode: product.currencyCode,
    locale: locale,
  );
}

/// A billing or trial period as data: how many of which unit.
typedef _Period = ({int count, PeriodUnit unit});

/// What one plan says, everywhere it is said (its card, the button, the
/// renewal terms), from the store product and this user's eligibility.
/// The words come from the strings (1.4.0 B4.6); the period is kept as
/// data, so "is this the yearly plan" never compares a word.
class _PlanTerms {
  /// The plan's stable name for keys: "Annual", "Monthly" (never shown).
  final String id;
  final String label;
  final String price;

  /// The billing period; null if the store gave none.
  final _Period? billing;

  /// The trial, only when the product has an introductory offer and the
  /// user is eligible for it.
  final _Period? trial;
  final TrialEligibility eligibility;

  /// A yearly plan's price over twelve months ("$4.17"), computed from the
  /// store price (see [monthlyEquivalent]); null on any other plan, and when
  /// it cannot be worked out.
  final String? monthlyEquivalentPrice;
  final AppLocalizations l10n;

  const _PlanTerms({
    required this.id,
    required this.label,
    required this.price,
    required this.billing,
    required this.trial,
    required this.eligibility,
    required this.l10n,
    this.monthlyEquivalentPrice,
  });

  factory _PlanTerms.of(Package package,
      {required String id,
      required String label,
      required TrialEligibility eligibility,
      required String locale,
      required AppLocalizations l10n}) {
    final product = package.storeProduct;
    final intro = product.introductoryPrice;
    final _Period? trial =
        intro != null && eligibility == TrialEligibility.eligible
            ? _trialDurationInDays(intro)
            : null;
    final billing = _parseSubscriptionPeriod(product.subscriptionPeriod);
    final yearly = billing?.unit == PeriodUnit.year && billing?.count == 1;
    return _PlanTerms(
      id: id,
      label: label,
      price: product.priceString,
      billing: billing,
      trial: trial,
      eligibility: eligibility,
      l10n: l10n,
      monthlyEquivalentPrice: yearly
          ? monthlyEquivalent(
              annualPrice: product.price,
              currencyCode: product.currencyCode,
              locale: locale,
            )
          : null,
    );
  }

  /// "year", "month", or "3 months"; null if the store gave no period.
  String? get period {
    final b = billing;
    return b == null ? null : _periodWord(b, l10n);
  }

  /// The trial's length ("7-day").
  String? get trialLength {
    final t = trial;
    return t == null ? null : _trialLengthWord(t, l10n);
  }

  /// The same trial as a span of time ("7 days").
  String? get trialSpan {
    final t = trial;
    return t == null ? null : _spanWord(t, l10n);
  }

  /// The annual card's small extra line, "≈ $4.17 per month"; null when
  /// there is none.
  String? get monthlyEquivalentLine {
    final value = monthlyEquivalentPrice;
    return value == null ? null : l10n.paywallPerMonthApprox(value);
  }

  bool get hasTrial => trial != null;

  /// "$49.99 per year", or the price alone without a period.
  String get pricePerPeriod {
    final p = period;
    return p == null ? price : l10n.paywallPricePerPeriod(price, p);
  }

  /// The card's detail line: the trial, or how it is billed.
  String get detail {
    if (hasTrial) return l10n.paywallTrial(trialLength!);
    final b = billing;
    if (b == null) return l10n.paywallBilledPerPeriod;
    if (b.count == 1 && b.unit == PeriodUnit.year) {
      return l10n.paywallBilledYearly;
    }
    if (b.count == 1 && b.unit == PeriodUnit.month) {
      return l10n.paywallBilledMonthly;
    }
    return l10n.paywallBilledEvery(period!);
  }

  /// The purchase button: the trial when there is one for this user; the
  /// price and period when there is none; neutral when it is unknown.
  String get cta {
    if (hasTrial) return l10n.paywallStartTrial(trialLength!);
    if (eligibility == TrialEligibility.unknown) {
      return l10n.paywallContinueWith(label);
    }
    return l10n.paywallSubscribeFor(pricePerPeriod);
  }

  /// The renewal terms under the button (App Store 3.1.2), always for the
  /// selected plan: the trial and then the price, or the price alone.
  String get disclosure => hasTrial
      ? l10n.paywallDisclosureTrial(trialSpan!, pricePerPeriod)
      : l10n.paywallDisclosure(pricePerPeriod);
}

/// "month" or "3 months": a billing period after "per" or "every".
String _periodWord(_Period p, AppLocalizations l10n) => switch (p.unit) {
      PeriodUnit.day => l10n.paywallPeriodDay(p.count),
      PeriodUnit.week => l10n.paywallPeriodWeek(p.count),
      PeriodUnit.month => l10n.paywallPeriodMonth(p.count),
      PeriodUnit.year => l10n.paywallPeriodYear(p.count),
      PeriodUnit.unknown => l10n.paywallPeriodUnknown,
    };

/// "7 days", "1 month": a trial as a span of time.
String _spanWord(_Period p, AppLocalizations l10n) => switch (p.unit) {
      PeriodUnit.day => l10n.paywallSpanDay(p.count),
      PeriodUnit.week => l10n.paywallSpanWeek(p.count),
      PeriodUnit.month => l10n.paywallSpanMonth(p.count),
      PeriodUnit.year => l10n.paywallSpanYear(p.count),
      PeriodUnit.unknown => l10n.paywallSpanUnknown(p.count),
    };

/// "7-day": a trial's length before "free trial".
String _trialLengthWord(_Period p, AppLocalizations l10n) => switch (p.unit) {
      PeriodUnit.day => l10n.paywallTrialLengthDay(p.count),
      PeriodUnit.week => l10n.paywallTrialLengthWeek(p.count),
      PeriodUnit.month => l10n.paywallTrialLengthMonth(p.count),
      PeriodUnit.year => l10n.paywallTrialLengthYear(p.count),
      PeriodUnit.unknown => l10n.paywallTrialLengthUnknown(p.count),
    };

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
            key: PremiumScreen.closeKey,
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: context.l10n.paywallClose,
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
      .map((offset) => Avatar.values[(center.order + offset) % Avatar.count])
      .toList();
}

class _AvatarHero extends StatelessWidget {
  final Avatar centerAvatar;

  const _AvatarHero({required this.centerAvatar});

  /// The board's sizes (V13: 70, 110, 64; fix round 2 keeps the old 124 pt
  /// row height so nothing below moves).
  static const double centerSize = 110;
  static const double leftSize = 70;
  static const double rightSize = 64;

  @override
  Widget build(BuildContext context) {
    final others = _otherAvatarsFor(centerAvatar);
    // V13 (fix round 2): the side companions float, the middle one hops,
    // each over a soft shadow; CompanionView runs the loops (still under
    // Reduce Motion).
    Widget companion(Avatar a, double size, CompanionAmbient ambient) =>
        SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: size * .22,
              right: size * .22,
              bottom: size * .01,
              height: size * .08,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(size),
                  ),
                ),
              ),
            ),
            CompanionView(
                hero: a, size: size, ambient: ambient, decorative: true),
          ]),
        );
    return Semantics(
      key: PremiumScreen.heroKey,
      label: context.l10n.paywallCompanion(centerAvatar.name(context.l10n)),
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 124,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  companion(others[0], leftSize, CompanionAmbient.float),
                  const SizedBox(width: 4),
                  companion(centerAvatar, centerSize, CompanionAmbient.hop),
                  const SizedBox(width: 4),
                  companion(others[1], rightSize, CompanionAmbient.float),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What V13r (the paywall opened from the free users' rest scene, SPEC
/// §1.15) needs to draw its top: the month's camp and today's weak spot
/// (null when there is none).
class PaywallRest {
  final ClimbTheme theme;
  final String? weakSpot;

  /// The companion and the name the rest scene showed, so the paywall and
  /// PW05r name the same hero (null: the stored profile's).
  final Avatar? hero;
  final String? name;

  const PaywallRest({required this.theme, this.weakSpot, this.hero, this.name});
}

/// The free trial, in days, the paywall would promise on its preselected
/// annual plan: only when the store has one and says this user is eligible,
/// the paywall's own rule; null otherwise (and on any error). V24f's button
/// says "· N days free" only with it.
Future<int?> paywallTrialDays(SubscriptionService service) async {
  try {
    final offering = await service.getOfferings();
    final package = offering?.annual ?? offering?.monthly;
    final intro = package?.storeProduct.introductoryPrice;
    if (package == null || intro == null) return null;
    final id = package.storeProduct.identifier;
    final eligibility = await service.checkTrialEligibility([id]);
    if (eligibility[id] != TrialEligibility.eligible) return null;
    return _trialDays(_trialDurationInDays(intro));
  } catch (_) {
    return null;
  }
}

/// V13r's top (fix round 2, item 11): an evening camp strip (the month's
/// night art, the awake companion waving, the campfire), the "GRAMMARLENS
/// PREMIUM" chip, "<Hero> is wide awake, <name>.", the subline, a
/// "PRACTISE IT NOW" card with today's weak spot, then the benefits in
/// V13r's order. The rest of the page (plans, table, CTA) is V13's.
class _RestTop extends StatelessWidget {
  final PaywallRest rest;
  final Avatar hero;
  final String name;
  final bool trial;
  final TextStyle headlineStyle;
  final bool compact;

  const _RestTop({
    required this.rest,
    required this.hero,
    required this.name,
    required this.trial,
    required this.headlineStyle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const free = StorageService.freeDailyPracticeLimit;
    const sessions = StorageService.dailySessionLimit;
    final heroName = hero.name(l10n);
    final lengths = _joinWithOr(
        PracticeLength.values.map((l) => '${l.questionCount}').toList(), l10n);
    final spot = rest.weakSpot;
    Widget benefit(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: c.sky, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: c.onSky),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall!
                          .withWeight(FontWeight.w900)
                          .copyWith(fontSize: 16, color: c.text)),
                  Text(body,
                      style:
                          theme.textTheme.bodyMedium!.copyWith(color: c.muted)),
                ],
              ),
            ),
          ]),
        );
    return Column(
      key: PremiumScreen.restTopKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The evening camp, the companion awake (V24s continues here).
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              height: compact ? 120 : 160,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(rest.theme.backgroundFor(Brightness.dark),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, .55),
                    excludeFromSemantics: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.nightTop.withValues(alpha: .25),
                        c.nightBottom.withValues(alpha: .55),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-.1, 1.15),
                  child: CompanionView(
                      key: PremiumScreen.restCompanionKey,
                      hero: hero,
                      mood: CompanionMood.wave,
                      size: compact ? 96 : 120,
                      decorative: true),
                ),
                const Align(
                  alignment: Alignment(.42, .95),
                  child: SizedBox(width: 50, height: 64, child: Campfire()),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: _PremiumLabel()),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            name.isEmpty
                ? l10n.paywallRestTitleNoName(heroName)
                : l10n.paywallRestTitle(heroName, name),
            textAlign: TextAlign.center,
            style: headlineStyle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallRestSubline(sessions - free),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge!.copyWith(color: c.muted),
        ),
        if (spot != null) ...[
          const SizedBox(height: 16),
          Container(
            key: PremiumScreen.restSpotKey,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: lipCard(c, radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.paywallRestPractiseNow,
                    style: theme.textTheme.labelMedium!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.navy, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(spot,
                    style: theme.textTheme.titleLarge!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.text)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: c.redSoft,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(l10n.paywallRestSavedToday,
                          style: theme.textTheme.labelMedium!
                              .withWeight(FontWeight.w800)
                              .copyWith(color: c.onRedSoft)),
                    ),
                    Text(
                        trial
                            ? l10n.paywallRestAfterTrial
                            : l10n.paywallRestAfterPremium,
                        style: theme.textTheme.labelLarge!
                            .withWeight(FontWeight.w800)
                            .copyWith(color: c.navy)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: lipCard(c, radius: 22),
          child: Column(children: [
            benefit(
                Icons.track_changes_rounded,
                l10n.paywallRestSessionsTitle(sessions),
                l10n.paywallRestSessionsBody(sessions - free, sessions)),
            benefit(Icons.chat_bubble_outline_rounded,
                l10n.paywallRestFeedbackTitle, l10n.paywallRestFeedbackBody),
            benefit(
                Icons.menu_book_rounded,
                l10n.paywallRestTopicsTitle(practiceTopics().length),
                l10n.paywallRestTopicsBody(lengths)),
          ]),
        ),
      ],
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
              context.l10n.paywallBadge,
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

/// The three benefits, true to what each tier really has: a free user has
/// the Daily Test, AI feedback on one weak-spot practice a day, and Review;
/// so Premium's lines say "more" and "every topic", never "AI only in
/// Premium", and the session cap is stated rather than any "unlimited".
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static List<(IconData, String, String)> benefits(AppLocalizations l10n) {
    const free = StorageService.freeDailyPracticeLimit;
    final lengthText = _joinWithOr(
        PracticeLength.values.map((l) => '${l.questionCount}').toList(), l10n);
    return [
      (
        Icons.chat_bubble_outline_rounded,
        l10n.paywallBenefitFeedbackTitle,
        l10n.paywallBenefitFeedbackBody,
      ),
      (
        Icons.track_changes_rounded,
        l10n.paywallBenefitWeakSpotsTitle,
        l10n.paywallBenefitWeakSpotsBody(free),
      ),
      (
        Icons.menu_book_rounded,
        l10n.paywallBenefitTopicsTitle,
        l10n.paywallBenefitTopicsBody(practiceTopics().length, lengthText,
            StorageService.dailySessionLimit),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final items = benefits(context.l10n);
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
            child: Text(restoring
                ? context.l10n.paywallRestoring
                : context.l10n.paywallRestore),
          )),
          _link(LegalLink(
              label: context.l10n.commonTermsOfService,
              url: AppLinks.termsUrl)),
          _link(LegalLink(
              label: context.l10n.commonPrivacyPolicy,
              url: AppLinks.privacyPolicyUrl)),
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
  /// V13c: the selected plan's name above the button once the plans have
  /// scrolled away.
  final String? planLabel;
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
    this.planLabel,
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
                  if (planLabel != null &&
                      purchaseState != _PurchaseState.success) ...[
                    Center(
                      child: Text(
                        planLabel!,
                        key: PremiumScreen.selectedPlanKey,
                        style: theme.textTheme.labelMedium
                            ?.withWeight(FontWeight.w900)
                            .copyWith(color: colorScheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
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
                                ? context.l10n.commonContinue
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
                        child: Text(context.l10n.paywallMaybeLater),
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
    // V13: the pinned CTA shines and pulses (fix round 2: it had neither).
    return CtaGlow(
      enabled: onPressed != null,
      color: theme.colorScheme.primary,
      radius: 17,
      child: _button(theme, palette),
    );
  }

  Widget _button(ThemeData theme, AppPalette palette) {
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
              ? context.l10n.paywallTrialStarted
              : context.l10n.paywallActive,
          colorScheme.onSurface,
        ),
      _PurchaseState.cancelled => (
          Icons.info_outline_rounded,
          context.l10n.paywallCancelled,
          colorScheme.onSurfaceVariant,
        ),
      _PurchaseState.pending => (
          Icons.hourglass_top_rounded,
          context.l10n.paywallPending,
          colorScheme.onSurfaceVariant,
        ),
      _PurchaseState.error => (
          Icons.error_outline_rounded,
          context.l10n.paywallFailed,
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

/// Row 4's question counts, joined the way a sentence would ("3, 5 or 10"
/// — no Oxford comma) rather than a plain comma list, and read off
/// [PracticeLength] so this can't drift from what session lengths the app
/// actually offers.
String _joinWithOr(List<String> items, AppLocalizations l10n) {
  if (items.length == 1) return items.first;
  return l10n.paywallListOr(
      items.sublist(0, items.length - 1).join(l10n.listSeparator), items.last);
}

/// A value in V13c's Free or Premium column.
sealed class _CompareValue {
  const _CompareValue();
}

class _CompareText extends _CompareValue {
  final String text;
  const _CompareText(this.text);
}

class _CompareCheck extends _CompareValue {
  const _CompareCheck();
}

class _CompareNone extends _CompareValue {
  const _CompareNone();
}

/// One V13c row: an icon tile, a label, the Free and the Premium value.
class _CompareRow {
  final IconData icon;
  final String label;
  final _CompareValue free;
  final _CompareValue premium;

  const _CompareRow(this.icon, this.label, this.free, this.premium);
}

/// One Daily Test a day, free or Premium (the shared daily set).
const _dailyTestsPerDay = 1;

/// V13c's rows (fix round 2, item 3), each value read from the app's real
/// rules so the table cannot drift from them: one Daily Test a day for
/// everyone; AI practice [StorageService.freeDailyPracticeLimit] vs
/// [StorageService.dailySessionLimit] a day; weak-spot practice in both;
/// every topic ([practiceTopics]) in Premium only; a free session is
/// always [PracticeLength.quick] (`practice_launch.dart`), Premium picks
/// any [PracticeLength]; the Monthly Climb in both.
List<_CompareRow> _compareRows(AppLocalizations l10n) {
  String perDay(int n) => l10n.paywallFreePerDay(n);
  return [
    _CompareRow(
        Icons.today_rounded,
        l10n.featureDailyTest,
        _CompareText(perDay(_dailyTestsPerDay)),
        _CompareText(perDay(_dailyTestsPerDay))),
    _CompareRow(
        Icons.auto_awesome_rounded,
        l10n.paywallCompareAiPractice,
        _CompareText(perDay(StorageService.freeDailyPracticeLimit)),
        _CompareText(perDay(StorageService.dailySessionLimit))),
    _CompareRow(Icons.track_changes_rounded, l10n.paywallCompareWeakSpots,
        const _CompareCheck(), const _CompareCheck()),
    _CompareRow(
        Icons.menu_book_rounded,
        l10n.paywallCompareTopics(practiceTopics().length),
        const _CompareNone(),
        const _CompareCheck()),
    _CompareRow(
        Icons.timer_outlined,
        l10n.paywallCompareLength,
        _CompareText('${PracticeLength.quick.questionCount}'),
        _CompareText(PracticeLength.values
            .map((l) => '${l.questionCount}')
            .join(' · '))),
    _CompareRow(Icons.landscape_rounded, l10n.paywallCompareClimb,
        const _CompareCheck(), const _CompareCheck()),
  ];
}

/// V13c-PaywallCompare (fix round 2, item 3, the board's values): the
/// heading "Free vs Premium" with the user's companion hopping at its end;
/// a card whose Premium column is one piece from the header to the last row
/// (2 px orange border, soft orange fill, a 4 px lip, a navy "Premium" pill
/// on top); six rows of an icon tile and a label; Free checks are grey
/// outlines, Premium checks filled green, "—" grey; then the green
/// "Cancel anytime" note. The rows appear 40 ms apart the first time they
/// scroll into view (a fade only).
class _ComparisonTable extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final Avatar hero;

  /// The page's scroll, for the rows' entrance.
  final ScrollController? reveal;

  const _ComparisonTable({
    required this.theme,
    required this.colorScheme,
    required this.hero,
    this.reveal,
  });

  /// The board's column widths (V13c: `minmax(0, 1fr) 76px 92px`).
  static const double freeWidth = 76;
  static const double premiumWidth = 92;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final rows = _compareRows(l10n);
    final valueStyle = theme.textTheme.bodyMedium!
        .withWeight(FontWeight.w900)
        .copyWith(fontSize: 14, height: 1.2);

    String spoken(String tier, _CompareValue v) => switch (v) {
          _CompareText(:final text) => l10n.paywallCompareValue(tier, text),
          _CompareCheck() => l10n.paywallIncludedIn(tier),
          _CompareNone() => l10n.paywallNotIncludedIn(tier),
        };

    Widget value(_CompareValue v, {required bool premium}) => switch (v) {
          _CompareText(:final text) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text,
                  maxLines: 1,
                  style:
                      valueStyle.copyWith(color: premium ? c.navy : c.muted)),
            ),
          _CompareCheck() => Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: premium ? c.green : null,
                border: premium
                    ? null
                    : Border.all(color: c.disabledLabel, width: 2),
              ),
              child: Icon(Icons.check_rounded,
                  size: 16, color: premium ? c.onNavy : c.disabledLabel),
            ),
          _CompareNone() => Container(
              width: 26,
              height: 26,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: c.disabledFill),
              child:
                  Icon(Icons.remove_rounded, size: 16, color: c.disabledLabel),
            ),
        };

    Widget row(int i) {
      final r = rows[i];
      return RevealOnScroll(
        key: PremiumScreen.rowRevealKey(i),
        scroll: reveal,
        delay: _rowStagger * i,
        child: Semantics(
          key: ValueKey('comparisonRow_${r.label}'),
          container: true,
          label: [
            r.label,
            spoken(l10n.paywallTierFree, r.free),
            spoken(l10n.featurePremium, r.premium),
          ].join('. '),
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            decoration: i == 0
                ? null
                : BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: c.sky, borderRadius: BorderRadius.circular(10)),
                    child: Icon(r.icon, size: 18, color: c.onSky),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.label,
                        style: theme.textTheme.bodyMedium!
                            .withWeight(FontWeight.w800)
                            .copyWith(
                                fontSize: 15, height: 1.2, color: c.text)),
                  ),
                ]),
              ),
              SizedBox(
                  width: freeWidth,
                  child: Center(child: value(r.free, premium: false))),
              SizedBox(
                  width: premiumWidth,
                  child: Center(child: value(r.premium, premium: true))),
            ]),
          ),
        ),
      );
    }

    final card = Container(
      key: const Key('comparisonTable'),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: c.line, width: 2),
        boxShadow: [BoxShadow(color: c.lip, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 6),
      child: Stack(clipBehavior: Clip.none, children: [
        // The Premium column, one piece from the header to the last row.
        PositionedDirectional(
          end: 0,
          top: -6,
          bottom: 2,
          width: premiumWidth,
          child: DecoratedBox(
            key: PremiumScreen.premiumColumnKey,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.cream, c.orangeSoft],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.orange, width: 2),
              boxShadow: [
                BoxShadow(color: c.orangeDeep, offset: const Offset(0, 4))
              ],
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Spacer(),
                SizedBox(
                  width: freeWidth,
                  child: Text(l10n.paywallTierFree,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(fontSize: 13, color: c.muted)),
                ),
                SizedBox(
                  width: premiumWidth,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.navy,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.featurePremium,
                            maxLines: 1,
                            style: theme.textTheme.labelMedium!
                                .withWeight(FontWeight.w800)
                                .copyWith(fontSize: 12, color: c.onNavy)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          for (var i = 0; i < rows.length; i++) row(i),
        ]),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(l10n.paywallCompareTitle,
                style: theme.textTheme.titleLarge!
                    .withWeight(FontWeight.w900)
                    .copyWith(fontSize: 22, height: 1.4, color: c.text)),
          ),
        ),
        const SizedBox(width: 8),
        CompanionView(
            key: PremiumScreen.compareCompanionKey,
            hero: hero,
            mood: CompanionMood.cheer,
            size: 60,
            ambient: CompanionAmbient.hop,
            decorative: true),
      ]),
      const SizedBox(height: 14),
      card,
      const SizedBox(height: 14),
      Container(
        key: PremiumScreen.compareNoteKey,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.greenSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_outlined, size: 18, color: c.onGreenSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.paywallCompareNote,
                style: theme.textTheme.bodySmall!
                    .withWeight(FontWeight.w700)
                    .copyWith(fontSize: 13, height: 1.4, color: c.onGreenSoft)),
          ),
        ]),
      ),
    ]);
  }
}

/// V13c: the table's rows appear this far apart.
const _rowStagger = Duration(milliseconds: 40);

/// Measures a single line of [text] in [style] at the context's current
/// [TextScaler], in the style it is drawn in ([style] merged over the
/// ambient [DefaultTextStyle], which carries the app font).
double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

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
  final String? referencePrice;
  final _PlanPeriod selected;
  final ValueChanged<_PlanPeriod> onChanged;

  /// V13a: the page's scroll; each plan enters from below, 60 ms after the
  /// one above, the first time it scrolls into view.
  final ScrollController? reveal;

  const _PlanCards({
    this.reveal,
    required this.annual,
    required this.monthly,
    required this.savingsLabel,
    required this.referencePrice,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RevealOnScroll(
          key: PremiumScreen.planRevealKey(0),
          scroll: reveal,
          rise: 24,
          child: _PlanCard(
            terms: annual,
            savingsLabel: savingsLabel,
            referencePrice: referencePrice,
            selected: selected == _PlanPeriod.annual,
            onTap: () => onChanged(_PlanPeriod.annual),
          ),
        ),
        const SizedBox(height: 10),
        RevealOnScroll(
          key: PremiumScreen.planRevealKey(1),
          scroll: reveal,
          rise: 24,
          delay: AppMotion.stagger,
          child: _PlanCard(
            terms: monthly,
            savingsLabel: null,
            selected: selected == _PlanPeriod.monthly,
            onTap: () => onChanged(_PlanPeriod.monthly),
          ),
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

  /// Twelve months of the monthly plan ("$71.88"), struck through above the
  /// price; only on the annual card and only with a saving badge.
  final String? referencePrice;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.terms,
    required this.savingsLabel,
    this.referencePrice,
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
      key: ValueKey('planCard_${terms.id}'),
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label:
          '${context.l10n.paywallPlanSemantics(terms.label, terms.pricePerPeriod)}'
          '${terms.monthlyEquivalentPrice != null ? context.l10n.paywallPlanSemanticsMonthly(terms.monthlyEquivalentPrice!) : ''}'
          ', ${terms.detail}'
          '${savings != null ? ', $savings' : ''}'
          '${referencePrice != null ? context.l10n.paywallPlanSemanticsReference(referencePrice!) : ''}',
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
                      // Same style as the detail line: never more prominent
                      // than the billed price (App Store 3.1.2).
                      if (terms.monthlyEquivalentLine case final line?)
                        Text(line, style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (referencePrice != null)
                      Text(
                        referencePrice!,
                        style: muted?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: muted.color,
                        ),
                      ),
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
                      Text(context.l10n.paywallPerPeriod(terms.period!),
                          style: muted),
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

  // The message: `paywallUnavailable`.

  /// A TextButton's own horizontal padding is 12 on each side and its
  /// minimum width 64; the label is measured, not guessed, so this follows
  /// Dynamic Type.
  double _retryButtonWidth(BuildContext context) {
    final label = _measureTextWidth(
      context,
      context.l10n.commonTryAgain,
      theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14),
    );
    return (label + 24).clamp(64, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20);
    final message = Text(context.l10n.paywallUnavailable,
        style: theme.textTheme.bodyMedium);
    final retry = TextButton(
        onPressed: onRetry, child: Text(context.l10n.commonTryAgain));

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
            text: TextSpan(
                text: context.l10n.paywallUnavailable,
                style: theme.textTheme.bodyMedium),
            textDirection: Directionality.of(context),
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
              Align(alignment: AlignmentDirectional.centerEnd, child: retry),
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
      label: context.l10n.paywallLoadingPricing,
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
/// display-only and never touches [_parseSubscriptionPeriod] (the
/// separate renewal-period text), which has its own independent input
/// (the product's ISO subscription period, not the introductory offer).
/// A trial's length in days when it is counted in days or weeks; null for
/// a month or longer (the timeline and the end date are then left out
/// rather than guessed).
int? _trialDays(_Period? trial) => switch (trial?.unit) {
      PeriodUnit.day => trial!.count,
      PeriodUnit.week => trial!.count * 7,
      _ => null,
    };

_Period _trialDurationInDays(IntroductoryPrice trial) {
  if (trial.periodUnit == PeriodUnit.week) {
    return (count: trial.periodNumberOfUnits * 7, unit: PeriodUnit.day);
  }
  return (count: trial.periodNumberOfUnits, unit: trial.periodUnit);
}

/// Parses RevenueCat's ISO-8601 subscription period ("P1M", "P3D", ...),
/// or null if absent or unparseable — callers should omit the "/ period"
/// suffix entirely then, rather than showing a raw ISO string to the user.
_Period? _parseSubscriptionPeriod(String? iso) {
  if (iso == null) return null;
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso);
  if (match == null) return null;
  final unit = switch (match.group(2)) {
    'D' => PeriodUnit.day,
    'W' => PeriodUnit.week,
    'M' => PeriodUnit.month,
    'Y' => PeriodUnit.year,
    _ => null,
  };
  if (unit == null) return null;
  return (count: int.parse(match.group(1)!), unit: unit);
}

/// The trial timeline (V13a, V13c): today everything unlocks with nothing
/// to pay; on the last day the plan starts unless cancelled before.
class _TrialTimeline extends StatelessWidget {
  final int days;
  const _TrialTimeline({required this.days});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    Widget step(IconData icon, Color color, String text, {bool line = true}) =>
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              if (line)
                Expanded(
                  child: Container(width: 3, color: c.line),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 14),
                child: Text(text,
                    style: theme.textTheme.bodyMedium!
                        .withWeight(FontWeight.w700)
                        .copyWith(color: c.text)),
              ),
            ),
          ]),
        );
    return Container(
      key: PremiumScreen.timelineKey,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: lipCard(c, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.paywallTimelineTitle,
                style: theme.textTheme.titleSmall!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: c.text)),
          ),
          const SizedBox(height: 12),
          step(Icons.lock_open_rounded, c.green, l10n.paywallTimelineToday),
          step(Icons.event_rounded, c.navy, l10n.paywallTimelineEnd(days),
              line: false),
        ],
      ),
    );
  }
}

/// V13 / V13c (v11): a small grey hint with a chevron under it ("Compare
/// plans", "Choose your plan"); the chevron floats every 1.8 s; tapping it
/// scrolls on. At least 44 pt tall to tap.
class _ScrollHint extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ScrollHint({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _Floating(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium!
                        .withWeight(FontWeight.w800)
                        .copyWith(fontSize: 12, color: c.muted)),
                const SizedBox(height: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: c.muted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// V13 / V13c: the hint floats up 8 pt and back every 1.8 s (the boards'
/// `gl-float`, an ambient loop).
class _Floating extends StatefulWidget {
  final Widget child;
  const _Floating({required this.child});

  static const period = Duration(milliseconds: 1800);

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge;

  @override
  void initState() {
    super.initState();
    _nudge = AnimationController(vsync: this, duration: _Floating.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context)) {
      if (!_nudge.isAnimating) _nudge.repeat();
    } else {
      _nudge
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _nudge,
        // V13's `gl-float` 1.8 s (fix round 2: the board's motion, up 8 and
        // back every 1.8 s, instead of a nudge that rested 60 % of the time).
        builder: (context, child) => Transform.translate(
            offset:
                Offset(0, -8 * (1 - math.cos(2 * math.pi * _nudge.value)) / 2),
            child: child),
        child: widget.child,
      );
}

/// An entrance played the first time [child] scrolls into view in [scroll]
/// (or at once if it is already in view): a fade over [AppMotion.slow] after
/// [delay], rising from [rise] points below. Its semantics stay while it is
/// hidden. Without a [scroll], or under Reduce Motion, it is just shown.
class RevealOnScroll extends StatefulWidget {
  final ScrollController? scroll;
  final Duration delay;
  final double rise;
  final Widget child;

  const RevealOnScroll({
    super.key,
    required this.scroll,
    this.delay = Duration.zero,
    this.rise = 0,
    required this.child,
  });

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: AppMotion.slow + widget.delay);
    if (widget.scroll == null) {
      _enter.value = 1;
      _started = true;
    } else {
      widget.scroll!.addListener(_check);
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    widget.scroll?.removeListener(_check);
    _enter.dispose();
    super.dispose();
  }

  /// In view: its top above the bottom fifth of the screen (the pinned
  /// footer's band).
  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top > MediaQuery.sizeOf(context).height * .8) return;
    _started = true;
    widget.scroll?.removeListener(_check);
    if (AppMotion.reduced(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _enter.duration!.inMilliseconds;
    final curve = Interval(widget.delay.inMilliseconds / total, 1,
        curve: AppMotion.enter);
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = curve.transform(_enter.value);
        return Opacity(
          opacity: t,
          alwaysIncludeSemantics: true,
          child: widget.rise == 0
              ? child
              : Transform.translate(
                  offset: Offset(0, widget.rise * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}
