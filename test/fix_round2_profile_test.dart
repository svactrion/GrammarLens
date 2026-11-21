import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/profile_stage.dart';

/// Fix round 2, item 4: V23's navy ribbon, with the board's values.
void main() {
  // Measured in the app's own font (the test font's square glyphs would
  // wrap the line).
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  Future<void> pumpStage(WidgetTester tester,
      {double width = 390,
      String name = 'Ada',
      bool reduce = false,
      bool settle = true,
      TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = Size(width, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 844), disableAnimations: reduce),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProfileStage(
                hero: Avatar.fox,
                name: name,
                since: DateTime(2026, 11, 2),
                onChange: () {},
                onEditName: () {},
              ),
            ),
          ),
        ),
      ),
    ));
    if (settle) await tester.pumpAndSettle();
  }

  final ribbon = find.byKey(ProfileStage.ribbonKey);

  testWidgets(
      'the board\'s body: 62 tall (fix round 3, C5: 390 − 60 − the two '
      '26 pt tails = 278 wide; was 286), radius 16, #1B4FB0 → navy, a '
      '5 pt #082A6B lip', (tester) async {
    await pumpStage(tester);
    expect(tester.getSize(ribbon), const Size(278, 62));
    final box = tester.widget<Container>(ribbon).decoration! as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(16));
    expect((box.gradient! as LinearGradient).colors,
        [AppColors.ribbonTop, AppColors.light.navy]);
    expect(box.boxShadow!.single.color, AppColors.ribbonLip);
    expect(box.boxShadow!.single.offset, const Offset(0, 5));
    // Centred under the stage.
    expect(tester.getCenter(ribbon).dx, closeTo(195, .5));
  });

  testWidgets(
      'the name 23/900 white, the line 12/700 #C9D6FF with "since", '
      'the 40 × 40 pencil at 14 % white', (tester) async {
    await pumpStage(tester);
    final name = tester.widget<Text>(find.byKey(ProfileStage.nameKey));
    expect(name.style!.fontSize, 23);
    expect(name.style!.fontWeight, FontWeight.w900);
    expect(name.style!.color, AppColors.light.onNavy);
    final line = tester.widget<Text>(find.byKey(ProfileStage.climbingKey));
    expect(line.data, 'Climbing with Fox · since Nov 2026');
    // C5: a line that just fits keeps (nearly) its 12 pt.
    expect(line.style!.fontSize, closeTo(12, .1));
    expect(line.style!.color, AppColors.onRibbonMuted);
    final pencil = find.descendant(
        of: find.byKey(ProfileStage.pencilKey),
        matching: find.byType(Container));
    expect(tester.getSize(pencil), const Size(40, 40));
    final deco = tester.widget<Container>(pencil).decoration! as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(12));
    expect(deco.color, AppColors.light.onNavy.withValues(alpha: .14));
    // 44 pt to tap.
    expect(
        tester.getSize(find.byKey(ProfileStage.pencilKey)), const Size(44, 44));
  });

  testWidgets('two 46 × 46 tails, 26 pt outside each end, 14 pt down',
      (tester) async {
    await pumpStage(tester);
    final body = tester.getRect(ribbon);
    final left = tester.getRect(find.byKey(ProfileStage.tailStartKey));
    final right = tester.getRect(find.byKey(ProfileStage.tailEndKey));
    expect(left.size, const Size(46, 46));
    expect(right.size, const Size(46, 46));
    expect(left.left, closeTo(body.left - 26, .01));
    expect(right.right, closeTo(body.right + 26, .01));
    expect(left.top, closeTo(body.top + 14, .01));
  });

  testWidgets('overlaps the stage\'s bottom by 40 pt', (tester) async {
    await pumpStage(tester);
    final stage = tester.getRect(find
        .ancestor(
            of: find.byKey(ProfileStage.changeKey),
            matching: find.byType(Stack))
        .first);
    // The stage container is the Stack's first child; its bottom is 40 pt
    // under the ribbon's top.
    final stageBox = tester.getRect(find
        .descendant(
            of: find.byType(ProfileStage), matching: find.byType(Container))
        .first);
    expect(stageBox.height, 210);
    expect(tester.getRect(ribbon).top, closeTo(stageBox.bottom - 40, .01));
    expect(stage, isNotNull);
  });

  testWidgets(
      'settles from 12 pt below in 300 ms (easeOutBack); still '
      'under Reduce Motion', (tester) async {
    await pumpStage(tester, settle: false);
    final start = tester.getTopLeft(ribbon).dy;
    await tester.pump(const Duration(milliseconds: 300));
    final end = tester.getTopLeft(ribbon).dy;
    expect(start - end, closeTo(12, .5));
    await pumpStage(tester, reduce: true, settle: false);
    await tester.pump();
    final still = tester.getTopLeft(ribbon).dy;
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(ribbon).dy, still);
  });

  testWidgets(
      'a 20-character name stays on one line; at 320 pt the tails '
      'stay on screen; RTL mirrors the V cuts', (tester) async {
    await pumpStage(tester, width: 320, name: 'Maximiliana Johanson');
    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(find.byKey(ProfileStage.nameKey));
    expect(name.maxLines, 1);
    expect(
        tester.getSize(find.byKey(ProfileStage.nameKey)).height, lessThan(30));
    for (final key in [ProfileStage.tailStartKey, ProfileStage.tailEndKey]) {
      final r = tester.getRect(find.byKey(key));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
    }
    await pumpStage(tester, direction: TextDirection.rtl);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(ribbon), const Size(278, 62));
  });
}
