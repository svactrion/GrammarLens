// Home's greeting row ("Good morning, <name>") across screens, text sizes,
// names and times of day: how much of the name is actually drawn.
//
// Self-contained on purpose (only home_fakes.dart), so it also runs on the
// 1.0.0 tree, which has none of the Batch 2+ files layouts.dart imports.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/utils/greeting.dart';

import 'home_fakes.dart';

const _screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(430, 932), 59.0, 34.0),
];

/// Short, medium, long, and a full name with spaces (onboarding has no
/// length limit and allows spaces).
const _names = ['Ada', 'Charlotte', 'Maximilian', 'Mary Anne Smith'];

/// 09:00 morning, 14:00 afternoon, 20:00 evening.
const _hours = [9, 14, 20];

String _f(double v) => v.toStringAsFixed(1);

void main() {
  final out = StringBuffer();
  setUpAll(() async {
    final bytes =
        File('assets/fonts/NunitoSans-Variable.ttf').readAsBytesSync();
    await (FontLoader('NunitoSans')
          ..addFont(
              Future.value(ByteData.view(Uint8List.fromList(bytes).buffer))))
        .load();
  });
  tearDownAll(() {
    final dir =
        Platform.environment['DESIGN_MEASURE_OUT'] ?? 'build/design_measure';
    Directory(dir).createSync(recursive: true);
    File('$dir/greeting.txt').writeAsStringSync(out.toString());
  });

  for (final (size, top, bottom) in _screens) {
    for (final textSize in AppTextSize.values) {
      testWidgets('${size.width.toInt()} ${textSize.name}', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
        addTearDown(tester.view.reset);
        for (final hour in _hours) {
          for (final name in _names) {
            await tester.pumpWidget(designHome(
                clock: DateTime(2026, 9, 15, hour),
                storage: DesignStorage(steps: 8),
                textSize: textSize,
                userName: name));
            await tester.pump();
            // The paragraph that ends with the name: the whole greeting on
            // one line, or (since the greeting fix) the name's own line.
            final paragraph = tester.renderObject<RenderParagraph>(
                find.byWidgetPredicate((w) =>
                    w is RichText && w.text.toPlainText().endsWith(name)));
            final text = paragraph.text.toPlainText();
            final lines = text == name ? 2 : 1;
            final greeting =
                '${timeOfDayGreeting(DateTime(2026, 9, 15, hour))}, $name';
            // A character is drawn if the paragraph lays out a box for it;
            // characters cut by the ellipsis get none.
            var drawn = 0;
            final start = text.length - name.length;
            for (var i = start; i < text.length; i++) {
              final boxes = paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: i, extentOffset: i + 1));
              if (boxes.isNotEmpty && boxes.first.right > boxes.first.left) {
                drawn++;
              }
            }
            final full = (TextPainter(
                    text: TextSpan(text: greeting, style: paragraph.text.style),
                    textDirection: TextDirection.ltr)
                  ..layout())
                .width;
            final state = drawn == 0
                ? 'LOST'
                : drawn < name.length
                    ? 'cut'
                    : 'full';
            out.writeln('${size.width.toInt()} ${textSize.name.padRight(6)} '
                '${hour.toString().padLeft(2)}h ${name.padRight(15)} '
                'available=${_f(paragraph.constraints.maxWidth)} '
                'needed=${_f(full)} lines=$lines '
                'drawn=$drawn/${name.length} $state');
          }
        }
      });
    }
  }
}
