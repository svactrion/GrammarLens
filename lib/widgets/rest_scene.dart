import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../utils/content_width.dart';
import '../utils/haptics.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'floating_nav_shell.dart';
import 'step_bar.dart';
import 'ticket.dart';
import 'pressable_button.dart';
import 'monthly_climb/climb_route.dart';
import 'monthly_climb/climb_trail_table.dart';
import 'monthly_climb/mountain_scene.dart';
import 'speech_bubble.dart';
import '../utils/upper_case.dart';

/// The time left until local midnight (the next Daily Test, the next free
/// ticket).
Duration timeToMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

/// The rest scene (V24, SPEC §1.8): replaces Home's content once every daily
/// right is used. The camp at the companion's own step — the tent behind,
/// the companion asleep, the campfire at its front right on the same
/// ground with a warm glow under it — over the month's mountain, and the
/// night panel under it, ending with the "Remind me tomorrow" row
/// ([reminder], TASK-widgets fixed decision 7).
///
/// V24 (Premium, its own board again in fix round 5, SPEC V24 v13) keeps
/// "See you tomorrow, <name>", the speech bubble and the Zzz; its panel has
/// the title with "Your buddy is resting until tomorrow.", the two done
/// tiles and the "Next Daily Test · step N" card with its step bar and the
/// countdown (local midnight, updated every minute). V24f (free, SPEC
/// §1.15) has the dream bubble, and its panel is the ticket deck (v13):
/// the title, today's free ticket used (with the time to the next one) and
/// the Premium card ([offer]). Both panels fit their content and end just
/// above the nav bar; the scene fills the rest ([designSheetTop]).
class RestScene extends StatefulWidget {
  final ClimbTheme theme;
  final int days;
  final int steps;
  final Avatar hero;
  final String name;

  /// V24's two done tiles: the Daily Test's line ("4/5 · +9 points") and
  /// the practice's ("5/5 sessions"). V24f does not show them.
  final String testLine;
  final String practiceLine;

  /// The score capsule, top right over the scene.
  final Widget? capsule;

  /// The "Remind me tomorrow" row (TASK-widgets fixed decision 7), the
  /// sheet's last row in both scenes; none in previews.
  final Widget? reminder;
  final DateTime Function() clock;

  /// V24f (free users, SPEC §1.15): the dream bubble and the Premium card
  /// with "Wake <Hero> up". Null for Premium users, who keep V24.
  final RestOffer? offer;

  const RestScene({
    super.key,
    required this.theme,
    required this.days,
    required this.steps,
    required this.hero,
    required this.name,
    required this.testLine,
    required this.practiceLine,
    required this.clock,
    this.capsule,
    this.reminder,
    this.offer,
  });

  /// The boards' width; the scene's sizes follow the screen's width.
  static const boardWidth = 390.0;

  /// V24f's dream bubble's width at 390 pt (the board's 216).
  static const dreamWidth = 216.0;

  /// The art is drawn at the boards' scale (600 px of art over a 390 pt
  /// board, so 600 / 390 of the screen width) and is never scaled up.
  static const artWidthShare = 600 / 390;

  /// The boards' sheet top below the safe area at 390 pt wide (V24f v13:
  /// 314 on its 844 pt screen, 47 pt of status bar; V24: 466), scaled with
  /// the width: the first frame's guess only. Fix round 5 (SPEC V24f v13
  /// "Panel", V24 v13): the panel fits its content and ends just above the
  /// nav bar ([anchorClearance]), so the sheet's top is fitted after layout
  /// and the scene fills the rest — no empty band under the reminder row.
  static const designSheetTop = 267.0;
  static const designSheetTopPremium = 419.0;

  /// V24's own board: the companion's top at 254 on its 844 pt screen.
  static const bandAboveCampPremium = 207.0;

  /// The boards' band from the safe area's top to the companion's top
  /// (174 − 47 at 390 wide): the dream bubble with its dots (V24f), the
  /// "See you tomorrow" chip and the speech bubble (V24), the capsule.
  static const bandAboveCamp = 127.0;

  /// The least band kept for them when the sheet needs room: the scene is
  /// cropped from the top down to this (fix round 3's rule).
  static const topBand = 100.0;

  /// The camp (tent, companion, fire) stays fully visible at least this far
  /// above the sheet.
  static const minCampGap = 12.0;

  /// The sheet's top corner radius; the scene runs this far under it.
  static const sheetRadius = 28.0;

  /// The panel's rows: its top padding and the gap between rows (both
  /// boards).
  static const panelTop = 16.0;
  static const rowGap = 12.0;

  /// On Home's first view, the reminder row (the sheet's last row) stays
  /// this far above the floating nav bar wherever the camp leaves room for
  /// it; the page then has no scroll extent.
  static const anchorClearance = 8.0;

  /// The companion's size in the scene's image units (84 pt at 390 wide on
  /// the board), times k = the art's scale / 900.
  static const companionUnits = 126.0;

