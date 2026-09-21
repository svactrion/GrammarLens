import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/avatar.dart';
import '../models/practice_length.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../utils/page_title.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';

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
/// Layout (the visual-redesign batch, docs/build-log.md same date as this
/// comment): a scrollable middle (headline, comparison table, plan cards,
/// Restore Purchases, legal links) plus a *fixed* footer (purchase status,
/// the primary CTA, the disclosure line, "Maybe later") — the same
/// scroll-body-plus-fixed-footer shape `AvatarPickerScreen` already uses,
/// adopted here because the previous single-`ListView` layout never
/// actually pinned the CTA the way a paywall's primary action should be.
///
/// Price and trial terms are read live from RevenueCat's current offering
/// ([SubscriptionService.getOfferings]), never hardcoded, so this screen
/// can't silently drift from whatever is actually configured in App Store
/// Connect. As of this commit no RevenueCat/App Store Connect product
/// exists yet, so that fetch always comes back empty unless Settings'
/// debug-only "Preview paywall pricing" toggle is on — the "pricing
/// unavailable" state below, not a crash, is the expected real-device
/// result without it.
class PremiumScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  /// Needed only for the hero avatar group's own avatar — this screen
  /// doesn't receive a `UserProfile`/`Avatar` from any of its four call
  /// sites today (two of them are plain functions, not widgets already
  /// holding profile state), so it reads its own copy here rather than
  /// threading `Avatar?` through four inconsistent call sites. Every call
  /// site already holds a `StorageService` instance for other reasons
  /// (confirmed by reading each one, not assumed), so this costs each of
  /// them one extra named argument, not a new dependency.
  final StorageService storageService;

  final AnalyticsService analyticsService;

  /// Which of `AnalyticsService`'s `paywallSource*` constants this visit
  /// came from — required, not optional with a guessed default: every
  /// real call site is one of exactly four known entry points (checked in
  /// Batch 0), so there is no "unknown" case worth silently falling back
  /// to.
  final String analyticsSource;

  /// Called when the user is done here — either they dismissed via "Maybe
  /// later," or a trial just started and they tapped "Continue" — right
  /// before this screen pops itself. Null (the default, for every entry
  /// point except the Day-0 flow) means there's nothing extra to do beyond
  /// the pop itself: Home's locked-card tap and its own Premium-row tap
  /// both just want to return to whatever pushed this screen.
  final VoidCallback? onDone;

  /// The weak spot that prompted this screen. It replaces the supporting
  /// sentence, keeping the main headline identical across entry points.
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

  // Computed once per screen visit (not per rebuild), the same reasoning
  // SettingsScreen's own `_fallbackAvatar` already uses: a legacy profile
  // with no avatar yet, or one carrying an id this build doesn't recognize
  // (Avatar.fromJson returns null either way), shouldn't show a different
  // random character on every unrelated rebuild — and per this batch's
  // own instruction, the hero never shows the generic placeholder at all,
  // so a real fallback avatar is picked up front rather than left null.
  late final Avatar _fallbackAvatar = Avatar.random();
  // Starts as the fallback, not null — the hero has a real avatar to show
  // from the very first frame, never a placeholder state while the async
  // storage read is in flight.
  late Avatar _userAvatar = _fallbackAvatar;

  // Set by _dismiss() (covers the X button, "Maybe later," and the
  // post-success "Continue" alike) before it *ever* triggers a pop —
  // PopScope's own observer below checks this to tell "this app's code
  // already accounted for the exit" apart from a system back gesture/
  // hardware back button, which is the one path that reaches a pop
  // without going through _dismiss() at all.
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
    if (!mounted) return;
    setState(() {
      _monthlyPackage = offering?.monthly;
      _annualPackage = offering?.annual;
      _loadingOffer = false;
    });
  }

  Future<void> _loadAvatar() async {
    UserProfile? profile;
    try {
      profile = await widget.storageService.getUserProfile();
    } catch (_) {
      // Fails open to the fallback avatar below — a hero visual is purely
      // decorative, never worth surfacing a storage error over.
    }
    if (!mounted) return;
    setState(() => _userAvatar = profile?.avatar ?? _fallbackAvatar);
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

  String get _selectedPlanAnalyticsId => switch (_selectedPeriod) {
        _PlanPeriod.monthly => AnalyticsService.planMonthly,
        _PlanPeriod.annual => AnalyticsService.planAnnual,
      };

  Future<void> _startTrial() async {
    final package = _selectedPackage;
    if (package == null) return;
    final plan = _selectedPlanAnalyticsId;
    widget.analyticsService.purchaseStarted(plan);
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
    final outcomeId = switch (outcome) {
      PurchaseOutcome.success => 'success',
      PurchaseOutcome.cancelled => 'cancelled',
      PurchaseOutcome.failure => 'error',
    };
    widget.analyticsService.purchaseResult(plan: plan, outcome: outcomeId);
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
  /// screen." [dismissMethod] is one of `AnalyticsService`'s
  /// `paywallDismiss*` constants for the first two (a real abandonment,
  /// worth logging), or null for "Continue" (a completed purchase, not a
  /// dismissal — already covered by [purchaseResult]). Sets [_exitHandled]
  /// unconditionally, before the pop, so the `PopScope` observer below
  /// never double-logs whichever path actually triggered this. Runs
  /// [PremiumScreen.onDone] first (e.g. the Day-0 flow's own
  /// onboarding-completion step) so its side effects are in flight before
  /// this route disappears, then pops.
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
        ? 'Practice the mistakes you actually make.'
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
    final width = MediaQuery.sizeOf(context).width;
    // Matches BrandScaffold's own responsive horizontal padding formula
    // (`body:` bypasses it — see that widget's doc comment — so this
    // screen owns its own padding, same as AvatarPickerScreen already
    // does for the same reason).
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    return PopScope(
      // Observes rather than blocks (canPop stays true): unlike
      // AvatarPickerScreen's own PopScope, there's no timing-sensitive
      // side effect that must run *before* the pop here — this only
      // needs to know, after the fact, whether the pop happened without
      // going through _dismiss() at all (a system back gesture/hardware
      // back button), the one path not already tagged with a dismiss
      // method at its own button.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop || _exitHandled) return;
        widget.analyticsService.paywallDismissed(
          source: widget.analyticsSource,
          method: AnalyticsService.paywallDismissSystemBack,
        );
      },
      child: BrandScaffold(
        title: const PageTitle('Premium'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => _dismiss(
              dismissMethod: AnalyticsService.paywallDismissCloseButton,
            ),
          ),
        ],
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 10),
                child: Column(
                  key: const Key('premiumBody'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AvatarHero(centerAvatar: _userAvatar),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock personalized feedback',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _supportingText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    _ComparisonTable(theme: theme, colorScheme: colorScheme),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        "What's free, trial, and paid",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        monthly: monthly,
                        annual: annual,
                        selected: _selectedPeriod,
                        onChanged: (period) =>
                            setState(() => _selectedPeriod = period),
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    const SizedBox(height: 16),
                    // Required by App Store guidelines for any screen that
                    // sells a subscription, regardless of whether pricing
                    // itself is currently available — always present, never
                    // gated on an offering existing.
                    Center(
                      child: TextButton(
                        // No explicit style: theme.dart's textButtonTheme
                        // now covers the orange-on-orange contrast fix this
                        // call site used to patch individually.
                        onPressed: _restoring ? null : _restore,
                        child: Text(
                            _restoring ? 'Restoring…' : 'Restore Purchases'),
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
                    const Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          LegalLink(
                            label: 'Privacy Policy',
                            url: AppLinks.privacyPolicyUrl,
                          ),
                          LegalLink(
                            label: 'Terms of Service',
                            url: AppLinks.termsUrl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _PremiumFooter(
              key: const Key('premiumFooter'),
              loading: _loadingOffer,
              offeringsReady: offeringsReady,
              purchaseState: _purchaseState,
              disclosureText:
                  offeringsReady ? _disclosureText(_selectedPackage!) : null,
              onStartTrial: _startTrial,
              onContinue: _dismiss,
              onMaybeLater: () => _dismiss(
                dismissMethod: AnalyticsService.paywallDismissMaybeLater,
              ),
              theme: theme,
              colorScheme: colorScheme,
              horizontalPadding: hPad,
            ),
          ],
        ),
      ),
    );
  }
}

