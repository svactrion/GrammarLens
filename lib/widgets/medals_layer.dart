import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/medal_tier.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'medal_badge.dart';
import 'monthly_medal_collection.dart';

/// PF02's keys.
abstract final class MedalsLayer {
  static const closeKey = ValueKey('medals_layer_close');

  /// The tier counters on top (n Gold, n Silver, n Bronze, n Welcome).
  static const countersKey = ValueKey('medals_layer_counters');

  /// A year's header.
  static ValueKey<String> yearKey(int year) => ValueKey('medals_layer_$year');

  /// The time the medals fly from the shelf (SPEC PF02: 350 ms); the blur
  /// reaches 10 in its first 250 ms.
  static const flight = Duration(milliseconds: 350);

  /// The medals that did not fly settle one after another.
  static const settleStagger = Duration(milliseconds: 40);
}

/// PF02: every medal over the blurred profile: the tier counters, then
/// each year newest first, a 3-column grid read left to right, top to
/// bottom, newest at the top left; the running month first ("in
/// progress"); the Welcome badge at the month it was earned. A layer, not a page: X or
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
    // PF02 (fix round 2, item 6): every slot newest first, the running
    // month first and the earned Welcome badge at the month it was earned
    // (it used to come after every year); each with its year.
    final badge = collection.welcomeBadge;
    final slots = collection.allSlots();
    int yearOf(ShelfMonth? m) => m?.year ?? badge!.earnedAt.year;
    final years = <int>{for (final m in slots) yearOf(m)}.toList();

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

    Widget cell(Key key, Widget medal, String month, String line,
            VoidCallback onTap,
            {String? semantics}) =>
        InkWell(
          key: key,
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticMap.light();
            onTap();
          },
          child: Semantics(
            label: semantics,
            excludeSemantics: semantics != null,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                medal,
                const SizedBox(height: 4),
                Text(month,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w800)
                        .copyWith(fontSize: 14, color: c.text)),
                Text(line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall!
                        .withWeight(FontWeight.w700)
                        .copyWith(fontSize: 12, color: c.muted)),
              ]),
            ),
          ),
        );

    Widget slot(int i, ShelfMonth? m) {
      if (m == null) {
        return settle(
          i,
          cell(
            MonthlyMedalCollection.welcomeSlotKey,
            const MedalHero(
              tag: MonthlyMedalCollection.welcomeHeroTag,
              child: MedalBadge.welcome(disc: 64, earned: true),
            ),
            monthShort(badge!.earnedAt.month, l10n),
            l10n.medalWelcomeSlot,
            () => showWelcomeDetail(context, badge),
            semantics: l10n.medalWelcomeEarned,
          ),
        );
      }
      return settle(
        i,
        cell(
          MonthlyMedalCollection.slotKey(m.year, m.month),
          MedalHero(
            tag: MonthlyMedalCollection.heroTag(m.year, m.month),
            child:
                m.medal(64, fadedOpacity: MonthlyMedalCollection.runningFade),
          ),
          monthShort(m.month, l10n),
          m.running ? l10n.medalsInProgress : m.tier!.label(l10n),
          () => m.showDetail(context),
        ),
      );
    }

    Widget chip(String text, Color fill, Color ink) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
              color: fill, borderRadius: BorderRadius.circular(999)),
          child: Text(text,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w800)
                  .copyWith(fontSize: 13, color: ink)),
        );

    final grid = <Widget>[];
    for (final year in years) {
      grid.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
        child: Text('$year', // l10n-guard: a year
            key: MedalsLayer.yearKey(year),
            style: theme.textTheme.titleMedium!
                .withWeight(FontWeight.w900)
                .copyWith(fontSize: 16, color: c.text)),
      ));
      final inYear = [
        for (final (i, m) in slots.indexed)
          if (yearOf(m) == year) (i, m)
      ];
      for (var r = 0; r < inYear.length; r += 3) {
        grid.add(Padding(
          padding: EdgeInsets.only(top: r == 0 ? 0 : 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var k = r; k < r + 3; k++)
              Expanded(
                child: k < inYear.length
                    ? slot(inYear[k].$1, inYear[k].$2)
                    : const SizedBox.shrink(),
              ),
          ]),
        ));
      }
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 14, 0),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(l10n.medalsAllTitle,
                                  style: theme.textTheme.headlineSmall!
                                      .withWeight(FontWeight.w900)
                                      .copyWith(fontSize: 24, color: c.text)),
                            ),
                            Text(l10n.medalsNewestFirst,
                                style: theme.textTheme.labelMedium!
                                    .withWeight(FontWeight.w700)
                                    .copyWith(fontSize: 13, color: c.muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        key: MedalsLayer.closeKey,
                        tooltip: l10n.profileMedalsClose,
                        style: IconButton.styleFrom(
                          backgroundColor: c.disabledFill,
                          fixedSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: c.text),
                      ),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            key: MedalsLayer.countersKey,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              chip(
                                  l10n.medalsTierCount(
                                      collection.countOf(MedalTier.gold),
                                      MedalTier.gold.label(l10n)),
                                  c.goldSoft,
                                  c.goldDeep),
                              chip(
                                  l10n.medalsTierCount(
                                      collection.countOf(MedalTier.silver),
                                      MedalTier.silver.label(l10n)),
                                  AppColors.silverSoft,
                                  AppColors.onSilverSoft),
                              chip(
                                  l10n.medalsTierCount(
                                      collection.countOf(MedalTier.bronze),
                                      MedalTier.bronze.label(l10n)),
                                  AppColors.bronzeSoft,
                                  AppColors.onBronzeSoft),
                              chip(
                                  l10n.medalsTierCount(badge == null ? 0 : 1,
                                      l10n.medalWelcomeSlot),
                                  c.sky,
                                  c.onSky),
                            ],
                          ),
                          ...grid,
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
