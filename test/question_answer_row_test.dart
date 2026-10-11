import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/question_view.dart';

/// The "Your answer" row keeps its 44 pt when "Review answer" appears, so
/// the answer field does not move when the answer takes focus (it grew to
/// 48 pt with the button's padded tap area, dropping the field 4 pt).
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  for (final size in AppTextSize.values) {
    testWidgets(
        'the row stays ${QuestionView.headHeight} pt and the field stays put '
        'when the answer takes focus (${size.name})', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final drafts = AnswerDrafts(['q']);
      addTearDown(drafts.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light, textSize: size),
        home: Scaffold(
          body: QuestionView(
            item: const PracticeItem(
                id: 'q',
                type: PracticeItemType.fillInBlank,
                instruction: 'I enjoy ____ in the morning.'),
            index: 0,
            total: 1,
            drafts: drafts,
            horizontalPadding: 16,
            onChanged: (_) {},
          ),
        ),
      ));
      final field = find.byKey(QuestionView.answerFieldKey);
      final row = find
          .ancestor(of: find.text('Your answer'), matching: find.byType(Row))
          .first;
      final fieldTop = tester.getRect(field).top;
      expect(tester.getSize(row).height, QuestionView.headHeight);

      drafts.focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(find.byKey(QuestionView.keyboardControlKey), findsOneWidget);
      expect(tester.getSize(row).height, QuestionView.headHeight);
      expect(tester.getRect(field).top, fieldTop);
      // Still a full-size target.
      final control =
          tester.getSize(find.byKey(QuestionView.keyboardControlKey));
      expect(control.height, greaterThanOrEqualTo(44));
      expect(control.width, greaterThanOrEqualTo(44));
    });
  }
}
