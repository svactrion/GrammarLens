// 1.1.0 release preparation, step 2: the iPad check. The real components
// of the screens 1.1.0 changed, rendered at three iPad sizes in portrait
// (the only orientation the app allows on iPad; upside-down portrait lays
// out the same), light and dark, Medium (the default) and Large (the
// largest) text, the latter only through buildAppTheme(textSize:).
//
// Screens (IPAD_CASES, comma list; all when unset):
//   launch          the launch splash's finished frame (LaunchSplash)
//   home_day1/15/31 Home's daily framing, October 2026 (Green Slope)
//   card_summary    Home with the month card open, 1 November 2026 (Ember
//   card_fresh      Peak), Silver near-miss summary / fresh start
//   kc              the first run's zoom held at its first frame (K-c)
//   label           the save point label after the hop onto C1
//   cel_welcome     the celebration layer over the Daily Test result
//   cel_gold        screen: the Welcome badge, and Gold
//   result          the Daily Test result screen, no celebration
//   profile         Profile (SettingsScreen in the real shell), twelve
//                   finalized months, the Welcome badge, a running month
//   profile_detail  the same with October's medal detail open
//   avatar_picker   the avatar picker
// Devices (IPAD_DEVICES): 13in 1032 × 1376, 11in 834 × 1194, mini
// 744 × 1133, all 2x, safe areas 24 pt top / 20 pt bottom (assumed for
// every current iPad with a home indicator; not read from a simulator).
//
// Writes one PNG per case at 2x (the device's real pixels) and
// ipad_numbers.txt (what each case measures; light mode only, dark lays
// out the same).
//
//   DESIGN_MEASURE_OUT=build/design_measure/ipad \
//     flutter test tool/design_measure/release/ipad_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/release_ipad_sheet.py
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart'
    show RenderParagraph, RenderRepaintBoundary;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_zoom.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

/// The scene images' width in pixels (every theme, both modes).
const _assetWidth = 1536.0;

/// Size, pixel ratio and safe areas (status bar; home indicator). The
/// iPads' 24 / 20 pt are assumed, not read from a simulator. The iPhones
/// are the existing tools' four screens, for P1's before/after check
/// (IPAD_DEVICES=iphone320,iphone375se,iphone375,iphone430).
const _allDevices = {
  '13in': (1032.0, 1376.0, 2.0, 24.0, 20.0),
  '11in': (834.0, 1194.0, 2.0, 24.0, 20.0),
  'mini': (744.0, 1133.0, 2.0, 24.0, 20.0),
  'iphone320': (320.0, 568.0, 2.0, 20.0, 0.0),
  'iphone375se': (375.0, 667.0, 2.0, 20.0, 0.0),
  'iphone375': (375.0, 812.0, 3.0, 47.0, 34.0),
  'iphone430': (430.0, 932.0, 3.0, 59.0, 34.0),
};
const _ipads = ['13in', '11in', 'mini'];

const _allCases = [
  'launch', 'home_day1', 'home_day15', 'home_day31', 'card_summary', //
  'card_fresh', 'kc', 'label', 'cel_welcome', 'cel_gold', 'result', //
  'profile', 'profile_detail', 'avatar_picker',
  // Step 3 of P1: the rest of the app.
  'welcome', 'onboarding', 'daily_test', 'topic_list', 'practice', //
  'practice_results', 'review', 'weak_spot', 'profile_bottom', 'premium', //
  'ai_consent',
];

List<String>? _env(String name) =>
    Platform.environment[name]?.split(',').map((s) => s.trim()).toList();

const _navTabs = [
  NavShellTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  NavShellTab(
      icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Review'),
  NavShellTab(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile'),
];

/// Home on a day of October 2026; also the first run (K-c held) and the
/// label's hop.
class _HomeStorage extends DesignStorage {
  _HomeStorage({required super.steps, super.correct});
  @override
  Future<bool> hasOneTimeFlag(String key) async => false;
  @override
  Future<bool> claimOneTimeFlag(String key) async => true;
}

/// A returning user on 1 November 2026 (Batch 6's month card measure):
/// October with [steps] steps and [score] points, or no step.
class _CardStorage extends StorageService {
  final int steps, score;
  _CardStorage({required this.steps, required this.score});

  @override
  Future<bool> hasOneTimeFlag(String key) async => false;
  @override
  Future<bool> claimOneTimeFlag(String key) async => true;
  @override
  Future<bool> hasClimbHistoryBefore(int year, int month) async => true;
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: month == 10 ? steps : 0, correct: 0, wrong: 0, skipped: 0);
  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        _result(2026, 10, score, activeDays: steps),
      ];
  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => null;
  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => null;
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      const [];
}

