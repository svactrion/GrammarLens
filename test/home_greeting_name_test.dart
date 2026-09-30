import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
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
      (steps: 8, correct: 0, wrong: 0, skipped: 0);
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

/// Regression: at 320 pt, "Good morning, <name>" on one line lost the whole
/// name (end-truncation left no room for one letter plus "…"), for every
/// name at the default text size, since 1.0.0
/// (`docs/design/greeting-fix/report.md`). The report's matrix: 3 screens ×
/// 3 text sizes × 3 greetings × 4 names, with the real font.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  const screens = [
    (Size(320, 568), 20.0, 0.0),
    (Size(375, 667), 20.0, 0.0),
    (Size(430, 932), 59.0, 34.0),
  ];
  const names = ['Ada', 'Charlotte', 'Maximilian', 'Mary Anne Smith'];
  const hours = [9, 14, 20]; // morning, afternoon, evening

  for (final (size, top, bottom) in screens) {
    for (final textSize in AppTextSize.values) {
      testWidgets(
          '${size.width.toInt()} pt, ${textSize.name} text: the name is never '
          'lost, and whole wherever a line can hold it', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
        addTearDown(tester.view.reset);
        for (final hour in hours) {
          for (final name in names) {
            final theme = buildAppTheme(Brightness.light, textSize: textSize);
            await tester.pumpWidget(MaterialApp(
              theme: theme,
              home: FloatingNavShell(
                body: HomeScreen(
                  active: true,
                  userName: name,
                  avatar: Avatar.values.first,
                  claudeService: ClaudeService(),
                  storageService: _Storage(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: _Subs(),
                  clock: () => DateTime(2026, 9, 15, hour),
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
                ],
                selectedIndex: 0,
                onTabChange: (_) {},
              ),
            ));
            await tester.pump();

            // The paragraph that ends with the name: the whole greeting on
            // one line, or the name's own line.
            final paragraphFinder = find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText().endsWith(name));
            expect(paragraphFinder, findsOneWidget);
            final paragraph =
                tester.renderObject<RenderParagraph>(paragraphFinder);
            final text = paragraph.text.toPlainText();
            // Characters cut by the ellipsis get no box.
            var drawn = 0;
            for (var i = text.length - name.length; i < text.length; i++) {
              final boxes = paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: i, extentOffset: i + 1));
              if (boxes.isNotEmpty && boxes.first.right > boxes.first.left) {
                drawn++;
              }
            }
            final where = '${size.width.toInt()} pt, ${textSize.name}, '
                '${hour}h, "$name"';
            expect(drawn, greaterThan(0), reason: 'name lost: $where');

            // Wherever the name alone fits the greeting's width, all of it
            // is drawn.
            final nameWidth = (TextPainter(
                    text: TextSpan(text: name, style: paragraph.text.style),
                    textDirection: TextDirection.ltr)
                  ..layout())
                .width;
            if (nameWidth <= paragraph.constraints.maxWidth) {
              expect(drawn, name.length, reason: 'name cut: $where');
            }
          }
        }
      });
    }
  }
}
