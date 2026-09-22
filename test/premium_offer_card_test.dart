import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/premium_offer_card.dart';

/// The offer card's benefit icons: the right light/dark variant, decorative
/// for screen readers, a fixed 24 pt at every text size, and no overflow at
/// the smallest width with the largest text.

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  double width = 390,
  AppTextSize textSize = AppTextSize.medium,
  double systemScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PremiumOfferCard(onSeePremium: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Image> _icons(WidgetTester tester) =>
    tester.widgetList<Image>(find.byType(Image)).toList();

String _assetName(Image image) => (image.image as AssetImage).assetName;

void main() {
  test('iconAsset picks the variant from the brightness', () {
    expect(PremiumOfferCard.iconAsset('ic_topic_practice', Brightness.light),
        'assets/icons/ic_topic_practice_light.png');
    expect(PremiumOfferCard.iconAsset('ic_topic_practice', Brightness.dark),
        'assets/icons/ic_topic_practice_dark.png');
  });

  for (final brightness in Brightness.values) {
    final variant = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('$variant theme: each benefit shows its $variant icon',
        (tester) async {
      await _pump(tester, brightness: brightness);

      final icons = _icons(tester);
      expect(icons.map(_assetName), [
        'assets/icons/ic_topic_practice_$variant.png',
        'assets/icons/ic_daily_sessions_$variant.png',
      ]);
      // Every chosen file is really in the bundle.
      for (final icon in icons) {
        final data = await rootBundle.load(_assetName(icon));
        expect(data.lengthInBytes, greaterThan(0), reason: _assetName(icon));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('icons are decorative: no semantics of their own',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, brightness: Brightness.light);

    for (final icon in _icons(tester)) {
      expect(icon.excludeFromSemantics, isTrue);
    }
    // The card reads as one node; the icons add nothing to it, so each
    // benefit title is read exactly once.
    final label = tester.getSemantics(find.text('Topic Practice')).label;
    for (final text in [
      'Topic Practice',
      'Focus on the areas you need',
      'More Daily Sessions',
      'Build your progress faster',
    ]) {
      // Whole lines: the message itself also mentions "Topic Practice".
      expect(label.split('\n').where((line) => line == text).length, 1,
          reason: text);
    }
    expect(label, isNot(contains('ic_')));
    expect(label, isNot(contains('.png')));
    semantics.dispose();
  });

  testWidgets(
      '320 pt, Large text, 2.0 system scale: no overflow, icons stay 24 pt, '
      'stacked, each icon aligned with its own title', (tester) async {
    await _pump(
      tester,
      brightness: Brightness.dark,
      width: 320,
      textSize: AppTextSize.large,
      systemScale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('premiumOfferBenefitsColumn')), findsOneWidget);
    final card = tester.getRect(find.byType(PremiumOfferCard));
    final images = find.byType(Image);
    for (var i = 0; i < 2; i++) {
      final icon = tester.getRect(images.at(i));
      expect(icon.size, const Size(24, 24));
      expect(icon.left, greaterThanOrEqualTo(card.left));
    }
    for (final (index, title, detail) in [
      (0, 'Topic Practice', 'Focus on the areas you need'),
      (1, 'More Daily Sessions', 'Build your progress faster'),
    ]) {
      final icon = tester.getRect(images.at(index));
      final titleRect = tester.getRect(find.text(title));
      final detailRect = tester.getRect(find.text(detail));
      // Top-aligned with its title, text to its right and inside the card.
      expect(icon.top, titleRect.top);
      expect(titleRect.left, greaterThan(icon.right));
      expect(detailRect.left, titleRect.left);
      expect(titleRect.right, lessThanOrEqualTo(card.right));
      expect(detailRect.right, lessThanOrEqualTo(card.right));
    }
    // Both icons share one left edge in the stacked layout.
    expect(
        tester.getRect(images.at(0)).left, tester.getRect(images.at(1)).left);
  });

  testWidgets('side by side on a wide screen, icons still 24 pt',
      (tester) async {
    await _pump(tester, brightness: Brightness.light, width: 430);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('premiumOfferBenefitsRow')), findsOneWidget);
    final images = find.byType(Image);
    expect(tester.getRect(images.at(0)).top, tester.getRect(images.at(1)).top);
    for (var i = 0; i < 2; i++) {
      expect(tester.getSize(images.at(i)), const Size(24, 24));
    }
  });
}