/// A Daily Test save: the Welcome badge ([welcome]), crossing [tier], or
/// neither (well under Bronze).
class _ResultStorage extends StorageService {
  final bool welcome;
  final MedalTier? tier;
  _ResultStorage({this.welcome = false, this.tier});

  @override
  Future<bool> completeDailyTest(
          Map<String, String> answers, List<ErrorEntry> errorEntries,
          {String? day, DateTime? completedAt}) async =>
      welcome;
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    if (tier == null) return (steps: 3, correct: 10, wrong: 2, skipped: 0);
    final score = MonthlyMedalRules.threshold(year, month, tier!);
    return (steps: 20, correct: score ~/ 2, wrong: score % 2, skipped: 0);
  }

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
}

class _NoPrefetch extends DailyTestService {
  _NoPrefetch(StorageService storage)
      : super(claudeService: ClaudeService(), storageService: storage);
  @override
  Future<void> prefetchSet(String day) async {}
}

MonthlyMedalResult _result(int year, int month, int score,
        {int activeDays = 20}) =>
    MonthlyMedalResult(
        year: year,
        month: month,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(year, month),
        activeDays: activeDays,
        correct: 0,
        wrong: 0,
        skipped: 0,
        tier: MonthlyMedalRules.tierFor(year: year, month: month, score: score),
        ruleVersion: 1,
        finalizedAt: DateTime(year, month + 1, 1));

const _themes = ['green_slope', 'ember_peak', 'glacier_peak', 'red_canyon'];

/// Profile with Batch 5's "twelve" case: the Welcome badge, December 2025
/// to October 2026 finalized with every tier and theme, November running
/// at Silver (Ember Peak).
class _ProfileStorage extends StorageService {
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];
  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      MonthlyMedalProgress(
          year: 2026,
          month: 11,
          score: 160,
          maxScore: MonthlyMedalRules.maxScore(2026, 11),
          activeDays: 18,
          correct: 0,
          wrong: 0,
          skipped: 0);
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        for (var i = 10; i >= 0; i--)
          _result(
              2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1, [96, 170, 251][i % 3]),
      ];
  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => WelcomeBadge(
      earnedAt: DateTime(2026, 8, 3), ruleVersion: 1, backfilled: false);
  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => {
        for (var i = 0; i < 11; i++)
          (2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1): _themes[i % 4],
        (2026, 11): 'ember_peak',
      };
}

/// The climb's images for [theme] in [b], and every medal.
List<String> _climbAssets(ClimbTheme theme, Brightness b) => [
      for (final a in Avatar.values) a.assetPath,
      theme.backgroundFor(b),
      theme.kcBackdropFor(b),
      for (final p in [...ClimbSavePoints.all, ...ClimbSavePoints.decor])
        p.asset,
      ClimbSavePoints.assetFor('summit_flag'),
      ClimbSavePoints.flameAsset,
      ClimbSavePoints.flagBaseAsset,
      ClimbSavePoints.pennantAsset,
      ..._medalAssets,
    ];

final _medalAssets = [
  for (final t in ClimbThemes.all)
    for (final tier in MedalTier.values) MedalArt.monthly(t.id, tier),
  MedalArt.welcome,
];

Widget _shell(Widget body, int index) => FloatingNavShell(
    body: body, tabs: _navTabs, selectedIndex: index, onTabChange: (_) {});

Widget _home(StorageService storage, DateTime clock,
        {bool firstRunZoom = false, ({String day, int step})? pending}) =>
    _shell(
        HomeScreen(
          active: true,
          userName: 'Ada',
          avatar: Avatar.values.first,
          claudeService: ClaudeService(),
          storageService: storage,
          analyticsService: AnalyticsService(),
          subscriptionService: DesignSubs(),
          clock: () => clock,
          firstRunZoom: firstRunZoom,
          initialPendingClimb: pending,
        ),
        0);

String _f(num v, [int d = 1]) => v.toStringAsFixed(d);
String _r(Rect r) =>
    '${_f(r.width)} × ${_f(r.height)} at (${_f(r.left)}, ${_f(r.top)})';