  /// The companion's left edge from its step, in image units × k: its
  /// feet stand on the step, a little left of it, so the camp to its right
  /// (tent, fire) stays on the trail's ground.
  static const companionLeftUnits = 78.0;

  /// The camp's centre right of the step, in image units × k: the camera
  /// centres it across the screen.
  static const campCentreUnits = 18.0;

  /// Shares of the companion's size S, from the v12 board and the images:
  /// the feet (the boards' `transform-origin: 50% 92%`; fox_sleep's lowest
  /// pixel is at 0.897 of its box), the tent (80 × 65 at 48, 2 from the
  /// companion's box at S = 84), the fire's box (56 × 66, its left 72 from
  /// the companion's) and the camp's height, the companion's top to the
  /// fire's foot (the logs image's lowest pixels, the stones in front).
  static const feetShare = .9;
  static const tentLeftShare = 48 / 84;
  static const tentTopShare = 2 / 84;
  static const tentWidthShare = 80 / 84;
  static const tentHeightShare = 65 / 84;
  static const fireLeftShare = 72 / 84;
  static const fireWidthShare = 56 / 84;
  static const fireHeightShare = 66 / 84;
  static const campHeightShare = feetShare + Campfire.pileBaseFromFoot;

  static const sceneKey = ValueKey('rest_scene_layer');
  static const sheetKey = ValueKey('rest_sheet');
  static const headerKey = ValueKey('rest_header');
  static const campGlowKey = ValueKey('rest_camp_glow');

  static const usedTicketKey = ValueKey('rest_used_ticket');
  static const deckKey = ValueKey('rest_deck');
  static const doneTilesKey = ValueKey('rest_done_tiles');
  static const nextTestKey = ValueKey('rest_next_test');

  static const dreamKey = ValueKey('rest_dream');
  static const awakeBubbleKey = ValueKey('rest_awake_bubble');
  static const premiumCardKey = ValueKey('rest_premium_card');
  static const wakeKey = ValueKey('rest_wake');
  static const seeYouKey = ValueKey('rest_see_you');

  /// V24s: how long the wake-up plays before the paywall rises (after the
  /// deck has gathered, [TicketDeck.gather]).
  static const wakeLead = Duration(milliseconds: 600);

  @override
  State<RestScene> createState() => _RestSceneState();
}

