import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'medal_badge.dart';
import 'monthly_medal_collection.dart';

/// PF02: every medal over the blurred profile, newest first, by year; the
/// running month grey; the Welcome badge last. A layer, not a page: X or
/// a tap outside closes it. A tap on a medal opens its detail (PF03, the
/// existing medal detail).
Future<void> showAllMedals(
    BuildContext context, MonthlyMedalCollection collection) {
  HapticMap.light();
  final reduced = AppMotion.reduced(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.profileMedalsClose,
    barrierColor: Colors.transparent,
    transitionDuration: reduced ? AppMotion.fast : AppMotion.base,
    pageBuilder: (dialogContext, _, __) => _MedalsLayer(collection: collection),
    transitionBuilder: (context, animation, _, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
              child: ColoredBox(
                  color:
                      AppColors.of(context).scrim.withValues(alpha: .35 * t)),
            ),
          ),
        ),
        Opacity(
          opacity: t,
          child:
              Transform.scale(scale: reduced ? 1 : .92 + .08 * t, child: child),
        ),
      ]);
    },
  );
}

class _MedalsLayer extends StatelessWidget {
  final MonthlyMedalCollection collection;
  const _MedalsLayer({required this.collection});

  static const closeKey = ValueKey('medals_layer_close');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final months = collection.shelf().reversed.toList();
    final years = <int>{for (final m in months) m.year}.toList();
    Widget medal(ShelfMonth m) => InkWell(
          key: MonthlyMedalCollection.slotKey(m.year, m.month),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticMap.light();
            showMedalDetail(context,
                medal: m.medal(MonthlyMedalCollection.detailDisc),
                lines: m.details(l10n));
          },
          child: SizedBox(
            width: 92,
            child: Column(children: [
              m.medal(64, fadedOpacity: MonthlyMedalCollection.runningFade),
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
                        child: Semantics(
                          header: true,
                          child: Text(l10n.settingsMedalCollection,
                              style: theme.textTheme.titleLarge!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.text)),
                        ),
                      ),
                      IconButton(
                        key: closeKey,
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
                            child: MedalBadge.welcome(
                                disc: 64,
                                earned: collection.welcomeBadge != null),
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
