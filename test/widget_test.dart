import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';

void main() {
  testWidgets('renders the topic list on launch', (tester) async {
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    expect(find.text('GrammarLens'), findsOneWidget);
    expect(find.text('Gerund vs. Infinitive'), findsOneWidget);
  });
}