class _RestSceneState extends State<RestScene>
    with SingleTickerProviderStateMixin {
  Timer? _minute;

  /// Where the night sheet starts on the page (the scene's visible
  /// height), fitted after layout; null until the first fit (the design
  /// top is drawn first).
  double? _sheetTop;
  double _minSheetTop = 0;
  double _designSheetTop = 0;
  double? _navClearance;
  final _sheetBoxKey = GlobalKey();
  final _endKey = GlobalKey();

  /// v13: fits [_sheetTop] so the panel's last row (the reminder row) ends
  /// [RestScene.anchorClearance] above the floating nav bar on the first
  /// view (or the safe area's bottom where there is no bar): the panel fits
  /// its content and the scene fills the rest, never so high that the camp
  /// would not fit ([_minSheetTop]; the page then scrolls).
  void _fitSheet() {
    if (!mounted) return;
    final sheet = _sheetBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = _endKey.currentContext?.findRenderObject() as RenderBox?;
    if (sheet == null ||
        anchor == null ||
        !sheet.attached ||
        !anchor.attached ||
        !sheet.hasSize ||
        !anchor.hasSize) {
      return;
    }
    final anchorBottom =
        anchor.localToGlobal(Offset(0, anchor.size.height), ancestor: sheet).dy;
    final barTop = _barTop(MediaQuery.of(context));
    final fits = barTop - RestScene.anchorClearance - anchorBottom;
    final top = math.max(_minSheetTop, fits);
    if (_sheetTop == null || (top - _sheetTop!).abs() > .5) {
      setState(() => _sheetTop = top);
    }
  }

  /// The floating nav bar's top on the screen.
  double _barTop(MediaQueryData media) {
    final clearance = _navClearance;
    return clearance == null
        ? media.size.height - media.padding.bottom - 16
        : media.size.height - (clearance - NavBarClearance.gap);
  }

  /// V24s: "Wake <Hero> up" was tapped: the companion is awake while the
  /// paywall is open; it falls asleep again when the paywall closes.
  bool _awake = false;

  /// v13: on Wake the deck first gathers into its front ticket (150 ms).
  bool _gathered = false;

  /// The wake-up hop (one, 500 ms).
  late final AnimationController _hop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  Future<void> _wake() async {
    final offer = widget.offer;
    if (offer == null || _awake || _gathered) return;
    // v13: the deck gathers into the front ticket, the companion wakes,
    // then the paywall rises (V13r).
    setState(() => _gathered = true);
    await Future<void>.delayed(AppMotion.orInstant(context, TicketDeck.gather));
    if (!mounted) return;
    setState(() => _awake = true);
    if (!AppMotion.reduced(context)) {
      HapticMap.light();
      unawaited(_hop.forward(from: 0));
    }
    await Future<void>.delayed(
        AppMotion.orInstant(context, RestScene.wakeLead));
    if (!mounted) return;
    await offer.onWake();
    if (mounted) {
      setState(() {
        _awake = false;
        _gathered = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final left = timeToMidnight(widget.clock());
    final hh = left.inHours.toString().padLeft(2, '0');
    final mm = (left.inMinutes % 60).toString().padLeft(2, '0');
    final days = widget.days.clamp(28, 31);
    final step = widget.steps.clamp(0, days);
    final offer = widget.offer;
    _navClearance =
        context.dependOnInheritedWidgetOfExactType<NavBarClearance>()?.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitSheet());
    final step0 = ClimbRoute(days).stepAt(step);
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const onPanel = Colors.white;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final u = width / RestScene.boardWidth;
      // The boards' scale, whatever the scene's height.
      final scale = width * RestScene.artWidthShare;
      final k = scale / 900;
      final s = RestScene.companionUnits * k;
      final campHeight = RestScene.campHeightShare * s;
      final minTop =
          safeTop + RestScene.topBand + campHeight + RestScene.minCampGap;
      _minSheetTop = minTop;
      final premium = offer == null;
      _designSheetTop = math.max(
          minTop,
          safeTop +
              (premium
                      ? RestScene.designSheetTopPremium
                      : RestScene.designSheetTop) *
                  u);
      final sheetTop = math.max(minTop, _sheetTop ?? _designSheetTop);
      final sceneHeight = sheetTop + RestScene.sheetRadius;
      // The camp: its top where the board has it, under the bubble band;
      // when the sheet rises, the gap under the camp shrinks to 12 first,
      // then the camp moves up with it (the scene cropped from the top).
      // v13: the art is never scaled and the sheet never starts below its
      // lower edge: where the fitted sheet sits lower than the art reaches
      // under the camp (early in the month on tall screens), the camp and
      // the art move down together.
      final artBelowStep = scale / climbImageAspect - step0.dy * scale;
      final campTop = math.max(
          math.max(
              safeTop + RestScene.topBand,
              math.min(
                  safeTop +
                      (premium
                              ? RestScene.bandAboveCampPremium
                              : RestScene.bandAboveCamp) *
                          u,
                  sheetTop - RestScene.minCampGap - campHeight)),
          sceneHeight - artBelowStep - RestScene.feetShare * s);
      final feetY = campTop + RestScene.feetShare * s;
      // The camera: the camp's centre across the middle, the companion's
      // feet at [feetY]. High on the mountain (late in the month) the art's
      // top edge would come into view: the art then starts lower and its
      // sky is continued above it by a mirrored copy ([pad]).
      final wantedOriginY = feetY - step0.dy * scale;
      final pad = math.max(0.0, wantedOriginY);
      final artBox = Size(width, sceneHeight - pad);
      final cover = math.max(width, artBox.height * climbImageAspect);
      final zoom = math.max(1.0001, scale / cover);
      final focus = Offset(step0.dx + RestScene.campCentreUnits / 900,
          (artBox.height / 2 - (wantedOriginY - pad)) / scale);
      final map = SceneMap(artBox, zoom: zoom, focus: focus);
      final stepAt = map.toBox(step0) + Offset(0, pad);
      final compLeft = stepAt.dx - RestScene.companionLeftUnits * k;
      final compTop = stepAt.dy - RestScene.feetShare * s;
      final feet = compTop + RestScene.feetShare * s;
      final fireLeft = compLeft + RestScene.fireLeftShare * s;
      final fireWidth = RestScene.fireWidthShare * s;
      final fireHeight = RestScene.fireHeightShare * s;
      final fireBottom = compTop + campHeight;
      final glowWidth = 140 / 84 * s;
      final glowHeight = 74 / 84 * s;
      final brightness = theme.brightness;
      final sheetPad = ContentWidth.sidePaddingOf(context);
      final clearance = _navClearance;
      final bottomPad = clearance == null
          ? media.padding.bottom + 16
          : clearance - NavBarClearance.gap + RestScene.anchorClearance;

      // V24f: the dream bubble (or, while waking, "I'm awake!"); V24: the
      // speech bubble. Its foot at the companion's head, its top never
      // under the status bar (nor, on V24, under the "See you" chip).
      final Widget? bubble = offer == null
          ? SpeechBubble(
              text: l10n.restBubble,
              pointer: BubblePointer.bottomStart,
              compact: true,
            )
          : _awake
              ? SpeechBubble(
                  key: RestScene.awakeBubbleKey,
                  text: l10n.restAwake,
                  pointer: BubblePointer.bottomStart,
                  compact: true,
                )
              : offer.weakSpot == null
                  ? null
                  : _DreamBubble(
                      key: RestScene.dreamKey,
                      hero: widget.hero.name(l10n),
                      spot: offer.weakSpot!);
      // V24's bubble ends above the Zzz; the dream's dots reach the head.
      final bubbleFoot = offer == null ? compTop - .2 * s : compTop + .1 * s;
      final bubbleStart =
          offer == null ? math.max(16.0, compLeft - 50 * k) : 16.0 * u;
      final bubbleMinTop = offer == null ? safeTop + 12 + 40 : safeTop + 8;

      return Stack(
        children: [
          Positioned(
            key: RestScene.sceneKey,
            left: 0,
            right: 0,
            top: 0,
            height: sceneHeight,
            child: ClipRect(
              child: Stack(
                children: [
                  if (pad > 0)
                    // The art's sky continued upwards: the art's top,
                    // mirrored (its edge rows meet without a seam).
                    Positioned(
                      left: map.origin.dx,
                      top: pad - map.imageSize.height,
                      width: map.imageSize.width,
                      height: map.imageSize.height,
                      child: Transform.flip(
                        flipY: true,
                        child: Image.asset(
                            widget.theme.backgroundFor(brightness),
                            fit: BoxFit.fill,
                            excludeFromSemantics: true),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: pad,
                    height: artBox.height,
                    child: MountainScene(
                      theme: widget.theme,
                      days: days,
                      showFlag: false,
                      zoom: zoom,
                      focus: focus,
                    ),
                  ),
                  // The status bar's shade (the board's 120 pt gradient).
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 120 * u,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.sceneTopShade,
                              Color(0x00000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The warm light on the ground, under the camp.
                  Positioned(
                    key: RestScene.campGlowKey,
                    left: fireLeft + fireWidth / 2 - glowWidth / 2,
                    top: feet - glowHeight / 2,
                    width: glowWidth,
                    height: glowHeight,
                    child: const CampGlow(),
                  ),
                  // The tent behind the companion.
                  Positioned(
                    left: compLeft + RestScene.tentLeftShare * s,
                    top: compTop + RestScene.tentTopShare * s,
                    width: RestScene.tentWidthShare * s,
                    height: RestScene.tentHeightShare * s,
                    child: Image.asset('assets/climb/objects/tent.webp',
                        fit: BoxFit.contain, excludeFromSemantics: true),
                  ),
                  // The companion asleep at its step.
                  Positioned(
                    left: compLeft,
                    top: compTop,
                    width: s,
                    height: s,
                    child: AnimatedBuilder(
                      animation: _hop,
                      builder: (context, child) => Transform.translate(
                          offset: Offset(
                              0, -16 * k * math.sin(math.pi * _hop.value)),
                          child: child),
                      child: CompanionView(
                          hero: widget.hero,
                          mood:
                              _awake ? CompanionMood.wave : CompanionMood.sleep,
                          // V24f: a dream bubble instead of the Zzz.
                          showProp: offer == null,
                          poseSwitch: _awake
                              ? const Duration(milliseconds: 200)
                              : const Duration(milliseconds: 400),
                          size: s),
                    ),
                  ),
                  // The campfire at its front right, on the same ground.
                  Positioned(
                    left: fireLeft,
                    top: fireBottom - fireHeight,
                    width: fireWidth,
                    height: fireHeight,
                    // V24s: the fire grows as the companion wakes.
                    child: AnimatedScale(
                      scale: _awake ? 1.25 : 1,
                      alignment: Alignment.bottomCenter,
                      duration: AppMotion.orInstant(
                          context, const Duration(milliseconds: 300)),
                      curve: AppMotion.pop,
                      child: const Campfire(),
                    ),
                  ),
                  if (bubble != null)
                    Positioned.fill(
                      child: CustomSingleChildLayout(
                        delegate: _AboveHead(
                          foot: bubbleFoot,
                          minTop: bubbleMinTop,
                          start: bubbleStart,
                          maxWidth: math.min(width - bubbleStart - 16,
                              offer == null ? 230.0 : RestScene.dreamWidth * u),
                          rtl: rtl,
                        ),
                        child: AnimatedSwitcher(
                          duration:
                              AppMotion.orInstant(context, AppMotion.base),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: AlignmentDirectional.bottomStart,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          child: bubble,
                        ),
                      ),
                    ),
                  if (offer == null)
                    PositionedDirectional(
                      key: RestScene.seeYouKey,
                      start: 16,
                      top: safeTop + 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.nightTop.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.restSeeYou(widget.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge!
                              .withWeight(FontWeight.w800)
                              .copyWith(color: onPanel),
                        ),
                      ),
                    ),
                  if (widget.capsule != null)
                    PositionedDirectional(
                        end: 16, top: safeTop + 8, child: widget.capsule!),
                ],
              ),
            ),
          ),
          // The night panel, attached under the scene (no gap, rounded top
          // corners), down to the bottom of the page; V24f's slides up
          // 300 ms after the scene.
          Padding(
            padding: EdgeInsets.only(top: sheetTop),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: math.max(0.0, media.size.height - sheetTop)),
              child: _SlideUp(
                enabled: !premium,
                child: DecoratedBox(
                  key: RestScene.sheetKey,
                  decoration: const BoxDecoration(
                    color: AppColors.restPanel,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(RestScene.sheetRadius)),
                  ),
                  child: Padding(
                    key: _sheetBoxKey,
                    padding: EdgeInsets.fromLTRB(sheetPad, RestScene.panelTop,
                        sheetPad, math.max(0.0, bottomPad)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (offer == null) ...[
                          const _PanelTitle(
                              key: RestScene.headerKey, premium: true),
                          const SizedBox(height: RestScene.rowGap),
                          Row(
                            key: RestScene.doneTilesKey,
                            children: [
                              Expanded(
                                  child: _DoneTile(
                                      title: l10n.featureDailyTest,
                                      line: widget.testLine)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _DoneTile(
                                      title: l10n.restPracticeTitle,
                                      line: widget.practiceLine)),
                            ],
                          ),
                          const SizedBox(height: RestScene.rowGap),
                          _NextTestCard(
                            key: RestScene.nextTestKey,
                            step: step,
                            countdown: '$hh:$mm',
                            semantics: l10n.restCountdownSemantics(
                                left.inHours, left.inMinutes % 60),
                          ),
                        ] else ...[
                          const _PanelTitle(
                              key: RestScene.headerKey, premium: false),
                          const SizedBox(height: RestScene.rowGap),
                          _UsedTicketRow(nextIn: left),
                          const SizedBox(height: RestScene.rowGap),
                          _FreePanel(
                            offer: offer,
                            hero: widget.hero,
                            awake: _awake,
                            gathered: _gathered,
                            onWake: _wake,
                          ),
                        ],
                        if (widget.reminder != null) ...[
                          const SizedBox(height: RestScene.rowGap),
                          widget.reminder!,
                        ],
                        SizedBox(key: _endKey, height: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// V24f v13: the panel slides up 24 pt as it fades in, 300 ms after the
/// scene; at once under Reduce Motion (and for V24, [enabled] false).
class _SlideUp extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const _SlideUp({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled || AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300) + AppMotion.slow,
      curve: const Interval(.43, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Opacity(opacity: .4 + .6 * t, child: child)),
      child: child,
    );
  }
}

/// Places a bubble with its foot at [foot] (its top never above [minTop])
/// and its start edge at [start] from the start side.
class _AboveHead extends SingleChildLayoutDelegate {
  final double foot;
  final double minTop;
  final double start;
  final double maxWidth;
  final bool rtl;
  const _AboveHead(
      {required this.foot,
      required this.minTop,
      required this.start,
      required this.maxWidth,
      required this.rtl});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0.0, maxWidth));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = rtl ? size.width - start - childSize.width : start;
    final y = math.max(minTop, foot - childSize.height);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_AboveHead old) =>
      old.foot != foot ||
      old.minTop != minTop ||
      old.start != start ||
      old.maxWidth != maxWidth ||
      old.rtl != rtl;
}

/// The panel's title: the moon and "All done for today" (V24f v13); V24
/// adds "Your buddy is resting until tomorrow." under it ([premium]).
class _PanelTitle extends StatelessWidget {
  final bool premium;
  const _PanelTitle({super.key, required this.premium});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const onPanel = Colors.white;
    final title = Text(l10n.restTitle,
        style: (premium
                ? theme.textTheme.titleLarge!
                : theme.textTheme.titleMedium!)
            .withWeight(FontWeight.w900)
            .copyWith(color: onPanel, height: 1.1));
    return Row(
      crossAxisAlignment:
          premium ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Icon(Icons.nightlight_round, color: c.gold, size: premium ? 22 : 20),
        SizedBox(width: premium ? 10 : 8),
        Expanded(
          child: premium
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 2),
                    Text(l10n.restBody,
                        style: theme.textTheme.bodySmall!
                            .withWeight(FontWeight.w600)
                            .copyWith(
                                color: AppColors.restPanelMuted, height: 1.4)),
                  ],
                )
              : title,
        ),
      ],
    );
  }
}

/// V24: a done tile (a green tick, the title and its line).
class _DoneTile extends StatelessWidget {
  final String title;
  final String line;
  const _DoneTile({required this.title, required this.line});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: Colors.white)),
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium!
                      .withWeight(FontWeight.w600)
                      .copyWith(color: AppColors.restPanelMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// V24: "NEXT DAILY TEST · STEP N" over the month's step bar (ten
/// segments, this round of ten filled in gold) and the countdown to local
/// midnight on the right.
class _NextTestCard extends StatelessWidget {
  final int step;
  final String countdown;
  final String semantics;
  const _NextTestCard({
    super.key,
    required this.step,
    required this.countdown,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filled = step % 10 == 0 && step > 0 ? 10 : step % 10;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(upperCaseFor(context, l10n.restNextTest(step + 1)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium!
                      .withWeight(FontWeight.w800)
                      .copyWith(
                          color: AppColors.restPanelMuted, letterSpacing: .6)),
              const SizedBox(height: 6),
              StepBar(
                segments: [
                  for (var i = 0; i < 10; i++) i < filled ? c.gold : null,
                ],
                track: Colors.white.withValues(alpha: .15),
                height: 6,
                gap: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: semantics,
          excludeSemantics: true,
          child: Text(
            countdown, // l10n-guard: a time span of numbers
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.headlineSmall!
                .withWeight(FontWeight.w900)
                .copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ]),
    );
  }
}

/// V24f v13: today's free ticket, used (X04's small used ticket with the
/// time to the next one), and beside it "Today's free ticket is used." and,
/// in white, "Not sleepy yet?".
class _UsedTicketRow extends StatelessWidget {
  final Duration nextIn;
  const _UsedTicketRow({required this.nextIn});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(children: [
      MiniUsedTicket(key: RestScene.usedTicketKey, nextIn: nextIn),
      const SizedBox(width: 12),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: l10n.restTodaysTicketUsed),
            const TextSpan(text: '\n'),
            TextSpan(
                text: l10n.restNotSleepy,
                style: theme.textTheme.bodySmall!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: Colors.white)),
          ]),
          style: theme.textTheme.bodySmall!
              .withWeight(FontWeight.w700)
              .copyWith(color: AppColors.restPanelMuted, height: 1.35),
        ),
      ),
    ]);
  }
}

