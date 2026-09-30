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
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

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

/// Design decision K3 (Batch 3c a–c): "Mountain of Learning" on a plaque on
/// the frame's top line; the month without the year and the steps inside
/// the frame, at every width and app text size. Replaces D10's two header
/// rows.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  for (final width in [320.0, 375.0, 430.0]) {
    for (final textSize in AppTextSize.values) {
      testWidgets(
          '$width pt, ${textSize.name} text: plaque on the line, '
          'month and steps inside', (tester) async {
        tester.view.physicalSize = Size(width, 1100) * 3;
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
            // The longest month name: "September", 30 / 30.
            clock: () => DateTime(2026, 9, 30, 9),
          ),
        ));
        await tester.pumpAndSettle();

        final card = tester.getRect(find.byType(ClimbCard));
        final plaque = tester.getRect(find.byKey(ClimbCard.plaqueKey));
        final window = tester.getRect(find.byType(MonthlyMountain));
        final month = tester.getRect(find.byKey(ClimbCard.monthKey));
        final steps = tester.getRect(find.byKey(ClimbCard.stepsKey));

        // The plaque is centered on the frame's top line (the window's top).
        expect(plaque.center.dx, closeTo(card.center.dx, .5));
        expect(plaque.center.dy, closeTo(window.top, .5));
        expect(plaque.top, closeTo(card.top, .5));

        // Month top left, steps top right, inside the frame, under the
        // plaque, one line each and never scaled down at the app's sizes.
        expect(find.text('September'), findsOneWidget);
        expect(find.text('30 / 30'), findsOneWidget);
        expect(find.textContaining('2026'), findsNothing);
        for (final label in [month, steps]) {
          expect(label.top, greaterThan(plaque.bottom));
          expect(label.overlaps(plaque), isFalse);
          expect(label.top, lessThan(window.top + 60));
        }
        expect(month.left, lessThan(card.center.dx));
        expect(steps.right, greaterThan(card.center.dx));
        expect(month.right, lessThan(steps.left));
        for (final key in [ClimbCard.monthKey, ClimbCard.stepsKey]) {
          final text = find.byKey(key);
          final style = tester.widget<Text>(text).style!;
          expect(tester.getSize(text).height,
              lessThan(style.fontSize! * (style.height ?? 1) * 1.5));
          // Laid out and drawn at the same size: no FittedBox scaling.
          expect(tester.getRect(text).width,
              closeTo(tester.getSize(text).width, .01));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
