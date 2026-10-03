import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../services/month_transition.dart';
import 'avatar_tile.dart';
import 'medal_badge.dart';
import 'monthly_climb/climb_card.dart';

/// How the month card was closed (Batch 6, M6). The names are
/// `month_card_dismissed`'s `method` values (M19).
enum MonthCardDismissal {
  button('button'),

  /// A swipe down on the sheet.
  drag('drag'),

  /// A tap outside the sheet.
  barrier('barrier');

  final String wireName;
  const MonthCardDismissal(this.wireName);
}

/// The month transition card (Batch 6, M3–M5, M12, M13, M15): a bottom
/// sheet over Home, which shows the new month's mountain in K-c behind it.
/// Content only; [showMonthCard] opens it.
class MonthCardSheet extends StatelessWidget {
  final MonthCardData data;

  /// The user's avatar, for the fresh-start card.
  final Avatar avatar;

  /// The one button, "See the mountain": it only closes the sheet (M12).
  final VoidCallback onClose;

  const MonthCardSheet({
    super.key,
    required this.data,
    required this.avatar,
    required this.onClose,
  });

  static const buttonLabel = 'See the mountain';
  static const contentKey = ValueKey('month_card_content');
  static const scrollKey = ValueKey('month_card_scroll');
  static const nearMissKey = ValueKey('month_card_near_miss');
  static const medalKey = ValueKey('month_card_medal');

  /// N30, N37: the medal large in the card's centre. 112 pt on screens
  /// 740 pt tall and up ([medalDiscRegular]); on 640–739 pt screens the
  /// largest disc, no larger than 88 pt, with which the fullest summary
  /// card does not scroll at any of the three text sizes
  /// ([medalDiscCompact]); 48 pt below ([medalDiscSmall]). Chosen by
  /// tool/design_measure/batch5/month_card_disc_test.dart.
  ///
  /// Measured (docs/design/batch5/card/month_card_disc.txt): at 375 × 812
  /// and 430 × 932 the card fits 112 pt at all three sizes. At 375 × 667
  /// it fits up to 88 / 80 / 70 pt at Small / Medium / Large, so 70. At
  /// 320 × 568 no disc down to 40 pt fits (the card without a medal is
  /// already 279 / 289 / 300 pt of 319.5); 48 pt, the stars' readability
  /// floor (N20), keeps the overflow smallest among readable discs: an
  /// accepted known flaw, the card scrolls there.
  static const medalDiscRegular = 112.0;
  static const medalDiscCompact = 70.0;
  static const medalDiscSmall = 48.0;

  /// The screen heights where the disc steps down.
  static const compactBelow = 740.0;
  static const smallBelow = 640.0;

  static double? _discForTesting;

  /// Debug builds only: stands in for the chosen disc in measuring tools.
  /// Ignored in profile and release builds.
  static set debugMedalDiscOverride(double? value) => _discForTesting = value;

  /// The medal's disc on a screen [height] points tall.
  static double medalDiscFor(double height) {
    if (kDebugMode && _discForTesting != null) return _discForTesting!;
    if (height < smallBelow) return medalDiscSmall;
    if (height < compactBelow) return medalDiscCompact;
    return medalDiscRegular;
  }

  /// The near-miss line (M15): the gap as a number, no promise of days.
  static String nearMissText(int gap, String tier) =>
      'Just $gap ${gap == 1 ? 'point' : 'points'} from $tier';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // A handle of our own (not `showDragHandle`), so the sheet's top is the
    // content's top; the whole sheet drags.
    final handle = Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    final button =
        FilledButton(onPressed: onClose, child: const Text(buttonLabel));
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: scrollKey,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: contentKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            handle,
            ...switch (data.variant) {
              MonthCardVariant.summary => _summary(context),
              MonthCardVariant.fresh => _fresh(context),
            },
            const SizedBox(height: 16),
            button,
          ],
        ),
      ),
    );
  }

  List<Widget> _summary(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final month = ClimbCard.monthNames[data.previousMonth - 1];
    final next = ClimbCard.monthNames[data.month - 1];
    final title = Text('Your $month climb',
        textAlign: TextAlign.center,
        style:
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800));
    Widget stat(String value, String label) => Text.rich(TextSpan(children: [
          TextSpan(
              text: value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          TextSpan(
              text: ' $label',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ]));
    final tier = data.tier;
    return [
      Semantics(header: true, child: title),
      // N30: the medal in the centre, large; no medal, no block.
      if (tier != null) ...[
        const SizedBox(height: 12),
        Column(key: medalKey, children: [
          MedalBadge.monthly(
              themeId: data.previousTheme.id,
              tier: tier,
              disc: medalDiscFor(MediaQuery.sizeOf(context).height)),
          const SizedBox(height: 4),
          Text('${tier.label} medal',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ],
      const SizedBox(height: 10),
      // Steps and points side by side, under the medal.
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 4,
          children: [
            stat('${data.steps} / ${data.days}', 'steps'),
            stat('${data.score}', 'points'),
          ]),
      if (data.nearMiss case (final next, final gap)) ...[
        const SizedBox(height: 6),
        Text(nearMissText(gap, next.label),
            key: nearMissKey,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
      ],
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
      Text('Next: $next · ${data.theme.name}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    ];
  }

  List<Widget> _fresh(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // The avatar beside the title, not above it: the card fits a 320 × 568
    // screen's sheet at every text size (M10).
    return [
      Row(children: [
        AvatarTile(avatar: avatar, radius: 28),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              child: Text('A new mountain awaits',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Text(data.theme.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Text(data.theme.tagline,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
      const SizedBox(height: 6),
      Text('Your avatar is ready at the start.',
          style: theme.textTheme.bodyMedium),
    ];
  }
}

/// Opens the month card as a modal bottom sheet and completes with how it
/// was closed: the button, a swipe down, or a tap outside (M6). A close
/// without the button is told apart by where the last pointer went down:
/// on the sheet (a drag) or outside it (the barrier).
Future<MonthCardDismissal> showMonthCard(
  BuildContext context, {
  required MonthCardData data,
  required Avatar avatar,
}) async {
  final sheetKey = GlobalKey();
  // Whether the last pointer went down on the sheet (true) or outside it.
  bool? lastDownOnSheet;
  void track(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    final box = sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    lastDownOnSheet = event.position.dy >= box.localToGlobal(Offset.zero).dy;
  }

  GestureBinding.instance.pointerRouter.addGlobalRoute(track);
  try {
    final result = await showModalBottomSheet<MonthCardDismissal>(
      context: context,
      builder: (sheetContext) => KeyedSubtree(
        key: sheetKey,
        child: MonthCardSheet(
          data: data,
          avatar: avatar,
          onClose: () =>
              Navigator.of(sheetContext).pop(MonthCardDismissal.button),
        ),
      ),
    );
    if (result != null) return result;
    return lastDownOnSheet == true
        ? MonthCardDismissal.drag
        : MonthCardDismissal.barrier;
  } finally {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(track);
  }
}
