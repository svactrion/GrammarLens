import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';

void main() {
  const topic = Topic(
    id: TopicId.articles,
    icon: Icons.school,
  );

  const practiceSet = PracticeSet(
    topicId: 'articles',
    items: [
      PracticeItem(
        id: 'q1',
        type: PracticeItemType.fillInBlank,
        instruction: 'I saw ___ elephant at the zoo.',
      ),
    ],
  );

  for (final brightness in Brightness.values) {
    group('"Leave practice?" dialog ($brightness)', () {
      Future<void> openDialog(WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844) * 3.0;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: PracticeScreen(
              topic: topic,
              practiceSet: practiceSet,
              claudeService: ClaudeService(),
              storageService: StorageService(),
              analyticsService: AnalyticsService(),
              subscriptionService: SubscriptionService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Leave practice?'), findsOneWidget);
        // R10: the companion asks; how far the session got (none yet).
        expect(find.byType(CompanionView), findsWidgets);
        expect(find.text('Keep going'), findsOneWidget);
      }

      testWidgets(
          'R10: "Keep going" is the primary button, "Leave" the quiet one',
          (tester) async {
        await openDialog(tester);
        final keep = tester
            .widget<PressableButton>(find.byKey(PracticeScreen.keepGoingKey));
        expect(keep.label, 'Keep going');
        expect(find.byKey(PracticeScreen.leaveKey), findsOneWidget);
        expect(find.text('Leave'), findsOneWidget);
      });

      testWidgets('Keep going keeps the session open', (tester) async {
        await openDialog(tester);
        await tester.tap(find.byKey(PracticeScreen.keepGoingKey));
        await tester.pumpAndSettle();

        expect(find.text('Leave practice?'), findsNothing);
        expect(find.byType(PracticeScreen), findsOneWidget);
      });
    });
  }
}
