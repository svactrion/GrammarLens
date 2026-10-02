// Batch 6 Batch 0, §5: a prototype of the month transition card (M3–M5)
// and of the climb card in the K-c framing (M4), for measuring and
// rendering only. Nothing in lib/ imports it; it is not the design to
// build, only the fullest content M5 allows, laid out with the app's own
// theme, so its height can be measured.
import 'package:flutter/material.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/medal_tier_color.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_point_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// What a summary card shows (M5). [tier] null: no medal row.
/// [nearMiss] null: no near-miss line.
class SummaryData {
  final String month, nextMonth;
  final MedalTier? tier;
  final int steps, days, points;
  final (MedalTier, int)? nearMiss;
  final ClimbTheme nextTheme;
  const SummaryData(
      {required this.month,
      required this.nextMonth,
      required this.tier,
      required this.steps,
      required this.days,
      required this.points,
      required this.nearMiss,
      required this.nextTheme});
}

const prototypeButton = 'Start climbing';

/// A copy of Profile's medal circle (`_MedalSpecimen` in
/// lib/widgets/monthly_medal_collection.dart, private there): M8 wants the
/// card to read it from the medal system, so the build would make it
/// public rather than copy it.
class MedalCircle extends StatelessWidget {
  final MedalTier tier;
  final double size;
  const MedalCircle({super.key, required this.tier, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(
              tier.color.withValues(alpha: .20), scheme.surfaceContainerHigh),
          border: Border.all(color: tier.color, width: 2),
        ),
        child: Icon(Icons.landscape_rounded,
            color: tier.color, size: size * 34 / 72),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
      Text(label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// The summary card's content, fullest case (M5).
class SummaryCard extends StatelessWidget {
  final SummaryData data;
  const SummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      key: const ValueKey('month_card_content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(data.month,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (data.tier case final tier?) ...[
          const SizedBox(height: 12),
          Row(children: [
            MedalCircle(tier: tier),
            const SizedBox(width: 12),
            Expanded(
                child: Text('${tier.label} medal',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Stat('${data.steps} / ${data.days}', 'steps')),
          Expanded(child: _Stat('${data.points}', 'points')),
        ]),
        if (data.nearMiss case (final tier, final gap)) ...[
          const SizedBox(height: 12),
          Text('Only $gap points short of ${tier.label}.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Text('${data.nextMonth}: ${data.nextTheme.name}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        FilledButton(onPressed: () {}, child: const Text(prototypeButton)),
      ],
    );
  }
}

/// The fresh-start card (M3): avatar, warm, no numbers.
class FreshCard extends StatelessWidget {
  final String nextMonth;
  final ClimbTheme nextTheme;
  final Avatar avatar;
  const FreshCard(
      {super.key,
      required this.nextMonth,
      required this.nextTheme,
      required this.avatar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('month_card_content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: AvatarTile(avatar: avatar, radius: 40)),
        const SizedBox(height: 16),
        Text('A fresh start',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('$nextMonth is on ${nextTheme.name}.',
            textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text(prototypeButton)),
      ],
    );
  }
}

/// The sheet around either card: scrolls if the content is taller than the
/// sheet's room.
Widget sheetBody(Widget content) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('month_card_scroll'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: content,
      ),
    );

/// The scene in the K-c framing (scene art Batch 0 §3): the whole image
/// fitted to the window's height, centered, the avatar on START, every save
/// point and the flag unreached. Drawn with the product's own assets,
/// tables and colour matrix; the window's fill shows in the side bands.
class KcMountain extends StatelessWidget {
  final ClimbTheme theme;
  final Avatar avatar;
  final int days;
  const KcMountain(
      {super.key,
      required this.theme,
      required this.avatar,
      required this.days});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final darkGain =
        brightness == Brightness.dark ? climbObjectDarkGain[theme.id] : null;
    return LayoutBuilder(builder: (context, c) {
      const h = 350.0;
      final scale = h / ClimbRoute.sceneSize.height;
      final band = (c.maxWidth - scale) / 2;
      final start = ClimbRoute(days).stepAt(0) * scale;
      // zoom_numbers.txt: the avatar's tile at K-c on START.
      const tile = 22.5;
      Rect scaled(Rect r) => Rect.fromLTRB(
          r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);
      return SizedBox(
        height: h,
        child: ColoredBox(
          color: theme.paletteFor(brightness).sky,
          child: Stack(children: [
            Positioned(
              left: band,
              top: 0,
              width: scale,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                    child: Image.asset(theme.backgroundFor(brightness),
                        fit: BoxFit.fill)),
                for (final p in [...ClimbSavePoints.all, ClimbSavePoints.flag])
                  Positioned.fromRect(
                      rect: scaled(p.rect),
                      child: ClimbObjectLayer(
                          asset: p.object == 'summit_flag'
                              ? ClimbSavePoints.assetFor('summit_flag')
                              : p.asset,
                          matrix: ClimbSavePoints.matrix(
                              lit: 0, darkGain: darkGain))),
                Positioned(
                    left: start.dx - tile / 2,
                    top: start.dy - tile * 55 / 58,
                    child: AvatarTile(avatar: avatar, radius: tile / 2)),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

/// The climb card with [KcMountain] in its window: the product's
/// `ClimbCard` (plaque, frame, chips) around the K-c scene.
Widget kcClimbCard(
        {required DateTime month,
        required ClimbTheme theme,
        required Avatar avatar,
        required Widget scoreBar}) =>
    ClimbCard(
      month: month,
      steps: 0,
      days: DateTime(month.year, month.month + 1, 0).day,
      mountain: KcMountain(
          theme: theme,
          avatar: avatar,
          days: DateTime(month.year, month.month + 1, 0).day),
      scoreBar: scoreBar,
    );
