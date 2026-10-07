// Batch 5 Batch 0: the composed medals (tool/medals/) in the places the
// app draws a medal today, as tool-only copies of those widgets. Nothing
// in lib/ imports this; the product widgets are unchanged.
//
// The images are read from build/medals/webp/<px>/ (tool/medals/
// medal_assets.py), not from assets/: Batch 0 adds no asset.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

/// The WebP candidates' pixel size the prototypes draw.
const protoMedalPx = 512;

/// Geometry of the composed images (docs/design/batch5/medal_assets.txt):
/// the canvas is [canvasOverDisc] times the body's disc, centred on it to
/// within 0.2 % of the diameter; the stars stand up to [starsAbove] of the
/// diameter above the disc; the Welcome ribbon stays inside the disc's
/// bounding square.
const canvasOverDisc = 768 / 681.95;
const starsAbove = .056;

File medalFile(String name) =>
    File('build/medals/webp/$protoMedalPx/$name.webp');

/// The images, read once into memory: a [FileImage] first resolved inside
/// a widget test's fake-async zone never finishes loading, so the tests
/// precache these [MemoryImage]s with real async before building the tree
/// ([precacheMedals]), and the widgets find them decoded.
final Map<String, MemoryImage> _medalImages = {};

MemoryImage medalImage(String name) => _medalImages.putIfAbsent(name,
    () => MemoryImage(Uint8List.fromList(medalFile(name).readAsBytesSync())));

String medalName(String themeId, MedalTier tier) =>
    'medal_${themeId}_${tier.name}';

/// One composed medal whose disc is [disc] points across. Laid out as a
/// box [disc] wide and `disc × (1 + starsAbove)` tall for a monthly medal
/// (the stars above the disc), [disc] square for the Welcome badge; the
/// image is drawn around it without clipping. [earned] false draws it
/// faded (N10: opacity 0.5, saturation 0.6, the same values as an
/// unreached save point, so `ClimbSavePoints.matrix(lit: 0)`).
class ProtoMedal extends StatelessWidget {
  final String name;
  final double disc;
  final bool earned;

  const ProtoMedal(
      {super.key, required this.name, required this.disc, this.earned = true});

  bool get welcome => name == 'medal_welcome';

  double get height => welcome ? disc : disc * (1 + starsAbove);

  @override
  Widget build(BuildContext context) {
    final side = disc * canvasOverDisc;
    Widget image = Image(
        image: medalImage(name),
        width: side,
        height: side,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium);
    if (!earned) {
      image = ColorFiltered(
          colorFilter: ColorFilter.matrix(ClimbSavePoints.matrix(lit: 0)),
          child: image);
    }
    final discTop = height - disc;
    return SizedBox(
      width: disc,
      height: height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
            left: disc / 2 - side / 2,
            top: discTop + disc / 2 - side / 2,
            width: side,
            height: side,
            child: image),
      ]),
    );
  }
}

/// A medal fitted whole into a [box] square (stars included): the disc is
/// smaller than [box] by the stars' room.
class ProtoMedalFit extends StatelessWidget {
  final String name;
  final double box;
  const ProtoMedalFit({super.key, required this.name, required this.box});

  @override
  Widget build(BuildContext context) {
    final disc = box / (1 + starsAbove);
    return SizedBox.square(
        dimension: box,
        child: Align(
            alignment: Alignment.bottomCenter,
            child: ProtoMedal(name: name, disc: disc)));
  }
}

/// Sample months for the collection: the running month and three
/// finalized ones, one before October 2026 (read as Green Slope).
class ProtoMonth {
  final int year, month;
  final ClimbTheme theme;
  final MedalTier? tier;
  final int score, maxScore;
  final bool running;
  const ProtoMonth(
      this.year, this.month, this.theme, this.tier, this.score, this.maxScore,
      {this.running = false});
}

const protoMonths = [
  ProtoMonth(2026, 11, ClimbThemes.emberPeak, MedalTier.silver, 160, 300,
      running: true),
  ProtoMonth(2026, 10, ClimbThemes.greenSlope, MedalTier.gold, 251, 310),
  ProtoMonth(2026, 9, ClimbThemes.greenSlope, MedalTier.bronze, 96, 300),
  ProtoMonth(2026, 8, ClimbThemes.greenSlope, null, 41, 310),
];

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// N10, one proposal: each month a row of its theme's three medals,
/// earned ones in colour (a Gold month lights all three), the rest faded;
/// the running month first, with the tiers already reached lit (N8 makes
/// a tier certain when it is crossed). The Welcome row keeps its place
/// with the Welcome image instead of the trophy icon.
class ProtoCollection extends StatelessWidget {
  /// The running month's three medals: disc size.
  final double currentDisc;

