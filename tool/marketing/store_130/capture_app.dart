// Extends the 9 October marketing rig. Never imported by lib/.
// Only dedicated 1.3 Store simulators; no Firebase or RevenueCat init.
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/utils/app_orientation.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

import '../../screenshots/seed.dart';

const captureDate = '2026-10-16';
final captureNow = DateTime(2026, 10, 16, 9, 41);
const captureDb = 'product_capture_2026_10_16_store_r2.db';
const onboardingDb = 'product_capture_2026_10_16_onboarding_r2.db';
// Same real bundled questions, reordered only in the capture database.
// The Tense Selection card contains neither "see" nor "saw".
final captureQuestions = [kDayZeroQuestions.last, ...kDayZeroQuestions.take(4)];
final captureAnswers = [
  'have seen',
  for (final question in captureQuestions.skip(1)) question.correctAnswer,
];
final storage = StorageService(dbName: captureDb);
final analytics = AnalyticsService(sink: const _NoAnalytics());
final claude = ClaudeService(proxyBaseUrl: '', appToken: '');
Offset? heldPosition;
const heldPointer = 130;

class _NoAnalytics implements AnalyticsSink {
  const _NoAnalytics();
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

Element? elementWhere(bool Function(Element) predicate) {
  Element? result;
  void visit(Element e) {
    if (result != null) return;
    if (predicate(e)) {
      result = e;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return result;
}

RenderBox keyedBox(String key) {
  final e = elementWhere((e) => e.widget.key == ValueKey(key));
  if (e == null) throw StateError('Missing capture target: $key');
  return e.findRenderObject()! as RenderBox;
}

NavigatorState get navigator =>
    (elementWhere((e) => e.widget is Navigator)! as StatefulElement).state
        as NavigatorState;

// The same production PracticeScreen with fictional local content. No
// generation or scoring request is made, no entitlement is manufactured.
const articleExample = PracticeSet(topicId: 'articles', items: [
  PracticeItem(
    id: 'store_articles_2',
    type: PracticeItemType.fillInBlank,
    context: '____ honesty matters to her, so she gave me ____ honest answer.',
    instruction:
        'Fill in each blank with a, an or the, or tap — for no article.',
  ),
  PracticeItem(
    id: 'store_articles_next',
    type: PracticeItemType.fillInBlank,
    context: 'We had ____ lunch at ____ small café near ____ station.',
    instruction:
        'Fill in each blank with a, an or the, or tap — for no article.',
  ),
]);

void launch(StorageService store, String key) {
  runApp(LaunchGate(
    key: ValueKey(key),
    initialize: () async {},
    app: (_) => GrammarLensApp(
      storageService: store,
      analyticsService: analytics,
      claudeService: claude,
      clock: () => captureNow,
    ),
  ));
}

Future<void> launchOnboarding() async {
  final store = StorageService(dbName: onboardingDb);
  if (await store.getUserProfile() != null) {
    throw StateError('Onboarding capture DB already has a profile; keep it.');
  }
  await store.setThemeMode(AppThemeMode.light);
  launch(store, 'onboarding-capture');
}

Future<void> main() async {
  enableFlutterDriverExtension(handler: (request) async {
    if (request == 'answers') return jsonEncode(captureAnswers);
    if (request == 'unfocus') {
      FocusManager.instance.primaryFocus?.unfocus();
      return 'ok';
    }
    if (request == 'hold_hint') {
      final box = keyedBox('topic_hint_knob');
      final start = box.localToGlobal(box.size.center(Offset.zero));
      final track = keyedBox('topic_hint_track');
      final travel = track.size.width - 56;
      GestureBinding.instance.handlePointerEvent(
          PointerDownEvent(pointer: heldPointer, position: start));
      var previous = start;
      // Cross the gesture slop, then move to the end and keep the finger
      // down. Native screenshot is taken before PointerUp. This operates
      // the real recognizer; no state field, widget or paint is replaced.
      for (final progress in [0.1, 0.4, 0.7, 1.15]) {
        await Future<void>.delayed(const Duration(milliseconds: 65));
        final next = start + Offset(travel * progress, 0);
        GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
          pointer: heldPointer,
          position: next,
          delta: next - previous,
        ));
        previous = next;
      }
      heldPosition = previous;
      return 'pointer-held';
    }
    if (request == 'release_hint') {
      if (heldPosition != null) {
        GestureBinding.instance.handlePointerEvent(
            PointerUpEvent(pointer: heldPointer, position: heldPosition!));
        heldPosition = null;
      }
      return 'released';
    }
    if (request == 'hint_audit') {
      final card = keyedBox('topic_hint_card');
      final p = card.localToGlobal(Offset.zero);
      final knob = keyedBox('topic_hint_knob');
      final track = keyedBox('topic_hint_track');
      final knobRight = knob.localToGlobal(Offset.zero).dx + knob.size.width;
      final trackRight = track.localToGlobal(Offset.zero).dx + track.size.width;
      final points = kTopicHints[TopicId.tenseSelection]!;
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      return jsonEncode({
        'method': 'real horizontal drag held down through native capture',
        'pointerHeld': heldPosition != null,
        'questionId': captureQuestions.first.item.id,
        'question': captureQuestions.first.item.context,
        'promptVerb': 'see',
        'correctAnswer': captureQuestions.first.correctAnswer,
        'topic': 'tenseSelection',
        'hintPoints': points,
        'promptVerbOrAnswerInHint':
            RegExp(r'\b(?:see|saw)\b', caseSensitive: false)
                .hasMatch(points.join(' ')),
        'knobAtEnd': (knobRight - trackRight).abs() < 0.5,
        'card': {
          'x': p.dx,
          'y': p.dy,
          'w': card.size.width,
          'h': card.size.height
        },
        'screenLogicalHeight': view.physicalSize.height / view.devicePixelRatio,
      });
    }
    if (request == 'onboarding') {
      await launchOnboarding();
      return 'ok';
    }
    if (request == 'articles') {
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          topic: topicById(TopicId.articles),
          practiceSet: articleExample,
          claudeService: claude,
          storageService: storage,
          analyticsService: analytics,
          subscriptionService: SubscriptionService(),
        ),
      ));
      return 'ok';
    }
    return '';
  });
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  // Existing public test seams; fixed date matches every screenshot.
  // ignore: invalid_use_of_visible_for_testing_member
  StorageService.clockForTesting = () => captureNow;
  DebugTools.enabledForTesting = false;
  if (const bool.fromEnvironment('CAPTURE_ONBOARDING_ONLY')) {
    await launchOnboarding();
    return;
  }
  if (await storage.getUserProfile() != null) {
    throw StateError(
        'Capture DB already has a profile; use a new dedicated simulator.');
  }
  await seedScreenshotData(storage, now: captureNow, premium: false);
  await storage.saveDailyTestSet(captureQuestions,
      day: captureDate, source: DailyTestSource.bundled);
  await storage.setThemeMode(AppThemeMode.light);
  launch(storage, 'store-capture');
}
