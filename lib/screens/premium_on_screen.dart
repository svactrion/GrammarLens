import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/companion_view.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/pressable_button.dart';
import '../widgets/rays.dart';

/// PW05: one celebration screen after a purchase or a trial start. The
/// companion cheers (two hops) under turning rays, the three unlocked
/// things slide in 120 ms apart, the trial's end date is written plainly;
/// confetti once; success haptic as it opens. Continue pops with true.
class PremiumOnScreen extends StatefulWidget {
  final Avatar hero;

  /// The real number of topics and daily sessions (the copy counts them).
  final int topics;
  final int sessions;

  /// When the free trial ends, or null when no trial was started.
  final DateTime? trialEnds;

  const PremiumOnScreen({
    super.key,
    required this.hero,
    required this.topics,
    required this.sessions,
    this.trialEnds,
  });

  static const continueKey = ValueKey('premium_on_continue');

  @override
  State<PremiumOnScreen> createState() => _PremiumOnScreenState();
}

class _PremiumOnScreenState extends State<PremiumOnScreen> {
  @override
  void initState() {
    super.initState();
    HapticMap.success();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    final items = [
      (Icons.menu_book_rounded, l10n.paywallOnTopics(widget.topics)),
      (Icons.bolt_rounded, l10n.paywallOnSessions(widget.sessions)),
      (Icons.auto_awesome_rounded, l10n.paywallOnFeedback),
    ];
    final ends = widget.trialEnds;
    return Scaffold(
      backgroundColor: c.navyDeep,
      body: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.5),
                radius: 1.2,
                colors: [c.navy, c.navyDeep],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -.62),
          child: Rays(color: c.gold.withValues(alpha: .18), size: 420),
        ),
        if (!reduced)
          ConfettiBurst(
            origin: Offset(MediaQuery.sizeOf(context).width / 2,
                MediaQuery.sizeOf(context).height * .3),
            colors: [c.orange, c.gold, c.sky, Colors.white],
            length: const Duration(milliseconds: 2500),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  // Scrolls on a short screen; the button stays below.
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: CompanionView(
                                  hero: widget.hero,
                                  mood: CompanionMood.cheer,
                                  size: 150,
                                  hopping: true,
                                  decorative: true),
                            ),
                            const SizedBox(height: 14),
                            Semantics(
                              header: true,
                              child: Text(l10n.paywallOnTitle,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium!
                                      .withWeight(FontWeight.w900)
                                      .copyWith(color: c.onNavy)),
                            ),
                            const SizedBox(height: 18),
                            for (final (i, (icon, text)) in items.indexed)
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                                duration: AppMotion.orInstant(
                                    context,
                                    AppMotion.slow +
                                        Duration(milliseconds: 120 * (i + 1))),
                                curve: Interval(
                                    (120 * (i + 1)) /
                                        (AppMotion.slow.inMilliseconds +
                                            120 * (i + 1)),
                                    1,
                                    curve: AppMotion.enter),
                                builder: (context, t, child) => Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                      offset: Offset(-40 * (1 - t), 0),
                                      child: child),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(children: [
                                    Icon(icon, color: c.gold),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(text,
                                          style: theme.textTheme.titleSmall!
                                              .withWeight(FontWeight.w800)
                                              .copyWith(color: c.onNavy)),
                                    ),
                                  ]),
                                ),
                              ),
                            if (ends != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.paywallOnTrialEnds(DateFormat.yMMMMd(
                                        Localizations.localeOf(context)
                                            .toLanguageTag())
                                    .format(ends)),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium!
                                    .copyWith(color: c.onNavyMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PressableButton(
                  key: PremiumOnScreen.continueKey,
                  label: l10n.commonContinue,
                  tone: ButtonTone.orange,
                  haptic: ButtonHaptic.medium,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
