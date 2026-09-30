// Home's vertical layout at each screen size and text size (Batch 0 item 13,
// Batch 3b report R4).
//
// Text size is applied the way the app applies it, through
// buildAppTheme(textSize:), and nowhere else: no MediaQuery.textScaler on
// top. (Batch 3a's tool added one and measured every size one step too
// large; see the Batch 3b report, R4.)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'layouts.dart';

/// Inputs, the same as Batch 0 unless overridden: `DESIGN_MEASURE_CLOCK`
/// (ISO date-time, default 2026-09-15T09:00) and `DESIGN_MEASURE_STEPS`
/// (default 8).
final _clock = DateTime.parse(
    Platform.environment['DESIGN_MEASURE_CLOCK'] ?? '2026-09-15T09:00:00');
final _steps = int.parse(Platform.environment['DESIGN_MEASURE_STEPS'] ?? '8');

class _Subs extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _Storage extends StorageService {
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: _steps, correct: 0, wrong: 0, skipped: 0);
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

String _f(double v) => v.toStringAsFixed(1);
String _r(Rect r) => '${_f(r.top)}..${_f(r.bottom)}';

/// Screen sizes with their status bar / home indicator insets.
const screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(375, 812), 44.0, 34.0),
  (Size(430, 932), 59.0, 34.0),
];

void main() {
  final out = StringBuffer();
  setUpAll(loadFont);
  tearDownAll(() =>
      File('${outDir()}/home_layout.txt').writeAsStringSync(out.toString()));
  for (final (size, top, bottom) in screens) {
    for (final ts in AppTextSize.values) {
      testWidgets('$size ${ts.name}', (tester) async {
        tester.view.physicalSize = size * 3.0;
        tester.view.devicePixelRatio = 3.0;
        tester.view.padding =
            FakeViewPadding(top: top * 3.0, bottom: bottom * 3.0);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light, textSize: ts),
          home: FloatingNavShell(
            body: HomeScreen(
              active: true,
              userName: 'Ada',
              avatar: Avatar.values.first,
              claudeService: ClaudeService(),
              storageService: _Storage(),
              analyticsService: AnalyticsService(),
              subscriptionService: _Subs(),
              clock: () => _clock,
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
            selectedIndex: 0,
            onTabChange: (_) {},
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        Rect r(Finder x) => tester.getRect(x.first);
        final titleFinder =
            find.textContaining('Mountain of Learning').evaluate().isNotEmpty
                ? find.textContaining('Mountain of Learning')
                : find.textContaining('Monthly Climb');
        final title = r(titleFinder);
        final steps = r(find.textContaining(' steps'));
        final today = r(find.ancestor(
            of: find.text('Daily Test'), matching: find.byType(Card)));
        final mountain = r(find.byType(MonthlyMountain));
        final fold = r(find.byType(BackdropFilter)).top;
        final avatar = r(find.descendant(
            of: find.byType(MonthlyMountain), matching: find.byType(Image)));
        out.writeln('${size.width.toInt()}x${size.height.toInt()} '
            '${ts.name.padRight(6)} '
            'todayCard=${_r(today)} header=${_f(title.top)}..${_f(steps.bottom)} '
            'rows=${steps.top > title.top + 2 ? 2 : 1} '
            'mountain=${_f(mountain.left)},${_f(mountain.top)} '
            '${mountain.width.toStringAsFixed(2)}x${_f(mountain.height)} '
            'fold=${_f(fold)} aboveFold=${_f(fold - mountain.top)} '
            'avatarImage=${_f(avatar.width)}x${_f(avatar.height)}');
      });
    }
  }
}
