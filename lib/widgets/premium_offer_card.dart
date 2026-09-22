import 'package:flutter/material.dart';

import '../utils/premium_copy.dart';

/// The Premium offer at the end of a free user's practice results, shown
/// once today's free practice is used up (`ResultsScreen` decides when).
///
/// A plain app [Card] (the theme's `surfaceContainerHigh`, radius 20,
/// outline border) with the usual 18 pt padding: no gradient, no
/// illustration, no custom surface. The "PREMIUM" chip uses the same
/// `secondaryContainer` pairing as the Premium screen's own PREMIUM column,
/// not the orange band color, and the only action is the theme's
/// FilledButton. Never says "unlimited": Premium is bounded by
/// `StorageService.dailySessionLimit`.
class PremiumOfferCard extends StatelessWidget {
  final VoidCallback onSeePremium;

  const PremiumOfferCard({super.key, required this.onSeePremium});

  /// Exactly two, both real Premium differences: Topic Practice is locked
  /// for a free user, and a free user gets
  /// `StorageService.freeDailyPracticeLimit` practice sessions a day against
  /// Premium's `StorageService.dailySessionLimit`.
  static const benefits = [
    _OfferBenefit(
      title: 'Topic Practice',
      detail: 'Focus on the areas you need',
    ),
    _OfferBenefit(
      title: 'More Daily Sessions',
      detail: 'Build your progress faster',
    ),
  ];

  /// The narrowest a benefit column may get, in unscaled points, before the
  /// two benefits stack instead of sitting side by side.
  static const double _minBenefitColumnWidth = 120;
  static const double _benefitGap = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumChip(),
            const SizedBox(height: 10),
            Text(
              'Keep practicing',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              freePracticeUsedMessage,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final columnWidth =
                    (constraints.maxWidth - _benefitGap) / 2 / scale;
                if (columnWidth >= _minBenefitColumnWidth) {
                  return Row(
                    key: const Key('premiumOfferBenefitsRow'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _BenefitTile(benefits[0])),
                      const SizedBox(width: _benefitGap),
                      Expanded(child: _BenefitTile(benefits[1])),
                    ],
                  );
                }
                return Column(
                  key: const Key('premiumOfferBenefitsColumn'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BenefitTile(benefits[0]),
                    const SizedBox(height: 12),
                    _BenefitTile(benefits[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSeePremium,
                child: const Text('See Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferBenefit {
  final String title;
  final String detail;

  const _OfferBenefit({required this.title, required this.detail});
}

/// One benefit: a title over its detail line. Text only for now; an icon,
/// when there is one, goes in front of this column inside this widget, so
/// neither layout above has to change.
class _BenefitTile extends StatelessWidget {
  final _OfferBenefit benefit;

  const _BenefitTile(this.benefit);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          benefit.title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          benefit.detail,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A label, not a control: nothing to tap, no lock (this is an offer, not a
/// locked item, which is what `LockedPremiumPill` is for).
class _PremiumChip extends StatelessWidget {
  const _PremiumChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'PREMIUM',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
