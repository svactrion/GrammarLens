import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

void main() {
  const topic = Topic(
    id: TopicId.articles,
    title: 'Articles',
    description: 'a/an/the',
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

  Color? fill(ButtonStyleButton b) =>
      b.style?.backgroundColor?.resolve(const {});
  Color? label(ButtonStyleButton b) =>
      b.style?.foregroundColor?.resolve(const {});
  Color? border(ButtonStyleButton b) => b.style?.side?.resolve(const {})?.color;

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
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Leave practice?'), findsOneWidget);
        expect(find.text('Your progress will be lost.'), findsOneWidget);
      }

      testWidgets('Leave is destructive, Cancel is neutral and not primary',
          (tester) async {
        await openDialog(tester);
        final scheme = buildAppTheme(brightness).colorScheme;

        final leave = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Leave'));
        expect(fill(leave), scheme.destructive);
        expect(label(leave), scheme.onDestructive);

        final cancel = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Cancel'));
        expect(label(cancel), scheme.onSurface);
        expect(label(cancel), isNot(scheme.primary));
        expect(border(cancel), scheme.onSurfaceVariant);
        expect(border(cancel), isNot(scheme.primary));
        expect(fill(cancel), isNull);
      });

      testWidgets('Cancel keeps the session open', (tester) async {
        await openDialog(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Leave practice?'), findsNothing);
        expect(find.byType(PracticeScreen), findsOneWidget);
      });
    });
  }
}