  /// A finalized month's three medals: disc size.
  final double historyDisc;

  /// The Welcome image's disc in its row.
  final double welcomeDisc;

  const ProtoCollection(
      {super.key,
      required this.currentDisc,
      required this.historyDisc,
      required this.welcomeDisc});

  static const welcomeKey = ValueKey('proto_welcome');
  static const currentKey = ValueKey('proto_current');
  static const historyKey = ValueKey('proto_history_first');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget three(ProtoMonth m, double disc) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in MedalTier.values) ...[
              if (t != MedalTier.bronze) SizedBox(width: disc * .12),
              ProtoMedal(
                  name: medalName(m.theme.id, t),
                  disc: disc,
                  earned: m.tier != null && t.index <= m.tier!.index),
            ],
          ],
        );
    final current = protoMonths.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DecoratedBox(
        key: welcomeKey,
        decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ProtoMedal(name: 'medal_welcome', disc: welcomeDisc),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Welcome to the climb',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Earned', style: muted),
                ])),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      DecoratedBox(
        key: currentKey,
        decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This month · ${current.theme.name}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Center(child: three(current, currentDisc)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: current.score / current.maxScore),
            const SizedBox(height: 8),
            Text('${current.score} / ${current.maxScore} points · '
                '${current.tier!.label} reached'),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      Text('History',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final (i, m) in protoMonths.skip(1).indexed) ...[
        if (i > 0) const SizedBox(height: 12),
        Row(key: i == 0 ? historyKey : null, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_monthNames[m.month - 1]} ${m.year}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(m.theme.name, style: muted),
              Text(
                  m.tier == null
                      ? 'No medal · ${m.score} points'
                      : '${m.tier!.label} · ${m.score} points',
                  style: muted),
            ]),
          ),
          three(m, historyDisc),
        ]),
      ],
    ]);
  }
}

/// A copy of `MonthCardSheet`'s summary content (handle, title, medal row,
/// stats, near-miss line, next month, button) with the medal row's image
/// swapped; [medal] null keeps the content without a medal row.
class ProtoMonthCardSummary extends StatelessWidget {
  final Widget medal;
  const ProtoMonthCardSummary({super.key, required this.medal});

  static const contentKey = ValueKey('proto_month_card');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    Widget stat(String value, String label) => Text.rich(TextSpan(children: [
          TextSpan(
              text: value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          TextSpan(
              text: ' $label',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ]));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        key: contentKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Your October climb',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            medal,
            const SizedBox(width: 10),
            Expanded(
                child: Text('Silver medal',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 20, runSpacing: 4, children: [
            stat('24 / 31', 'steps'),
            stat('228', 'points'),
          ]),
          const SizedBox(height: 6),
          Text('Just 5 points from Gold',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Next: November · Ember Peak',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {}, child: const Text('See the mountain')),
        ],
      ),
    );
  }
}

/// A copy of the Day-0 result screen's `_WelcomeBadgeCard` with the
/// composed image ([image], or the trophy circle of today when null), and
/// the same card as N8's tier celebration ([title], [body]).
class ProtoCelebrationCard extends StatelessWidget {
  final Widget? image;
  final String title;
  final String body;
  const ProtoCelebrationCard(
      {super.key, this.image, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onContainer = colorScheme.onSecondaryContainer;
    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          children: [
            image ??
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onContainer.withValues(alpha: 0.12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Icon(Icons.emoji_events_rounded,
                        color: onContainer, size: 44),
                  ),
                ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: onContainer)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: onContainer)),
          ],
        ),
      ),
    );
  }
}

/// Every medal the prototypes may draw.
List<String> allMedalNames() => [
      for (final t in ClimbThemes.all)
        for (final r in MedalTier.values) medalName(t.id, r),
      'medal_welcome',
    ];

/// Decodes every medal with real async, before the tree that draws them
/// is built: call inside `tester.runAsync` with any mounted [context].
Future<void> precacheMedals(BuildContext context) => Future.wait([
      for (final n in allMedalNames()) precacheImage(medalImage(n), context),
    ]);