/// The warm light on the ground under the camp (the board's 140 × 74
/// glow at S = 84): breathes 1.6 s (`gl-glowpulse`), still under Reduce
/// Motion.
class CampGlow extends StatefulWidget {
  const CampGlow({super.key});

  @override
  State<CampGlow> createState() => _CampGlowState();
}

class _CampGlowState extends State<CampGlow>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _t == null) {
      _t = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget glow(double p) {
      final wave = (1 - math.cos(2 * math.pi * p)) / 2;
      return Opacity(
        opacity: .55 + .3 * wave,
        child: Transform.scale(
          scale: 1 + .08 * wave,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.fireGround,
                Color(0x00FFAA3C),
              ]),
            ),
          ),
        ),
      );
    }

    final t = _t;
    return IgnorePointer(
      child: ExcludeSemantics(
        // An oval: the circle stretched to the box.
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.square(
            dimension: 100,
            child: t == null
                ? glow(0)
                : AnimatedBuilder(
                    animation: t, builder: (context, _) => glow(t.value)),
          ),
        ),
      ),
    );
  }
}

/// The campfire (V24f v12): the logs image (logs on a ring of stones) with
/// the flame standing in the middle of the pile — two layers, an orange
/// one (yellow at its heart, red at its rim, a soft orange halo) and a pale
/// yellow one inside, flickering in opposite phase (`gl-flame`, 0.5 s and
/// 0.38 s) — and three sparks rising (1.4 s). Its box is the board's
/// 56 × 66: the flame is about 40 % of the companion's height. Still under
/// Reduce Motion.
class Campfire extends StatefulWidget {
  const Campfire({super.key});

