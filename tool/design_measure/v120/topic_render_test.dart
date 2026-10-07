// 1.2.0 Batch 9, part B: the real Topic Practice screen with the real font,
// the whole page, light and dark. DESIGN_MEASURE_WIDTHS (390),
// DESIGN_MEASURE_SIZES (medium) and DESIGN_MEASURE_MODES (light,dark)
// change the case; DESIGN_MEASURE_STARTED=1 gives two topics a history.
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_topics \
//     flutter test tool/design_measure/v120/topic_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Storage extends StorageService {
  final bool started;
  _Storage(this.started);

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => started
      ? const {
          'modalVerbs': TopicStats(practiced: 12, weakSpotCount: 2),
          'articles': TopicStats(practiced: 1, weakSpotCount: 1),
        }
      : const {};
}

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  List<String> env(String name, String fallback) =>
      (Platform.environment[name] ?? fallback)
          .split(',')
          .map((s) => s.trim())
          .toList();
  final started = Platform.environment['DESIGN_MEASURE_STARTED'] == '1';
  for (final w in env('DESIGN_MEASURE_WIDTHS', '390')) {
    for (final size in env('DESIGN_MEASURE_SIZES', 'medium')) {
      for (final m in env('DESIGN_MEASURE_MODES', 'light,dark')) {
        final width = double.parse(w);
        final b = Brightness.values.byName(m);
        final file = 'topics_${w}_${size}_$m${started ? '_started' : ''}';
        testWidgets(file, (tester) async {
          tester.view.physicalSize = Size(width, 1200) * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding = const FakeViewPadding(top: 47 * 3);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme:
                  buildAppTheme(b, textSize: AppTextSize.values.byName(size)),
              home: TopicPracticeScreen(
                claudeService: ClaudeService(),
                storageService: _Storage(started),
                analyticsService: AnalyticsService(),
                subscriptionService: SubscriptionService(),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final img = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$file.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        });
      }
    }
  }
}
