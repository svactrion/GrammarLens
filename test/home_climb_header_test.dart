import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';

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
      (steps: 30, correct: 0, wrong: 0, skipped: 0);
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

/// Design decision D10: the header above the mountain is two fixed rows,
/// "Mountain of Learning" and "<month> · n / N steps", at every width and
/// every app text size. (The one-line "Mountain of Learning · <month>" is
/// 314 pt at Medium and wrapped on a 320 pt screen.)
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  for (final width in [320.0, 375.0, 430.0]) {
    for (final textSize in AppTextSize.values) {
      testWidgets('$width pt, ${textSize.name} text: two one-line rows',
          (tester) async {
        tester.view.physicalSize = Size(width, 900) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          // The app's only text-size path: the theme, no textScaler.
          theme: buildAppTheme(Brightness.light, textSize: textSize),
          home: HomeScreen(
            active: true,
            userName: 'Ada',
            avatar: null,
            claudeService: ClaudeService(),
            storageService: _Storage(),
            analyticsService: AnalyticsService(),
            subscriptionService: _Subs(),
            // The longest month name: "September 2026 · 30 / 30 steps".
            clock: () => DateTime(2026, 9, 30, 9),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Monthly Climb'), findsNothing);
        final title = find.text('Mountain of Learning');
        final month = find.text('September 2026 · ');
        final steps = find.text('30 / 30 steps');
        expect(title, findsOneWidget);
        expect(month, findsOneWidget);
        expect(steps, findsOneWidget);

        double lineHeight(Finder f) {
          final style = tester.widget<Text>(f).style!;
          return style.fontSize! * (style.height ?? 1);
        }

        // Each row is a single line...
        for (final f in [title, month, steps]) {
          expect(tester.getSize(f).height, lessThan(lineHeight(f) * 1.5),
              reason: tester.widget<Text>(f).data);
        }
        // ...and the month and the steps share the second row.
        expect(tester.getTopLeft(steps).dy,
            closeTo(tester.getTopLeft(month).dy, 2));
        expect(tester.getTopLeft(month).dy,
            greaterThan(tester.getBottomLeft(title).dy - .5));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
