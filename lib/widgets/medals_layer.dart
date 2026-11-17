import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'medal_badge.dart';
import 'monthly_medal_collection.dart';

/// PF02's keys.
abstract final class MedalsLayer {
  static const closeKey = ValueKey('medals_layer_close');

  /// "N earned" under the title (moved here from Profile's section header,
  /// which V23 does not have).
  static const earnedKey = ValueKey('medals_layer_earned');

  /// The time the medals fly from the shelf (SPEC PF02: 350 ms); the blur
  /// reaches 10 in its first 250 ms.
  static const flight = Duration(milliseconds: 350);

  /// The medals that did not fly settle one after another.
  static const settleStagger = Duration(milliseconds: 40);
}

/// PF02: every medal over the blurred profile, newest first, by year; the
/// running month grey; the Welcome badge last. A layer, not a page: X or
/// a tap outside closes it. The medals on the shelf fly into the panel
/// (Hero) and fly back when it closes; the others settle 40 ms apart. A
/// tap on a medal opens its detail (PF03, the existing medal detail).
Future<void> showAllMedals(
    BuildContext context, MonthlyMedalCollection collection) {
  HapticMap.light();
  final reduced = AppMotion.reduced(context);
  final duration = reduced ? AppMotion.fast : MedalsLayer.flight;
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierLabel: context.l10n.profileMedalsClose,
    barrierColor: Colors.transparent,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => _MedalsLayer(collection: collection),
    transitionsBuilder: (context, animation, _, child) {
      final blur = CurvedAnimation(
          parent: animation,
          curve: Interval(
              0,
              reduced
                  ? 1
                  : AppMotion.base.inMilliseconds /
                      MedalsLayer.flight.inMilliseconds,
              curve: AppMotion.enter));
      final panel = CurvedAnimation(parent: animation, curve: AppMotion.enter);
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 10 * blur.value, sigmaY: 10 * blur.value),
                child: ColoredBox(
                    color: AppColors.of(context)
                        .scrim
                        .withValues(alpha: .35 * blur.value)),
              ),
            ),
          ),
          Opacity(
            opacity: panel.value,
            child: Transform.scale(
                scale: reduced ? 1 : .92 + .08 * panel.value, child: child),
          ),
        ]),
        child: child,
      );
    },
  ));
}

class _MedalsLayer extends StatelessWidget {
  final MonthlyMedalCollection collection;
  const _MedalsLayer({required this.collection});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    final months = collection.shelf();
    final years = <int>{for (final m in months) m.year}.toList();
    // The order the medals settle in: newest first, the Welcome badge last.
    final order = {for (final (i, m) in months.indexed) (m.year, m.month): i};
    Widget settle(int i, Widget child) {
      final delay = MedalsLayer.settleStagger * i;
      final total = AppMotion.base + delay;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : total,
        curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1,
            curve: AppMotion.pop),
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: .8 + .2 * t, child: child),
        ),
        child: child,
      );
    }

    Widget medal(ShelfMonth m) => settle(
          order[(m.year, m.month)]!,
          InkWell(
            key: MonthlyMedalCollection.slotKey(m.year, m.month),
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticMap.light();
              m.showDetail(context);
            },
            child: SizedBox(
              width: 92,
              child: Column(children: [
                MedalHero(
                  tag: MonthlyMedalCollection.heroTag(m.year, m.month),
                  child: m.medal(64,
                      fadedOpacity: MonthlyMedalCollection.runningFade),
                ),
                const SizedBox(height: 4),
                Text(
                  m.running ? l10n.profileMedalThisMonth : m.label(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: m.running ? c.muted : c.text),
                ),
              ]),
            ),
          ),
        );
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(l10n.settingsMedalCollection,
                                  style: theme.textTheme.titleLarge!
                                      .withWeight(FontWeight.w900)
                                      .copyWith(color: c.text)),
                            ),
                            Text(
                              l10n.settingsMedalsEarned(
                                  collection.earnedCount),
                              key: MedalsLayer.earnedKey,
                              style: theme.textTheme.labelMedium!
                                  .withWeight(FontWeight.w700)
                                  .copyWith(color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: MedalsLayer.closeKey,
                        tooltip: l10n.profileMedalsClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: c.text),
                      ),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final year in years) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: Text('$year', // l10n-guard: a year
                                  style: theme.textTheme.labelLarge!
                                      .withWeight(FontWeight.w900)
                                      .copyWith(color: c.muted)),
                            ),
                            Wrap(spacing: 6, runSpacing: 12, children: [
                              for (final m in months)
                                if (m.year == year) medal(m),
                            ]),
                          ],
                          const SizedBox(height: 16),
                          Center(
                            child: settle(
                              months.length,
                              InkWell(
                                key: MonthlyMedalCollection.welcomeSlotKey,
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  HapticMap.light();
                                  showWelcomeDetail(
                                      context, collection.welcomeBadge);
                                },
                                child: Semantics(
                                  label: collection.welcomeBadge != null
                                      ? l10n.medalWelcomeEarned
                                      : l10n.medalWelcomeLocked,
                                  excludeSemantics: true,
                                  button: true,
                                  child: MedalHero(
                                    tag: MonthlyMedalCollection.welcomeHeroTag,
                                    child: MedalBadge.welcome(
                                        disc: 64,
                                        earned:
                                            collection.welcomeBadge != null),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