void main() {
  final out = outDir();
  final rows = <String, List<String>>{};
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() {
    final lines = [
      '1.1.0 release step 2: the iPad check on the real components. Points '
          '(1 pt = 2 px on every iPad here). Portrait; safe areas '
          '24 / 20 pt on iPads (assumed). Light mode '
          '(dark lays out the same). Exceptions: the framework errors the '
          'case raised (overflow and the like); "none" when none.',
      '',
    ];
    // For comparison, iPhones, computed (not rendered) from Home's card
    // padding (4.5 % of the width, 16-28 pt) and ClimbCamera.
    lines.add('== iPhone reference (computed, not rendered) ==');
    for (final (pt, dpr) in [(320.0, 2.0), (375.0, 2.0), (430.0, 3.0)]) {
      final card = pt - 2 * (pt * .045).clamp(16.0, 28.0);
      final px = ClimbCamera(card).imageSize.width * dpr;
      lines.add('${pt.toInt()} pt @${dpr.toInt()}x: window ${_f(card)} × 350 '
          '(aspect ${_f(card / 350, 2)}:1), image ${_f(px, 0)} px wide: '
          '${_f(px / _assetWidth, 2)}× the asset');
    }
    lines.add('');
    for (final c in _allCases) {
      if (rows[c] == null) continue;
      lines
        ..add('== $c ==')
        ..addAll(rows[c]!)
        ..add('');
    }
    File('$out/ipad_numbers.txt').writeAsStringSync(lines.join('\n'));
  });

  final cases = _env('IPAD_CASES') ?? _allCases;
  final devices = _env('IPAD_DEVICES') ?? _ipads;
  for (final c in cases) {
    for (final d in devices) {
      final (w, h, dpr, safeTop, safeBottom) = _allDevices[d]!;
      for (final b in Brightness.values) {
        for (final size in [AppTextSize.medium, AppTextSize.large]) {
          final name = 'ipad_${c}_${d}_${b.name}_${size.name}';
          testWidgets(name, (tester) async {
            tester.view.physicalSize = Size(w, h) * dpr;
            tester.view.devicePixelRatio = dpr;
            tester.view.padding =
                FakeViewPadding(top: safeTop * dpr, bottom: safeBottom * dpr);
            addTearDown(tester.view.reset);
            final key = GlobalKey();
            final notes = <String>[];
            MaterialApp app(Widget home) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(b, textSize: size),
                  builder: (context, child) =>
                      RepaintBoundary(key: key, child: child),
                  home: home,
                );
            Future<void> precache(List<String> assets) => tester
                .runAsync(() => Future.wait([
                      for (final a in assets)
                        precacheImage(AssetImage(a), key.currentContext!),
                    ]))
                .then((_) {});

            final october = ClimbThemeRotation.shownFor(2026, 10);
            final november = ClimbThemeRotation.shownFor(2026, 11);

            switch (c) {
              case 'launch':
                await tester.pumpWidget(RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                    data: MediaQueryData(
                        size: Size(w, h),
                        platformBrightness: b,
                        padding:
                            EdgeInsets.only(top: safeTop, bottom: safeBottom)),
                    child: const LaunchSplash(),
                  ),
                ));
                await tester.pump(LaunchTiming.intro);
                final logo = tester.getRect(find.byType(LaunchLogo));
                final word = tester.getRect(find.text('GrammarLens'));
                notes.add('logo ${_r(logo)}; wordmark ${_r(word)}; '
                    'logo is ${_f(logo.width * 100 / w)} % of the width');

              case 'home_day1' || 'home_day15' || 'home_day31':
                final day = int.parse(c.substring('home_day'.length));
                await tester.pumpWidget(app(_home(
                    _HomeStorage(steps: day, correct: day * 3),
                    DateTime(2026, 10, day, 14))));
                await precache(_climbAssets(october, b));
                await tester.pump();
                await tester.pump(const Duration(seconds: 2));
                await tester.pump();
                _measureScene(tester, notes, w, h, day);

              case 'card_summary' || 'card_fresh':
                final storage = c == 'card_summary'
                    ? _CardStorage(steps: 24, score: 228)
                    : _CardStorage(steps: 0, score: 0);
                await tester.pumpWidget(app(_shell(
                    HomeScreen(
                      active: true,
                      userName: 'Ada',
                      avatar: Avatar.values.first,
                      claudeService: ClaudeService(),
                      storageService: storage,
                      analyticsService: AnalyticsService(),
                      subscriptionService: DesignSubs(),
                      clock: () => DateTime(2026, 11, 1, 9),
                    ),
                    0)));
                await precache(_climbAssets(november, b));
                await tester.pumpAndSettle();
                expect(find.byType(MonthCardSheet), findsOneWidget);
                // The sheet's drawn surface (Material 3 caps a modal sheet's
                // width), not the full-width box around it.
                final sheet = tester.getRect(find
                    .descendant(
                        of: find.byType(BottomSheet),
                        matching: find.byType(Material))
                    .first);
                final window = tester.getRect(find.byType(MonthlyMountain));
                final hidden = (window.bottom.clamp(sheet.top, h) -
                        window.top.clamp(sheet.top, h))
                    .clamp(0.0, window.height);
                final kcLeft = window.left + ClimbOverview.band(window.width);
                final kcRight = window.right - ClimbOverview.band(window.width);
                final coversSides =
                    sheet.left <= kcLeft && sheet.right >= kcRight;
                final content =
                    tester.getSize(find.byKey(MonthCardSheet.contentKey));
                final room =
                    tester.getSize(find.byKey(MonthCardSheet.scrollKey));
                notes.add(
                    'sheet ${_r(sheet)} (${_f(sheet.width * 100 / w, 0)} % '
                    'of the width, ${_f(sheet.height * 100 / h, 0)} % of the '
                    'height); content ${_f(content.height)} in '
                    '${_f(room.height)} (scrolls: '
                    '${content.height > room.height + .5 ? 'yes' : 'no'})');
                notes.add('mountain window ${_r(window)}: '
                    '${_f(hidden)} pt of its ${_f(window.height, 0)} under the '
                    'sheet (${_f(hidden * 100 / window.height, 0)} %); the '
                    'K-c image spans x ${_f(kcLeft)}–${_f(kcRight)}, the '
                    'sheet x ${_f(sheet.left)}–${_f(sheet.right)}'
                    '${coversSides ? '' : ' (the image shows beside the sheet)'}; '
                    'START (298.5 pt into the window) above the sheet: '
                    '${window.top + 298.5 < sheet.top ? 'yes' : 'no'}');

              case 'kc':
                await tester.pumpWidget(app(_home(
                    _HomeStorage(steps: 0), DateTime(2026, 10, 1, 9),
                    firstRunZoom: true)));
                await precache(_climbAssets(october, b));
                await tester.pump();
                final mountain = tester
                    .widget<MonthlyMountain>(find.byType(MonthlyMountain));
                final z = mountain.zoom?.value;
                notes.add('zoom progress at capture: '
                    '${z == null ? 'no zoom' : _f(z, 3)} (0 = K-c)');
                final window = tester.getRect(find.byType(MonthlyMountain));
                final band = ClimbOverview.band(window.width);
                final kcW = window.width - 2 * band;
                notes.add('window ${_r(window)}; K-c image '
                    '${_f(kcW)} × ${_f(ClimbCamera.windowHeight)} pt '
                    '(${_f(kcW * 2 / _assetWidth, 2)} × the asset in px); '
                    'side bands ${_f(band)} pt each '
                    '(${_f(band * 2 * 100 / window.width, 0)} % of the window)');

              case 'label':
                final p = ClimbSavePoints.all.first;
                final step = p.reachedOn(31);
                await tester.pumpWidget(app(_home(
                    _HomeStorage(steps: step, correct: step * 3),
                    DateTime(2026, 10, 31, 14),
                    pending: (day: '2026-10-31', step: 1))));
                await precache(_climbAssets(october, b));
                for (var i = 0; i < 100; i++) {
                  await tester.pump(const Duration(milliseconds: 25));
                }
                final label = find.byKey(MonthlyMountain.labelKey);
                expect(label, findsOneWidget);
                final box = tester.getRect(label);
                final window = tester.getRect(find.byType(MonthlyMountain));
                final style = tester
                    .widgetList<Text>(
                        find.descendant(of: label, matching: find.byType(Text)))
                    .map((t) => t.style?.fontSize)
                    .whereType<double>()
                    .toList();
                notes.add('${p.clearing} ${p.name} on step $step: label '
                    '${_r(box)}, ${_f(box.width * 100 / window.width, 0)} % of '
                    'the ${_f(window.width)} pt window'
                    '${style.isEmpty ? '' : '; text ${style.map(_f).join(' / ')} pt'}');
                _measureScene(tester, notes, w, h, step);

              case 'cel_welcome' || 'cel_gold' || 'result':
                final storage = switch (c) {
                  'cel_welcome' => _ResultStorage(welcome: true),
                  'cel_gold' => _ResultStorage(tier: MedalTier.gold),
                  _ => _ResultStorage(),
                };
                await tester.pumpWidget(app(DailyTestResultScreen(
                  dailyTestSet: DailyTestSet(
                      day: '2026-10-14',
                      questions: kDayZeroQuestions,
                      source: DailyTestSource.shared),
                  answers: {
                    for (final (i, q) in kDayZeroQuestions.indexed)
                      q.item.id:
                          c == 'result' && i == 0 ? 'goed' : q.correctAnswer
                  },
                  dailyTestService: _NoPrefetch(storage),
                  analyticsService: AnalyticsService(),
                  isDay0: c == 'cel_welcome',
                  onDone: () {},
                )));
                await precache(_medalAssets);
                await tester.pumpAndSettle();
                if (c == 'result') {
                  expect(find.byType(MedalCelebration), findsNothing);
                  final cards = tester.widgetList(find.byType(Card)).length;
                  final first = find.byType(Card).first;
                  notes.add(
                      '$cards cards; the first ${_r(tester.getRect(first))} '
                      '(${_f(tester.getRect(first).width * 100 / w, 0)} % of the '
                      'width)');
                  // How many characters of the first explanation's text fit
                  // on one line at its own width and style: the explanation
                  // repeated until it wraps, the first line's length.
                  final explanation = kDayZeroQuestions.first.explanation!;
                  final text = find.text(explanation);
                  final paragraph = tester.renderObject<RenderParagraph>(text);
                  final painter = TextPainter(
                      text: TextSpan(
                          text: List.filled(6, explanation).join(' '),
                          style: tester.widget<Text>(text).style ??
                              DefaultTextStyle.of(tester.element(text)).style),
                      textScaler: paragraph.textScaler,
                      textDirection: TextDirection.ltr)
                    ..layout(maxWidth: paragraph.constraints.maxWidth);
                  final line = painter
                      .getLineBoundary(const TextPosition(offset: 0))
                      .end;
                  notes.add(
                      'explanation text box ${_f(paragraph.constraints.maxWidth)} '
                      'pt wide: $line characters on a full line');
                  painter.dispose();
                } else {
                  expect(find.byType(MedalCelebration), findsOneWidget);
                  final group = tester.getRect(find
                      .descendant(
                          of: find.byType(MedalCelebration),
                          matching: find.byType(Column))
                      .first);
                  final medal = tester.getRect(find
                      .descendant(
                          of: find.byType(MedalCelebration),
                          matching: find.byType(Image))
                      .first);
                  notes.add('group ${_r(group)} '
                      '(${_f(group.height * 100 / h, 0)} % of the height, '
                      '${_f(group.width * 100 / w, 0)} % of the width); medal '
                      '${_f(medal.width)} pt (${_f(medal.width * 100 / w, 0)} % '
                      'of the width)');
                }

              case 'profile' || 'profile_detail':
                await tester.pumpWidget(app(_shell(
                    SettingsScreen(
                      active: true,
                      themeMode: AppThemeMode.system,
                      onSelectThemeMode: (_) {},
                      textSize: size,
                      onSelectTextSize: (_) {},
                      profile: UserProfile(
                          name: 'Ada',
                          learningGoal: LearningGoal.general,
                          avatar: Avatar.values.first),
                      storageService: _ProfileStorage(),
                      onProfileUpdated: (_) {},
                      onResetOnboarding: () {},
                      subscriptionService: DesignSubs(),
                      analyticsService: AnalyticsService(),
                    ),
                    2)));
                await precache([
                  ..._medalAssets,
                  for (final a in Avatar.values) a.assetPath
                ]);
                await tester.pumpAndSettle();
                expect(find.byType(MonthlyMedalCollection), findsOneWidget);
                final shelf =
                    tester.getRect(find.byType(MonthlyMedalCollection));
                final slots = <Rect>[
                  tester.getRect(
                      find.byKey(MonthlyMedalCollection.welcomeSlotKey)),
                  for (var i = 0; i < 12; i++)
                    if (find
                        .byKey(MonthlyMedalCollection.slotKey(
                            2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1))
                        .evaluate()
                        .isNotEmpty)
                      tester.getRect(find.byKey(MonthlyMedalCollection.slotKey(
                          2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1))),
                ];
                final perRow = <double, int>{};
                for (final s in slots) {
                  perRow.update(s.top.roundToDouble(), (n) => n + 1,
                      ifAbsent: () => 1);
                }
                notes.add('shelf ${_r(shelf)}; ${slots.length} slots '
                    '(Welcome and 12 months), per row ${perRow.values.join(' / ')}; slot '
                    '${slots.isEmpty ? '-' : '${_f(slots.first.width)} × ${_f(slots.first.height)}'}');
                if (c == 'profile_detail') {
                  final slot =
                      find.byKey(MonthlyMedalCollection.slotKey(2026, 10));
                  await tester.ensureVisible(slot);
                  await tester.pumpAndSettle();
                  await tester.tap(slot);
                  await tester.pumpAndSettle();
                  final detail = find.byKey(MonthlyMedalCollection.detailKey);
                  expect(detail, findsOneWidget);
                  final r = tester.getRect(detail);
                  final medal = tester.getRect(find
                      .descendant(of: detail, matching: find.byType(Image))
                      .first);
                  notes.add('detail ${_r(r)} (${_f(r.width * 100 / w, 0)} % '
                      'of the width); medal ${_f(medal.width)} pt');
                }

              case 'avatar_picker':
                await tester.pumpWidget(app(AvatarPickerScreen(
                    currentAvatar: Avatar.values.first,
                    onAvatarChanged: (_) {},
                    heroTag: 'avatar')));
                await precache([for (final a in Avatar.values) a.assetPath]);
                await tester.pumpAndSettle();
                final tiles = find.byType(AvatarTile);
                final rects = [
                  for (final e in tiles.evaluate())
                    tester.getRect(find.byWidget(e.widget))
                ]..sort((a, b) => b.width.compareTo(a.width));
                final onScreen =
                    rects.where((r) => r.right > 0 && r.left < w).length;
                final cut = rects.where((r) => r.left < 0 || r.right > w);
                notes.add('cut by the screen edge: ${cut.length} '
                    '(${cut.map((r) => '${_f(math.min(r.right, w) - math.max(r.left, 0))} of ${_f(r.width)} pt shown').join(', ')})');
                notes.add('${rects.length} avatar tiles built, $onScreen on '
                    'screen; the largest ${rects.isEmpty ? '-' : '${_f(rects.first.width)} pt '
                        '(${_f(rects.first.width * 100 / w, 0)} % of the width)'}');

              case 'welcome':
                await tester
                    .pumpWidget(app(WelcomeScreen(onGetStarted: () {})));
                await tester.pump(const Duration(seconds: 3));
                notes.add(_column(tester, find.text('Get started'), w));

              case 'onboarding':
                await tester
                    .pumpWidget(app(OnboardingScreen(onComplete: (_) {})));
                await precache([for (final a in Avatar.values) a.assetPath]);
                await tester.pump(const Duration(seconds: 1));
                // Onboarding starts on a random avatar (PRD v2 §13.5); the
                // render jumps to the lap's first one, so runs compare.
                final pages =
                    tester.widget<PageView>(find.byType(PageView)).controller!;
                final page = pages.page!.round();
                pages.jumpToPage(page - page % Avatar.count);
                await tester.pump(const Duration(seconds: 1));
                notes.add(_column(tester, find.byType(TextField), w));

              case 'daily_test':
                final storage = _TestStorage();
                await tester.pumpWidget(app(DailyTestScreen(
                  dailyTestService: DailyTestService(
                      claudeService: ClaudeService(), storageService: storage),
                  analyticsService: AnalyticsService(),
                )));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(TextField), w));

              case 'topic_list':
                await tester.pumpWidget(app(TopicPracticeScreen(
                  claudeService: ClaudeService(),
                  storageService: _AppStorage(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: DesignSubs(),
                )));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(Card), w));

              case 'practice':
                await tester.pumpWidget(app(PracticeScreen(
                  topic: kTopics.first,
                  practiceSet: _practiceSet,
                  claudeService: ClaudeService(),
                  storageService: _AppStorage(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: DesignSubs(),
                )));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(TextField), w));

              case 'practice_results':
                await tester.pumpWidget(app(ResultsScreen(
                  topic: kTopics.first,
                  result: _practiceResult,
                  practiceSet: _practiceSet,
                  answers: const {'i1': 'went', 'i2': 'gone'},
                  storageService: _AppStorage(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: DesignSubs(),
                )));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(Card), w));

              case 'review':
                await tester.pumpWidget(app(_shell(
                    ReviewScreen(
                      claudeService: ClaudeService(),
                      storageService: _AppStorage(),
                      analyticsService: AnalyticsService(),
                      subscriptionService: DesignSubs(),
                      active: true,
                      onGoToPractice: () {},
                    ),
                    1)));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(Card), w));

              case 'weak_spot':
                await tester.pumpWidget(app(WeakSpotDetailScreen(
                  topic: kTopics.first,
                  spot: _AppStorage.spots.first,
                  claudeService: ClaudeService(),
                  storageService: _AppStorage(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: DesignSubs(),
                )));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(FilledButton), w));

              case 'profile_bottom':
                await tester.pumpWidget(app(_shell(
                    SettingsScreen(
                      active: true,
                      themeMode: AppThemeMode.system,
                      onSelectThemeMode: (_) {},
                      textSize: size,
                      onSelectTextSize: (_) {},
                      profile: UserProfile(
                          name: 'Ada',
                          learningGoal: LearningGoal.general,
                          avatar: Avatar.values.first),
                      storageService: _ProfileStorage(),
                      onProfileUpdated: (_) {},
                      onResetOnboarding: () {},
                      subscriptionService: DesignSubs(),
                      analyticsService: AnalyticsService(),
                    ),
                    2)));
                await precache([
                  ..._medalAssets,
                  for (final a in Avatar.values) a.assetPath
                ]);
                await tester.pumpAndSettle();
                await tester.drag(
                    find.byType(Scrollable).first, const Offset(0, -6000));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.text('Credits'), w));

              case 'premium':
                await tester.pumpWidget(app(PremiumScreen(
                  storageService: _AppStorage(),
                  analyticsService: AnalyticsService(),
                  analyticsSource: AnalyticsService.paywallSourceHome,
                  subscriptionService: _OfferingSubs(),
                )));
                await precache([for (final a in Avatar.values) a.assetPath]);
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(Card), w));

              case 'ai_consent':
                await tester.pumpWidget(app(const AiConsentScreen()));
                await tester.pumpAndSettle();
                notes.add(_column(tester, find.byType(FilledButton), w));
            }

            final exceptions = <Object>[];
            for (Object? e = tester.takeException();
                e != null;
                e = tester.takeException()) {
              exceptions.add(e);
            }
            notes.add(
                'exceptions: ${exceptions.isEmpty ? 'none' : exceptions.map((e) => e.toString().split('\n').first).join('; ')}');
            if (b == Brightness.light) {
              rows.putIfAbsent(c, () => []).add(
                  '$d ${w.toInt()}×${h.toInt()} ${size.name}: ${notes.join('\n    ')}');
            }
            await _writePng(tester, key, '$out/$name.png', dpr);
            // Let Home's timers (the hop, the label) run out.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 5));
          });
        }
      }
    }
  }
}

