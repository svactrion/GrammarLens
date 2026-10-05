// 1.2.0 Batch 7, part B: the real Profile (SettingsScreen in the real nav
// shell) with the real font, medal and avatar images, in a window tall
// enough to show the whole page; light and dark, and the medal detail.
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_profile \
//     flutter test tool/design_measure/v120/profile_render_test.dart
//
// DESIGN_MEASURE_WIDTHS (320,390,430), DESIGN_MEASURE_SIZES (small,medium,
// large), DESIGN_MEASURE_MODES (light,dark), DESIGN_MEASURE_SCORE (the
// running month's points, October 2026) and DESIGN_MEASURE_NAME override
// the defaults (390, medium, both modes, 7, "Ahmet"). DESIGN_MEASURE_HISTORY=1
// adds three finalized months and the Welcome badge.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Storage extends StorageService {
  final int score;
  final bool history;
  _Storage(this.score, this.history);

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      MonthlyMedalProgress(
        year: 2026,
        month: 10,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 10),
        activeDays: (score / 8).ceil(),
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        if (history)
          for (final (m, tier) in [
            (9, MedalTier.gold),
            (8, MedalTier.silver),
            (7, MedalTier.bronze),
          ])
            MonthlyMedalResult(
              year: 2026,
              month: m,
              score: 200,
              maxScore: MonthlyMedalRules.maxScore(2026, m),
              activeDays: 20,
              correct: 0,
              wrong: 0,
              skipped: 0,
              tier: tier,
              ruleVersion: 1,
              finalizedAt: DateTime(2026, m + 1, 1),
            ),
      ];

  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => WelcomeBadge(
      earnedAt: DateTime(2026, 9, 2), ruleVersion: 1, backfilled: false);

  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => const {};
}

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  List<String> env(String name, String fallback) =>
      (Platform.environment[name] ?? fallback)
          .split(',')
          .map((s) => s.trim())
          .toList();
  final widths = [
    for (final w in env('DESIGN_MEASURE_WIDTHS', '390')) double.parse(w)
  ];
  final sizes = [
    for (final s in env('DESIGN_MEASURE_SIZES', 'medium'))
      AppTextSize.values.byName(s)
  ];
  final modes = [
    for (final m in env('DESIGN_MEASURE_MODES', 'light,dark'))
      Brightness.values.byName(m)
  ];
  final score = int.parse(Platform.environment['DESIGN_MEASURE_SCORE'] ?? '7');
  final name = Platform.environment['DESIGN_MEASURE_NAME'] ?? 'Ahmet';
  final history = Platform.environment['DESIGN_MEASURE_HISTORY'] == '1';

  for (final width in widths) {
    for (final size in sizes) {
      for (final b in modes) {
        final file = 'profile_${width.toInt()}_${size.name}_${b.name}_s$score'
            '${history ? '_history' : ''}${name == 'Ahmet' ? '' : '_name${name.length}'}';
        testWidgets(file, (tester) async {
          DebugTools.enabledForTesting = false;
          addTearDown(() => DebugTools.enabledForTesting = true);
          tester.view.physicalSize = Size(width, 2200) * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding =
              const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(b, textSize: size),
              home: FloatingNavShell(
                body: SettingsScreen(
                  active: true,
                  themeMode: AppThemeMode.light,
                  onSelectThemeMode: (_) {},
                  textSize: size,
                  onSelectTextSize: (_) {},
                  profile: UserProfile(
                          name: name, learningGoal: LearningGoal.general)
                      .copyWith(avatar: Avatar.values.last),
                  storageService: _Storage(score, history),
                  onProfileUpdated: (_) {},
                  analyticsService: AnalyticsService(),
                  onResetOnboarding: () {},
                ),
                tabs: const [
                  NavShellTab(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home'),
                  NavShellTab(
                      icon: Icons.history_outlined,
                      activeIcon: Icons.history,
                      label: 'Review'),
                  NavShellTab(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile'),
                ],
                selectedIndex: 2,
                onTabChange: (_) {},
              ),
            ),
          ));
          await tester.pumpAndSettle();
          Future<void> decode() => tester.runAsync(() async {
                await Future.wait([
                  for (final e in find
                      .byType(MedalBadge)
                      .evaluate()
                      .map((e) => e.widget as MedalBadge))
                    precacheImage(AssetImage(e.asset), key.currentContext!),
                  precacheImage(AssetImage(Avatar.values.last.assetPath),
                      key.currentContext!),
                ]);
              });
          await decode();
          await tester.pump();
          Future<void> shoot(String name) => tester.runAsync(() async {
                final img = await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 3);
                final bytes =
                    await img.toByteData(format: ui.ImageByteFormat.png);
                File('$out/$name.png')
                    .writeAsBytesSync(bytes!.buffer.asUint8List());
              });
          await shoot(file);
          expect(tester.takeException(), isNull);

          // The running month's detail.
          await tester
              .tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 10)));
          await tester.pumpAndSettle();
          await decode();
          await tester.pump();
          await shoot('${file}_detail');
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(4, 300));
          await tester.pumpAndSettle();

          // The name being edited.
          await tester.tap(find.text('Edit'));
          await tester.pumpAndSettle();
          await shoot('${file}_edit');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