/// Four avatars distinct from [center] and from each other, picked by a
/// fixed offset from its own index rather than [Avatar.random] — the same
/// visitor sees the same group every time they open this screen (no
/// re-roll on every rebuild), and it's trivially testable. Offsets (2, 4,
/// 6, 8 positions around the 12-avatar cycle) are spread out rather than
/// adjacent so the four don't cluster right next to the center avatar's
/// own asset-numbering neighborhood.
List<Avatar> _otherAvatarsFor(Avatar center) {
  const offsets = [2, 4, 6, 8];
  return offsets
      .map(
          (offset) => Avatar.values[(center.index - 1 + offset) % Avatar.count])
      .toList();
}

/// The hero visual (this batch): the user's own avatar front-and-center,
/// two or four smaller companions alongside — "here's your identity among the
/// set," not a feature illustration. Built from the existing [AvatarTile]
/// (transparent background + ground shadow already baked in, since the
/// ring-removal batch) with no [Hero] wrapper at all: this screen has no
/// push/pop partner to fly to, and wrapping these in `Hero` risked
/// colliding with Home's or Settings' own avatar Hero tags, both of which
/// stay mounted at the same time as this screen (see `home_screen.dart`'s
/// own `homeAvatarHeroTag` doc comment for why that would crash). [centerAvatar]
/// is never null by the time this builds — [_PremiumScreenState] resolves
/// a real fallback avatar before this is ever rendered, so there is no
/// placeholder state here to design for.
class _AvatarHero extends StatelessWidget {
  final Avatar centerAvatar;