/// The mountain window, the image's size on screen against its asset,
/// the avatar and the climb card, on Home's daily framing at [step].
void _measureScene(
    WidgetTester tester, List<String> notes, double w, double h, int step) {
  final card = tester.getRect(find.byType(ClimbCard));
  final window = tester.getRect(find.byType(MonthlyMountain));
  final camera = ClimbCamera(window.width);
  final image = camera.imageSize;
  final px = image.width * 2;
  final tile = tester.getRect(find
      .descendant(
          of: find.byType(MonthlyMountain), matching: find.byType(AvatarTile))
      .first);
  final shown =
      window.width * window.height * 100 / (image.width * image.height);
  notes.add('climb card ${_r(card)} (${_f(card.width * 100 / w, 0)} % of the '
      'width, ${_f(card.height * 100 / h, 0)} % of the height); window '
      '${_f(window.width)} × ${_f(window.height)} (aspect '
      '${_f(window.width / window.height, 2)}:1)');
  notes.add('image on screen ${_f(image.width)} × ${_f(image.height)} pt = '
      '${_f(px, 0)} px wide against the ${_assetWidth.toInt()} px asset: '
      '${_f(px / _assetWidth, 2)}× (${px > _assetWidth ? 'upscaled' : 'not upscaled'}); '
      'the window shows ${_f(shown, 0)} % of the image; route length '
      '${_f(ClimbRoute.length * camera.scale, 0)} pt');
  notes.add('avatar tile ${_f(tile.width)} pt on step $step '
      '(${_f(tile.width * 100 / window.width, 1)} % of the window width; '
      'cap ${_f(ClimbCamera.maxAvatarTile)} pt)');
  notes.add('screen below the card: ${_f(h - card.bottom)} pt; '
      'max(0, ...) ${_f(math.max(0, h - card.bottom))}');
}