  /// The board's box and its parts (px at S = 84).
  static const boxWidth = 56.0;
  static const boxHeight = 66.0;
  static const logsLeft = 2.0;
  static const logsWidth = 52.0;
  static const logsHeight = 39.0;

  /// The log pile's lowest pixel in `campfire_logs.webp` (270 of 384 rows;
  /// measured on its saturated pixels): the logs' base, which stands on
  /// the companion's foot line. The stones' ring reaches lower, in front.
  static const pileBase = 270 / 384;

  /// From the companion's feet to the fire box's foot, a share of S.
  static const pileBaseFromFoot = logsHeight * (1 - pileBase) / 84;

  /// The flame: its base (the pile's middle) above the box's foot, its
  /// size; the flame is 40 % of the companion's height (SPEC v12).
  static const flameBase = 18.0;
  static const flameWidth = 26.0;
  static const flameHeight = .4 * 84;
  static const heartBase = 20.0;
  static const heartWidth = 12.0;
  static const heartHeight = 18.0;

  @override
  State<Campfire> createState() => _CampfireState();
}

class _CampfireState extends State<Campfire>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _t == null) {
      // One clock for every layer: 5.6 s holds whole cycles of each (0.5,
      // 0.38 ≈ 5.6 / 15 and 1.4).
      _t = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 5600))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint(double seconds) => LayoutBuilder(
          builder: (context, box) {
            final x = box.maxWidth / Campfire.boxWidth;
            final y = box.maxHeight / Campfire.boxHeight;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: Campfire.logsLeft * x,
                bottom: 0,
                width: Campfire.logsWidth * x,
                height: Campfire.logsHeight * y,
                child: Image.asset('assets/ui/campfire_logs.webp',
                    fit: BoxFit.contain, excludeFromSemantics: true),
              ),
              Positioned.fill(
                child: CustomPaint(
                    painter: _FlamePainter(seconds: seconds, x: x, y: y)),
              ),
            ]);
          },
        );
    final t = _t;
    return ExcludeSemantics(
      child: t == null
          ? paint(0)
          : AnimatedBuilder(
              animation: t, builder: (context, _) => paint(t.value * 5.6)),
    );
  }
}