  const _AvatarHero({required this.centerAvatar});

  @override
  Widget build(BuildContext context) {
    final others = _otherAvatarsFor(centerAvatar);
    // Keep the user's avatar prominent without fading or overlapping others.
    // Retain the 90pt hero height so entry-point layout stays consistent.
    const centerRadius = 38.0;
    const innerRadius = 26.0;
    const outerRadius = 21.0;
    const gap = 8.0;
    const fiveAvatarWidth =
        centerRadius * 2 + innerRadius * 4 + outerRadius * 4 + gap * 4;

    // One semantic node for the whole group, not five: the other four
    // avatars are purely decorative (nothing to tap, nothing individually
    // meaningful about *which* four they are), so exposing each one to a
    // screen reader would just be noise. The one thing worth announcing —
    // whose avatar this is — is stated directly instead.
    return Semantics(
      label: "Your avatar: ${centerAvatar.semanticLabel}",
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 90,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showOuterPair = constraints.maxWidth >= fiveAvatarWidth;
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showOuterPair) ...[
                        AvatarTile(avatar: others[0], radius: outerRadius),
                        const SizedBox(width: gap),
                      ],
                      AvatarTile(avatar: others[1], radius: innerRadius),
                      const SizedBox(width: gap),
                      AvatarTile(avatar: centerAvatar, radius: centerRadius),
                      const SizedBox(width: gap),
                      AvatarTile(avatar: others[2], radius: innerRadius),
                      if (showOuterPair) ...[
                        const SizedBox(width: gap),
                        AvatarTile(avatar: others[3], radius: outerRadius),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The App Store's required auto-renewable-subscription disclosure,
/// compressed to a single sentence (at most two lines once wrapped):
/// trial length, price + billing period after it, and that it auto-renews
/// unless cancelled. Reuses [_hyphenatedDuration] and
/// [_formatSubscriptionPeriod] so every number here still comes from
/// [package]'s own live StoreKit/RevenueCat data, never hardcoded.
String _disclosureText(Package package) {
  final product = package.storeProduct;
  final trial = product.introductoryPrice;
  String trialPart;
  if (trial == null) {
    trialPart = 'Free trial';
  } else {
    final (count, unit) = _trialDurationInDays(trial);
    trialPart = '${_hyphenatedDuration(count, unit)} free trial';
  }
  final billingPeriod = _formatSubscriptionPeriod(product.subscriptionPeriod);
  final priceStr = billingPeriod == null
      ? product.priceString
      : '${product.priceString} / $billingPeriod';
  return '$trialPart, then $priceStr, auto-renews unless cancelled.';
}

/// The screen's fixed bottom area — never scrolls away, unlike the
/// previous single-`ListView` layout. Content varies by state rather than
/// always showing the same three things:
///
/// - **loading**: a disabled CTA with an inline spinner (no disclosure —
///   there's no price yet to disclose) plus "Maybe later".
/// - **offerings ready**: the purchase status banner (nothing shown for
///   idle/purchasing, which already have their own affordance), the CTA
///   (label/enabled-state driven by [purchaseState]), the disclosure line,
///   and "Maybe later" — hidden once a trial has actually started, since
///   the CTA itself becomes "Continue" then and a second identical exit
///   would be redundant.
/// - **pricing unavailable**: *only* "Maybe later" — no CTA, no
///   disclosure, since neither means anything without a real price. The
///   retry affordance itself stays in the scrollable body
///   ([_UnavailableCard]), not duplicated here.
class _PremiumFooter extends StatelessWidget {
  final bool loading;
  final bool offeringsReady;
  final _PurchaseState purchaseState;
  final String? disclosureText;
  final VoidCallback onStartTrial;
  final VoidCallback onContinue;
  final VoidCallback onMaybeLater;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final double horizontalPadding;

  const _PremiumFooter({
    super.key,
    required this.loading,
    required this.offeringsReady,
    required this.purchaseState,
    required this.disclosureText,
    required this.onStartTrial,
    required this.onContinue,
    required this.onMaybeLater,
    required this.theme,
    required this.colorScheme,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final showCta = offeringsReady;
    final showMaybeLater = purchaseState != _PurchaseState.success;
    // The hard-edge separator below only earns its keep when there's
    // actual footer content above "Maybe later" for it to separate from
    // the scrollable body (the loading spinner or the loaded CTA). In the
    // pricing-unavailable state the footer is just "Maybe later" alone,
    // and the same line reads as a stray, orphaned rule sitting directly
    // above it rather than a section boundary — dropped for that state
    // only; the retry affordance itself already lives in the scrollable
    // body ([_UnavailableCard]), not duplicated here.
    final showTopBorder = loading || showCta;

    return DecoratedBox(
      // A hard edge (not a shadow/blur) between the scrollable content and
      // the fixed footer — the same "permanent, not scroll-triggered"
      // separation BrandScaffold's own band/body boundary already uses,
      // for the same reason: a shadow that only appears once scrolled
      // reads as a bug (looks fine at rest, gains an edge mid-scroll).
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: showTopBorder
            ? Border(top: BorderSide(color: colorScheme.outlineVariant))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (showCta) ...[
                _PurchaseStatusBanner(
                  state: purchaseState,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    // Once the trial has actually started, this button's
                    // job changes from "start it" to "acknowledge and move
                    // on" — reusing the same primary button for that
                    // rather than adding a separate one keeps a single,
                    // consistent continuation point regardless of outcome.
                    onPressed: switch (purchaseState) {
                      _PurchaseState.purchasing => null,
                      _PurchaseState.success => onContinue,
                      _ => onStartTrial,
                    },
                    child: purchaseState == _PurchaseState.purchasing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(purchaseState == _PurchaseState.success
                            ? 'Continue'
                            : 'Start free trial'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  disclosureText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
              ],
              if (showMaybeLater)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onMaybeLater,
                  child: const Text('Maybe later'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the Free/Premium comparison table. [freeLabel] overrides the
/// usual checkmark/dash with specific text (today, only "1 a day" for the
/// merged weak-spot row) — null everywhere else, meaning [free] alone
/// decides the glyph.
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

const TextStyle _freeValueStyle =
    TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

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

const TextStyle _headerStyle =
    TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
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

/// Two side-by-side selectable plan cards (PRD v2 §13.3). Annual is
/// preselected and carries the "Save N%" badge; both cards' prices come
/// from [_planPricing], called once per period.
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
    // Only two natural-height cards: measure the taller content, then stretch
    // both borders to it. No fixed height or vertical flex clips scaled text.
    return IntrinsicHeight(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    ));
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
    // Fill stays the plain card surface regardless of selection — visual-
    // polish batch, same date as this comment. It used to switch to
    // `secondaryContainer` when selected, the same fill the comparison
    // table's Premium strip uses a few rows above; next to that strip a
    // selected card and "this is the Premium column" read as the same
    // signal. Selection is carried entirely by the 2px `secondary` border
    // (unchanged) plus an explicit check mark below, so it no longer
    // borrows a color language that means something else on this screen.
    final borderColor =
        selected ? colorScheme.secondary : colorScheme.outlineVariant;
    final savings = pricing.savingsLabel;
    final borderWidth = selected ? 2.0 : 1.0;

    return Semantics(
      key: ValueKey('planCard_$label'),
      button: true,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label: '$label plan, ${pricing.bigAmount}, ${pricing.smallDetail}'
          '${savings != null ? ', $savings' : ''}',
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            // Decoration contributes the border to padding. Keep the total
            // inset stable when selection switches between the two plans.
            padding: EdgeInsets.symmetric(
                horizontal: 14 - borderWidth, vertical: 12 - borderWidth),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (savings != null) ...[
                      _Badge(label: savings),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pricing.bigAmount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pricing.smallDetail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.secondary,
                    ),
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
/// fields — never a hardcoded number.
///
/// The annual plan's monthly-equivalent price ([StoreProduct.pricePerMonth]/
/// [StoreProduct.pricePerMonthString]) is computed and formatted by
/// RevenueCat/StoreKit itself from the real annual price, already in the
/// viewer's own currency — this reads that directly rather than
/// reimplementing currency formatting by hand (which risks assuming a
/// "$" prefix that breaks for every other currency).
///
/// The savings percentage deliberately does **not** reuse [pricePerMonth]
/// for its own math (found live on-device, 2026-09-17): StoreKit truncates
/// that figure to 2 decimals for display (49.99/12 = 4.1658... → "4.16"),
/// and computing the percentage from the truncated number overstated the
/// real 30.44% saving as 31%. The percentage below instead compares the
/// two products' own raw [StoreProduct.price] values directly (annual vs.
/// 12 × monthly) — full precision, no intermediate rounding — and floors
/// rather than rounds, so display rounding can never overstate a discount
/// the user isn't actually getting.
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
    final yearlyIfMonthly = monthlyProduct.price * 12;
    final savings =
        (yearlyIfMonthly - annualProduct.price) / yearlyIfMonthly * 100;
    if (savings > 0) savingsLabel = 'Save ${savings.floor()}%';
  }

  return _PlanPricing(
    bigAmount: '$perMonthString / month',
    smallDetail: 'Billed ${annualProduct.priceString} annually.',
    savingsLabel: savingsLabel,
  );
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

  static const _message = "Trial pricing isn't available right now";

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(height: 14, width: 56),
            const SizedBox(height: 10),
            _bar(height: 20, width: 84),
            const SizedBox(height: 6),
            _bar(height: 12, width: 104),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading pricing',
      child: Row(
        children: [
          Expanded(child: _card()),
          const SizedBox(width: 12),
          Expanded(child: _card()),
        ],
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