/// The box of [finder]'s first match and its share of the screen width:
/// the content column's width on that screen.
String _column(WidgetTester tester, Finder finder, double w) {
  if (finder.evaluate().isEmpty) return 'column: (reference not found)';
  final r = tester.getRect(finder.first);
  return 'column reference ${_r(r)} (${_f(r.width * 100 / w, 0)} % of the '
      'width)';
}

Future<void> _writePng(
        WidgetTester tester, GlobalKey key, String file, double dpr) =>
    tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: dpr);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

const _practiceSet = PracticeSet(
  topicId: 'gerundVsInfinitive',
  items: [
    PracticeItem(
        id: 'i1',
        type: PracticeItemType.fillInBlank,
        instruction: 'She ___ (go) to the store yesterday.'),
    PracticeItem(
        id: 'i2',
        type: PracticeItemType.sentenceWriting,
        instruction: 'Write a sentence about your weekend using the past '
            'simple.'),
  ],
);

const _practiceResult = ScoringResult(
  topicId: 'gerundVsInfinitive',
  feedback: [
    ItemFeedback(
        itemId: 'i1',
        isCorrect: true,
        isSkipped: false,
        correctedAnswer: 'went',
        explanation: "'Yesterday' is a finished time, so the past simple: "
            "'went'."),
    ItemFeedback(
        itemId: 'i2',
        isCorrect: false,
        isSkipped: false,
        correctedAnswer: 'I went to the beach last weekend.',
        explanation: "'Gone' is the past participle; on its own the past "
            "simple is 'went'."),
  ],
);