/// The flame's two layers and the sparks, in the board's 56 × 66 box
/// scaled by [x] and [y].
class _FlamePainter extends CustomPainter {
  final double seconds;
  final double x;
  final double y;
  _FlamePainter({required this.seconds, required this.x, required this.y});

  /// `gl-flame` at phase [p]: scaleY 1 → 1.12 → .92 → 1 and scaleX
  /// 1 → .94 → 1.05 → 1 (at 30 % and 60 %).
  static (double, double) _flicker(double p) {
    double lerp(double a, double b, double t) => a + (b - a) * t;
    if (p < .3) {
      final t = p / .3;
      return (lerp(1, .94, t), lerp(1, 1.12, t));
    }
    if (p < .6) {
      final t = (p - .3) / .3;
      return (lerp(.94, 1.05, t), lerp(1.12, .92, t));
    }
    final t = (p - .6) / .4;
    return (lerp(1.05, 1, t), lerp(.92, 1, t));
  }

  /// The board's flame shape: rounded, fuller at the foot
  /// (`border-radius: 50% 50% 42% 42% / 60% 60% 40% 40%`).
  static RRect _shape(Rect r) => RRect.fromRectAndCorners(r,
      topLeft: Radius.elliptical(r.width * .5, r.height * .6),
      topRight: Radius.elliptical(r.width * .5, r.height * .6),
      bottomLeft: Radius.elliptical(r.width * .42, r.height * .4),
      bottomRight: Radius.elliptical(r.width * .42, r.height * .4));

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // The outer flame.
    final (ax, ay) = _flicker((seconds / .5) % 1.0);
    final ow = Campfire.flameWidth * x * ax;
    final oh = Campfire.flameHeight * y * ay;
    final ob = size.height - Campfire.flameBase * y;
    final outer = Rect.fromLTWH(cx - ow / 2, ob - oh, ow, oh);
    canvas.drawRRect(
        _shape(outer),
        Paint()
          ..color = AppColors.fireHalo
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * x));
    canvas.drawRRect(
        _shape(outer),
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, .5),
            radius: 1.15,
            colors: [AppColors.fireCore, AppColors.fireMid, AppColors.fireRim],
            stops: [0, .45, 1],
          ).createShader(outer));
    // The heart, in the opposite phase.
    final (bx, by) = _flicker(1 - (seconds / .38) % 1.0);
    final hw = Campfire.heartWidth * x * bx;
    final hh = Campfire.heartHeight * y * by;
    final hb = size.height - Campfire.heartBase * y;
    canvas.drawOval(Rect.fromLTWH(cx - hw / 2, hb - hh, hw, hh),
        Paint()..color = AppColors.fireHeart);
    // Three sparks (`gl-zz2`, 1.4 s, 0.45 s apart).
    for (var i = 0; i < 3; i++) {
      final p = ((seconds - i * .45) / 1.4) % 1.0;
      final opacity = p < .3 ? p / .3 : 1 - (p - .3) / .7;
      final r = 1.5 * x * (.6 + .5 * p);
      final at = Offset(
          (21.5 + 7 * i + 14 * p) * x, size.height - (51.5 + 30 * p) * y);
      canvas.drawCircle(
          at,
          r,
          Paint()
            ..color =
                AppColors.fireSpark.withValues(alpha: opacity.clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.seconds != seconds || old.x != x || old.y != y;
}

/// V24f's offer (SPEC §1.15): what the free users' rest scene says and does.
class RestOffer {
  /// Today's weak spot (topic names stay English), or null: no dream
  /// bubble, and the card names the topics instead.
  final String? weakSpot;

  /// The store's free trial on the paywall's preselected plan, in days, or
  /// null (the button then promises none).
  final int? trialDays;

  /// The real number of practice topics (the fallback line counts them).
  final int topics;

  /// Opens the paywall (V13r); completes when it has closed.
  final Future<void> Function() onWake;

  const RestOffer({
    required this.weakSpot,
    required this.trialDays,
    required this.topics,
    required this.onWake,
  });
}

/// V24f: "<HERO> IS DREAMING OF…", today's weak spot and "today's weak
/// spot", with three small cloud dots from the head (200 ms apart); the
/// bubble floats (3.2 s).
class _DreamBubble extends StatefulWidget {
  final String hero;
  final String spot;
  const _DreamBubble({super.key, required this.hero, required this.spot});

  @override
  State<_DreamBubble> createState() => _DreamBubbleState();
}

class _DreamBubbleState extends State<_DreamBubble>
    with TickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  AnimationController? _float;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _dots.value = 1;
    } else if (_dots.value == 0 && !_dots.isAnimating) {
      _dots.forward();
    }
    if (AppMotion.loopsOn(context) && _float == null) {
      _float = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3200))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    _float?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c.lip, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(upperCaseFor(context, l10n.restDreamingOf(widget.hero)),
              style: theme.textTheme.labelSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.muted, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(widget.spot,
              style: theme.textTheme.titleMedium!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.text)),
          Text(l10n.restTodaysWeakSpot,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: c.navyText)),
        ],
      ),
    );
    Widget dot(int i, double size) => AnimatedBuilder(
          animation: _dots,
          builder: (context, child) => Opacity(
              opacity: ((_dots.value * 3) - (2 - i)).clamp(0.0, 1.0),
              child: child),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
          ),
        );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        // The dots run from the head up to the bubble: the nearest first.
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 92, top: 4),
          child: dot(0, 12),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 104, top: 3),
          child: dot(1, 8),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 112, top: 3),
          child: dot(2, 5),
        ),
      ],
    );
    final f = _float;
    return Semantics(
      container: true,
      label: '${l10n.restDreamingOf(widget.hero)} ${widget.spot}, '
          '${l10n.restTodaysWeakSpot}',
      excludeSemantics: true,
      child: f == null
          ? content
          : AnimatedBuilder(
              animation: f,
              builder: (context, child) => Transform.translate(
                  offset: Offset(0, -4 + 4 * math.cos(2 * math.pi * f.value)),
                  child: child),
              child: content,
            ),
    );
  }
}

