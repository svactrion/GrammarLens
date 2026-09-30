// Fix options for Home's greeting row at 320 pt, rendered and measured.
// Each option is a copy of the row (greeting text + 12 pt gap + the 60 pt
// avatar tile) with one change; the product is untouched.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/greeting.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

import 'layouts.dart';

enum Option {
  today('Today: one line, cut at the end'),
  wrap('A: name on its own line when needed'),
  firstName('B: first name only, one line'),
  shrink('C: shrink to fit one line');

  final String label;
  const Option(this.label);
}

/// The content width on a 320 pt screen (the mountain card's width).
const _rowWidth = 288.0;

const _cases = [
  (9, 'Ada'),
  (14, 'Charlotte'),
  (14, 'Mary Anne Smith'),
];

Widget _row(Option option, String word, String name, TextStyle style) {
  final shown = option == Option.firstName ? name.split(' ').first : name;
  final text = '$word, $shown';
  final Widget greeting = switch (option) {
    Option.today ||
    Option.firstName =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    // One line if it fits. Otherwise two lines: the greeting word (scaled
    // down only if it alone is wider than the space) and the name on a line
    // of its own, shortened only if it is longer than a whole line.
    Option.wrap => LayoutBuilder(builder: (context, constraints) {
        final oneLine = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1)
          ..layout(maxWidth: constraints.maxWidth);
        final fits = !oneLine.didExceedMaxLines;
        oneLine.dispose();
        if (fits) return Text(text, maxLines: 1, style: style);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('$word,', maxLines: 1, style: style)),
            Text(shown,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ],
        );
      }),
    Option.shrink => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: style)),
  };
  return SizedBox(
    width: _rowWidth,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: greeting),
        const SizedBox(width: 12),
        AvatarTile(avatar: Avatar.values.first, radius: 30),
      ],
    ),
  );
}

void main() {
  final out = StringBuffer();
  final dir = outDir();
  setUpAll(loadFont);
  tearDownAll(() =>
      File('$dir/greeting_options.txt').writeAsStringSync(out.toString()));

  for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
    testWidgets('options at 320 pt, ${textSize.name}', (tester) async {
      final theme = buildAppTheme(Brightness.light, textSize: textSize);
      final style = theme.textTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.w700,
          color:
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface);
      tester.view.physicalSize = const Size(1500, 900) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final rowKeys = {
        for (final o in Option.values)
          for (final c in _cases) (o, c): GlobalKey()
      };
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final option in Option.values) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Caption('${option.label} · ${textSize.name} text',
                            width: _rowWidth, brightness: Brightness.light),
                        for (final c in _cases) ...[
                          Container(
                            key: rowKeys[(option, c)],
                            child: _row(
                                option,
                                timeOfDayGreeting(DateTime(2026, 9, 15, c.$1)),
                                c.$2,
                                style),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                    const SizedBox(width: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.runAsync(() => precacheImage(
          AssetImage(Avatar.values.first.assetPath), key.currentContext!));
      await tester.pump();

      for (final option in Option.values) {
        for (final c in _cases) {
          final rowFinder = find.byKey(rowKeys[(option, c)]!);
          // The name is in the row's last paragraph (option A may split the
          // greeting into two).
          final paragraphs =
              find.descendant(of: rowFinder, matching: find.byType(RichText));
          final paragraph =
              tester.renderObject<RenderParagraph>(paragraphs.last);
          final text = paragraph.text.toPlainText();
          final name =
              option == Option.firstName ? c.$2.split(' ').first : c.$2;
          var drawn = 0;
          for (var i = text.length - name.length; i < text.length; i++) {
            final boxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1));
            if (boxes.isNotEmpty && boxes.first.right > boxes.first.left) {
              drawn++;
            }
          }
          final lines = paragraphs.evaluate().length > 1
              ? paragraphs.evaluate().length
              : paragraph
                  .getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: text.length))
                  .map((b) => b.top.round())
                  .toSet()
                  .length;
          // Rendered font size: the paragraph's size against its on-screen
          // size (FittedBox scales it down).
          final onScreen = tester.getRect(paragraphs.first);
          final scale = onScreen.width /
              tester.renderObject<RenderParagraph>(paragraphs.first).size.width;
          out.writeln('${textSize.name.padRight(6)} ${option.name.padRight(9)} '
              '${c.$1.toString().padLeft(2)}h ${c.$2.padRight(15)} '
              'drawn=$drawn/${name.length} of "$name" lines=$lines '
              'rowHeight=${tester.getSize(rowFinder).height.toStringAsFixed(1)} '
              'fontSize=${(style.fontSize! * scale).toStringAsFixed(1)}');
        }
      }
      await writePng(
          tester, key, '$dir/greeting_options_320_${textSize.name}.png');
    });
  }
}