/// Today's Daily Test already stored (the bundled first-day questions).
class _TestStorage extends StorageService {
  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => DailyTestSet(
      day: '2026-10-14',
      questions: kDayZeroQuestions,
      source: DailyTestSource.shared);
  @override
  Future<DailyTestSet?> getDailyTestSet(String day) =>
      getDailyTestSetForToday();
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      const [];
  @override
  Future<String> getOrCreateDeviceId() async => 'design-device';
}

/// Review, the weak spot detail, practice, its results, the topic list
/// and Premium: a free user with three weak spots and one free practice
/// used today.
class _AppStorage extends StorageService {
  static final spots = [
    WeakSpot(
        topicId: kTopics[0].id.name,
        errorType: 'gerund_after_avoid',
        frequency: 3,
        lastSeen: DateTime(2026, 10, 14),
        latestExplanation:
            "'Avoid' is followed by the -ing form, not 'to'. Say 'avoid "
            "eating'.",
        latestRule: 'Gerund vs. Infinitive'),
    WeakSpot(
        topicId: kTopics[1].id.name,
        errorType: 'modal_plus_s',
        frequency: 2,
        lastSeen: DateTime(2026, 10, 13)),
    WeakSpot(
        topicId: kTopics[2].id.name,
        errorType: 'modal_past',
        frequency: 1,
        lastSeen: DateTime(2026, 10, 10)),
  ];
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      spots;
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      [
        ErrorEntry(
            topicId: topicId,
            errorType: errorType,
            timestamp: DateTime(2026, 10, 14),
            prompt: 'You should avoid ___ too much sugar.\nFill in the blank '
                'with the correct form of the verb in brackets.',
            userAnswer: 'to eat',
            correctedAnswer: 'eating',
            explanation: "'Avoid' is followed by the -ing form, not 'to'. Say "
                "'avoid eating'.",
            source: ErrorSource.dailyTest),
      ];
  @override
  Future<int> getFreePracticeCountForToday() async => 1;
  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async {}
  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async {}
  @override
  Future<UserProfile?> getUserProfile() async => UserProfile(
      name: 'Ada',
      learningGoal: LearningGoal.general,
      avatar: Avatar.values.first);
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => {
        kTopics[0].id.name: const TopicStats(practiced: 2, weakSpotCount: 1),
        kTopics[1].id.name: const TopicStats(practiced: 1, weakSpotCount: 1),
      };
  @override
  Future<String> getOrCreateDeviceId() async => 'design-device';
}