/// V24f's Premium card (v13): the navy card (140°, navy → plum, a gold
/// hairline, a dark lip) with the gold ✦ PREMIUM tag and "5 practices a
/// day" on its top row, the ticket deck ([TicketDeck]: NEXT UP, today's
/// weak spot, "AI feedback on every answer", "+4 / TODAY"), and "Wake
/// <Hero> up · 7 days free". It glows while the companion wakes (V24s); on
/// Wake the deck gathers first ([gathered]).
class _FreePanel extends StatelessWidget {
  final RestOffer offer;
  final Avatar hero;
  final bool awake;
  final bool gathered;
  final VoidCallback onWake;

  static const cardPadding = EdgeInsets.all(14);

  /// The board's button height (v13).
  static const buttonHeight = 50.0;

  const _FreePanel({
    required this.offer,
    required this.hero,
    required this.awake,
    required this.gathered,
    required this.onWake,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spot = offer.weakSpot;
    final days = offer.trialDays;
    const more = StorageService.dailySessionLimit -
        StorageService.freeDailyPracticeLimit;
    return AnimatedContainer(
      key: RestScene.premiumCardKey,
      duration: AppMotion.orInstant(context, AppMotion.base),
      padding: cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          // The board's 140°.
          begin: const Alignment(-.64, -.77),
          end: const Alignment(.64, .77),
          colors: [c.navy, AppColors.premiumPlum],
        ),
        border: Border.all(color: c.gold.withValues(alpha: .45), width: 1.5),
        boxShadow: [
          const BoxShadow(color: AppColors.restCardLip, offset: Offset(0, 6)),
          BoxShadow(
              color: c.gold.withValues(alpha: awake ? .55 : 0),
              blurRadius: 18,
              spreadRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: c.gold, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppColors.light.onOrange),
                const SizedBox(width: 6),
                // The plan's name: English capitals (F4-13).
                Text(upperCaseIn('en', l10n.featurePremium),
                    style: theme.textTheme.labelSmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(
                            color: AppColors.light.onOrange,
                            letterSpacing: 1.2)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  l10n.restPracticesADay(StorageService.dailySessionLimit),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: AppColors.onRibbonMuted)),
            ),
          ]),
          const SizedBox(height: 12),
          TicketDeck(
            key: RestScene.deckKey,
            eyebrow: upperCaseFor(context, l10n.restNextUp),
            title: spot ?? l10n.restDeckAnyTopic(offer.topics),
            line: l10n.restAiFeedback,
            count: '+$more', // l10n-guard: a number
            countLabel: upperCaseFor(context, l10n.restDeckToday),
            semantics: l10n.restDeckSemantics(more),
            gathered: gathered,
          ),
          const SizedBox(height: 12),
          // While the companion wakes the button stays orange (V24s) but
          // takes no second tap.
          IgnorePointer(
            ignoring: awake || gathered,
            child: PressableButton(
              key: RestScene.wakeKey,
              label: days == null
                  ? l10n.restWakeUp(hero.name(l10n))
                  : l10n.restWakeUpTrial(hero.name(l10n), days),
              height: buttonHeight,
              tone: ButtonTone.orange,
              trailingIcon: Icons.arrow_forward_rounded,
              shine: true,
              haptic: ButtonHaptic.medium,
              onPressed: onWake,
            ),
          ),
        ],
      ),
    );
  }
}
