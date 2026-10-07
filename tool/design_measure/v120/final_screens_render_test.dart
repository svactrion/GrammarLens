// 1.2.0 final screens (docs/design/1.2.0-final): Premium Review (Suggested
// Focus, no weak spots), Free Review for comparison, Data (on, off, the
// reset dialog) and Credits, with the real font, light and dark.
//
//   DESIGN_MEASURE_OUT=docs/design/1.2.0-final/renders \
//     flutter test tool/design_measure/v120/final_screens_render_test.dart
//
// Images at 390 × 844, Medium (the default). DESIGN_MEASURE_SWEEP=1 writes
// no images: every screen at 320, 360, 390 and 430 pt (844 tall) and at
// 375 × 667, every text size, system text 1.0 / 1.3 / 2.0, light and dark,
// and `final_screens_sweep.txt` lists each layout exception and each text
// that ends in an ellipsis.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/credits_screen.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Subs extends SubscriptionService {
  final bool access;
  _Subs(this.access);
  @override
  Future<bool> get hasFullAccess async => access;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _Storage extends StorageService {
  final List<WeakSpot> spots;
  final bool consent;
  _Storage({this.spots = const [], this.consent = false});

  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      spots.take(limit).toList();
  @override
  Future<int> getFreePracticeCountForToday() async => 0;
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<AiConsent?> getAiConsent() async => consent
      ? AiConsent(
          granted: true,
          decidedAt: DateTime(2026, 10, 1),
          version: AiConsent.currentVersion)
      : null;
}

final _spots = [
  WeakSpot(
      topicId: 'gerundVsInfinitive',
      errorType: 'gerund_after_enjoy',
      frequency: 1,
      lastSeen: DateTime(2026, 10, 6),
      latestExplanation:
          'The base form doesn’t work after ‘enjoy’; you need the -ing form.'),
  WeakSpot(
      topicId: 'modalVerbs',
      errorType: 'modal_past_form',
      frequency: 2,
      lastSeen: DateTime(2026, 10, 6)),
  WeakSpot(
      topicId: 'articles',
      errorType: 'missing_article',
      frequency: 1,
      lastSeen: DateTime(2026, 10, 5)),
];

Widget _review(bool premium, List<WeakSpot> spots) => FloatingNavShell(
      body: ReviewScreen(
        claudeService: ClaudeService(),
        storageService: _Storage(spots: spots),
        analyticsService: AnalyticsService(),
        subscriptionService: _Subs(premium),
        active: true,
        onGoToPractice: () {},
      ),
      tabs: const [
        NavShellTab(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        NavShellTab(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: 'Review'),
        NavShellTab(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile'),
      ],
      selectedIndex: 1,
      onTabChange: (_) {},
    );

typedef _Screen = ({
  String name,
  Widget Function() build,
  Future<void> Function(WidgetTester tester)? after,
});

final List<_Screen> _screens = [
  (name: 'review_premium', build: () => _review(true, _spots), after: null),
  (name: 'review_free', build: () => _review(false, _spots), after: null),
  (
    name: 'review_premium_empty',
    build: () => _review(true, const []),
    after: null
  ),
  (
    name: 'data_on',
    build: () => DataScreen(storageService: _Storage(consent: true)),
    after: null
  ),
  (
    name: 'data_off',
    build: () => DataScreen(storageService: _Storage()),
    after: null
  ),
  (
    name: 'data_reset_dialog',
    build: () => DataScreen(storageService: _Storage(consent: true)),
    after: (tester) async {
      await tester.ensureVisible(find.byKey(DataScreen.resetKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DataScreen.resetKey));
      await tester.pumpAndSettle();
    }
  ),
  (name: 'credits', build: () => const CreditsScreen(), after: null),
];

void main() {
  final out = outDir();
  final sweep = Platform.environment['DESIGN_MEASURE_SWEEP'] == '1';
  final only = Platform.environment['DESIGN_MEASURE_SCREENS']
      ?.split(',')
      .map((s) => s.trim())
      .toSet();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  final report = StringBuffer();
  tearDownAll(() {
    if (sweep) {
      File('$out/final_screens_sweep.txt')
          .writeAsStringSync(report.toString());
    }
  });

  Future<void> pumpScreen(WidgetTester tester, _Screen screen, Size size,
      AppTextSize textSize, double systemScale, Brightness b,
      GlobalKey key) async {
    DebugTools.enabledForTesting = false;
    addTearDown(() => DebugTools.enabledForTesting = true);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    final pad = FakeViewPadding(
        top: (size.height < 700 ? 20 : 47) * 3,
        bottom: (size.height < 700 ? 0 : 34) * 3);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(b, textSize: textSize),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(systemScale)),
            child: child!),
        home: screen.build(),
      ),
    ));
    await tester.pumpAndSettle();
    if (screen.after != null) await screen.after!(tester);
  }

  final screens = [
    for (final s in _screens)
      if (only == null || only.contains(s.name)) s
  ];

  if (sweep) {
    const sizes = [
      Size(320, 844),
      Size(360, 844),
      Size(390, 844),
      Size(430, 844),
      Size(375, 667),
    ];
    for (final screen in screens) {
      for (final size in sizes) {
        for (final textSize in AppTextSize.values) {
          for (final systemScale in const [1.0, 1.3, 2.0]) {
            for (final b in Brightness.values) {
              final id = '${screen.name} ${size.width.toInt()}x'
                  '${size.height.toInt()} ${textSize.name} x$systemScale '
                  '${b.name}';
              testWidgets(id, (tester) async {
                final key = GlobalKey();
                final errors = <String>[];
                final previous = FlutterError.onError;
                FlutterError.onError = (d) =>
                    errors.add(d.exceptionAsString().split('\n').first);
                try {
                  await pumpScreen(
                      tester, screen, size, textSize, systemScale, b, key);
                } finally {
                  FlutterError.onError = previous;
                }
                final cut = <String>{};
                void visit(RenderObject o) {
                  if (o is RenderParagraph && o.didExceedMaxLines) {
                    final t = o.text.toPlainText();
                    cut.add(t.length > 50 ? '${t.substring(0, 50)}…' : t);
                  }
                  o.visitChildren(visit);
                }

                visit(tester.renderObject(find.byKey(key)));
                if (errors.isNotEmpty || cut.isNotEmpty) {
                  report.writeln(id);
                  for (final e in errors.toSet()) {
                    report.writeln('  exception: $e');
                  }
                  for (final c in cut) {
                    report.writeln('  ellipsis: "$c"');
                  }
                }
              });
            }
          }
        }
      }
    }
    return;
  }

  for (final screen in screens) {
    for (final b in Brightness.values) {
      final file = '${screen.name}_390_medium_${b.name}';
      testWidgets(file, (tester) async {
        final key = GlobalKey();
        await pumpScreen(tester, screen, const Size(390, 844),
            AppTextSize.medium, 1, b, key);
        await tester.runAsync(() async {
          final img = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