/// A free user offered both plans (the Premium tests' fixture prices).
class _OfferingSubs extends DesignSubs {
  static const _context = PresentedOfferingContext('default', null, null);
  @override
  Future<Offering?> getOfferings() async {
    const monthly = Package(
        '\$rc_monthly',
        PackageType.monthly,
        StoreProduct('grammarlens_premium_monthly', 'Full access',
            'GrammarLens Premium (Monthly)', 9.99, '\$9.99', 'USD',
            introductoryPrice:
                IntroductoryPrice(0, '\$0.00', 'P3D', 1, PeriodUnit.day, 3),
            subscriptionPeriod: 'P1M'),
        _context);
    const annual = Package(
        '\$rc_annual',
        PackageType.annual,
        StoreProduct('grammarlens_premium_annual', 'Full access (annual)',
            'GrammarLens Premium (Annual)', 89.99, '\$89.99', 'USD',
            introductoryPrice:
                IntroductoryPrice(0, '\$0.00', 'P1W', 1, PeriodUnit.week, 1),
            subscriptionPeriod: 'P1Y',
            pricePerMonth: 7.49,
            pricePerMonthString: '\$7.49'),
        _context);
    return const Offering('default', 'Default offering', {}, [monthly, annual],
        monthly: monthly, annual: annual);
  }
}
