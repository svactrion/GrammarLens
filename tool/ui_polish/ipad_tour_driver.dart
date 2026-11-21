// 1.5.0 release preparation, step 6 (docs/RELEASE-1.5.0.md): the iPad
// tour. The host side of `flutter drive` on the seeded app
// (`smoke_app.dart`), modelled on `smoke_driver.dart`. Each screen is saved
// in light and in dark (`xcrun simctl ui <udid> appearance`, the app on its
// default "system" theme) to TOUR_OUT.
//
// TOUR_PART picks the walk:
//   fresh    a fresh install (SEED_SKIP=true): Welcome, the hero picker,
//            the name, the goals, getting ready, the mountain intro, the
//            Day 0 test, the results, the badge, the first climb, the
//            paywall's three views, Home after the test, Review, the free
//            ticket on a practice with the hint card open, the wait, the
//            results, the free rest scene with N01, Profile with the
//            progress card, the reminder settings, Wake → the paywall from
//            the rest scene.
//   premium  the seeded learner with SEED_PREMIUM=true: Home before the
//            Daily Test, a question, the result, the step, Home after,
//            Topic Practice (ten cards), the length picker, a practice
//            question with the hint card open, the wait, the results,
//            Review and a weak spot's detail, Profile.
//   lang     the seeded free learner in TOUR_LANG: Home, a Daily Test
//            question, the paywall.
//
//   flutter drive -d <iPad> --target tool/ui_polish/smoke_app.dart \
//     --driver tool/ui_polish/ipad_tour_driver.dart \
//     --dart-define=PROXY_BASE_URL=http://localhost:8787 \
//     --dart-define=APP_TOKEN=local-smoke [--dart-define=SEED_SKIP=true] …
//
// With TOUR_UDID, TOUR_OUT, TOUR_PART and TOUR_LANG (the ARB the walk takes
// its texts from; default `en`), and a local stand-in for the practice
// proxy on port 8787 (canned JSON, no AI call).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _timeout = Duration(seconds: 20);

Future<void> main() async {
  late FlutterDriver d;
  final env = Platform.environment;
  final udid = env['TOUR_UDID']!;
  final out = env['TOUR_OUT']!;
  final part = env['TOUR_PART'] ?? 'fresh';
  final lang = env['TOUR_LANG'] ?? 'en';
  final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
      as Map<String, dynamic>;
  String t(String key) => arb[key] as String;
  var n = 0;

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> appearance(String mode) async {
    await Process.run('xcrun', ['simctl', 'ui', udid, 'appearance', mode]);
  }

  Future<void> capture(String name) async {
    await Process.run(
        'xcrun', ['simctl', 'io', udid, 'screenshot', '--type=png', name]);
  }

  // Light, then dark, then light again for the next step.
  Future<void> shot(String name) async {
    n++;
    final base = '$out/${n.toString().padLeft(2, '0')}-$name';
    await capture('$base-light.png');
    await appearance('dark');
    await wait(900);
    await capture('$base-dark.png');
    await appearance('light');
    await wait(700);
    stdout.writeln('shot $base');
  }

  Future<void> tap(SerializableFinder f) =>
      d.runUnsynchronized(() => d.tap(f, timeout: _timeout));

  Future<void> type(SerializableFinder f, String text) async {
    await tap(f);
    await d.runUnsynchronized(() => d.enterText(text, timeout: _timeout));
  }

  Future<bool> present(SerializableFinder f, {int ms = 1500}) async {
    try {
      await d.runUnsynchronized(
          () => d.waitFor(f, timeout: Duration(milliseconds: ms)));
      return true;
    } catch (_) {
      return false;
    }
  }

  SerializableFinder first(SerializableFinder f) => find.descendant(
      of: find.byType('MaterialApp'), matching: f, firstMatchOnly: true);

  Future<void> back() => tap(first(find.byType('PageBackButton')));

  Future<void> scroll(SerializableFinder f, double dy) => d.runUnsynchronized(
      () => d.scroll(f, 0, dy, const Duration(milliseconds: 300),
          timeout: _timeout));

  // The hint card opens while its knob is held and dragged along the track;
  // the capture is taken while the drag is still held.
  Future<void> hintOpen(String name) async {
    final knob = find.byValueKey('topic_hint_knob');
    if (!await present(knob)) {
      stdout.writeln('no hint slider on this question');
      return;
    }
    final drag = d.runUnsynchronized(() => d.scroll(
        knob, 900, 0, const Duration(milliseconds: 4500),
        timeout: _timeout));
    await wait(3600);
    n++;
    await capture('$out/${n.toString().padLeft(2, '0')}-$name-light.png');
    await drag;
    await wait(800);
    stdout.writeln('shot $name (light only: held drag)');
  }

  Future<void> paywallViews(String prefix) async {
    await shot('$prefix-first-view');
    if (await present(find.byValueKey('premium_compare_plans'))) {
      await tap(find.byValueKey('premium_compare_plans'));
      await wait(1800);
    } else {
      await scroll(find.byValueKey('premiumBody'), -700);
      await wait(1200);
    }
    await shot('$prefix-compare');
    if (await present(find.byValueKey('premium_choose_plan_hint'))) {
      await tap(find.byValueKey('premium_choose_plan_hint'));
      await wait(2200);
    } else {
      await scroll(find.byValueKey('premiumBody'), -900);
      await wait(1200);
    }
    await shot('$prefix-plans');
  }

  Future<void> closePaywall() async {
    await tap(find.byValueKey('premium_close'));
    await wait(1200);
    if (await present(find.byValueKey('premium_exit_continue_free'))) {
      await shot('V13b-exit');
      await tap(find.byValueKey('premium_exit_continue_free'));
    }
    await wait(2000);
  }

  Future<void> practice(String prefix) async {
    await wait(800);
    await shot('$prefix-V18-preparing');
    await wait(2500);
    for (var i = 0; i < 3; i++) {
      await shot('$prefix-q${i + 1}');
      if (i == 0) await hintOpen('$prefix-q1-hint-open');
      await type(find.byValueKey('question_answer_field'), 'a');
      await wait(300);
      await tap(find.byValueKey('practice_step_primary'));
      await wait(i == 2 ? 2000 : 1200);
    }
    await shot('$prefix-V20-waiting');
    await wait(6000);
    await shot('$prefix-V21-results');
  }

  await appearance('light');
  d = await FlutterDriver.connect();
  try {
    if (part == 'fresh') {
      await wait(5000);
      await shot('V02-welcome');
      await tap(find.byValueKey('welcome_get_started'));
      await wait(1500);
      await shot('V03-hero-picker');
      await tap(find.byValueKey('buddy_confirm'));
      await wait(1200);
      await shot('V04-name-asks');
      await type(find.byValueKey('onboarding_name'), 'Ada');
      await wait(1500);
      await shot('V04-name-greets');
      await tap(find.byValueKey('onboarding_continue'));
      await wait(1000);
      await shot('V05-goals');
      await tap(find.byValueKey('onboarding_goal_work'));
      await wait(700);
      await tap(find.byValueKey('onboarding_start'));
      await wait(1500);
      await shot('V05b-getting-ready');
      await wait(4000);
      await shot('V06-mountain-intro');
      await tap(find.byValueKey('mountain_intro_start'));
      await wait(1500);
      const answers = [
        'eat',
        'She is the best student in our class',
        'She can speak three languages',
        'would',
        'saw',
      ];
      for (var i = 0; i < answers.length; i++) {
        if (i == 0) await shot('V07-daily-question');
        await type(find.byValueKey('question_answer_field'), answers[i]);
        await wait(400);
        await tap(find.byValueKey('daily_test_check'));
        await wait(900);
        if (i == 0) await shot('V09-wrong');
        if (i == 1) await shot('V08-correct');
        await tap(find.byValueKey('daily_test_continue'));
        await wait(1200);
      }
      await wait(2500);
      await shot('V10-results');
      await tap(find.byValueKey('resultPrimary'));
      await wait(2500);
      await shot('V11-badge');
      await tap(find.byValueKey('medal_celebration_continue'));
      await wait(5500);
      await shot('V12-first-climb');
      await tap(find.byValueKey('first_climb_continue'));
      await wait(2200);
      await paywallViews('V13');
      await closePaywall();
      await shot('V14-home-after-test');
      await scroll(find.byValueKey('home_greeting_line'), -600);
      await wait(1000);
      await shot('V14-home-after-test-scrolled');

      await tap(find.text(t('featureReview')));
      await wait(1500);
      await shot('V16-review');
      await tap(find.byValueKey('review_practice_ticket'));
      await wait(1500);
      if (await present(find.text(t('aiConsentAgree')))) {
        await shot('V17-consent');
        await tap(find.text(t('aiConsentAgree')));
      }
      await practice('ticket');
      await tap(find.text(t('resultsBackToTopics')));
      await wait(1500);
      await shot('V22-review-after-ticket');
      await tap(find.text(t('navHome')));
      await wait(2500);
      await shot('V24f-rest-free-N01');
      if (await present(find.text(t('softAskNotNow')))) {
        await tap(find.text(t('softAskNotNow')));
        await wait(1500);
      }
      await shot('V24f-rest-free');

      await tap(find.text(t('navProfile')));
      await wait(1500);
      await shot('V23-profile');
      await d.runUnsynchronized(() => d.scrollUntilVisible(
          find.byValueKey('profile_ribbon'),
          find.byValueKey('medal_progress_card'),
          dyScroll: -250,
          timeout: _timeout));
      await wait(1500);
      await shot('V23p-progress-card');
      await d.runUnsynchronized(() => d.scrollUntilVisible(
          find.byValueKey('medal_progress_card'),
          find.byValueKey('settings_notifications_row'),
          dyScroll: -250,
          timeout: _timeout));
      await tap(find.byValueKey('settings_notifications_row'));
      await wait(1500);
      await shot('N03-reminder-settings');
      await back();
      await wait(1200);
      await tap(find.text(t('navHome')));
      await wait(1500);
      await tap(find.byValueKey('rest_wake'));
      await wait(3200);
      await paywallViews('V13r');
      await closePaywall();
      await shot('V24f-back-asleep');
    } else if (part == 'premium') {
      await wait(5000);
      await shot('H04-home-premium-before-test');
      await scroll(find.byValueKey('home_greeting_line'), -600);
      await wait(1000);
      await shot('H04-home-premium-scrolled');
      await d.runUnsynchronized(() => d.scrollIntoView(
          find.byValueKey('daily_test_card_button'),
          timeout: _timeout));
      await wait(800);
      await tap(find.byValueKey('daily_test_card_button'));
      await wait(2500);
      await shot('V07-daily-question');
      for (var i = 0; i < 5; i++) {
        await type(find.byValueKey('question_answer_field'), 'a');
        await wait(400);
        await tap(find.byValueKey('daily_test_check'));
        await wait(900);
        if (i == 0) await shot('V09-wrong');
        await tap(find.byValueKey('daily_test_continue'));
        await wait(1200);
      }
      await wait(2500);
      await shot('V10-results');
      await tap(find.byValueKey('resultPrimary'));
      await wait(4000);
      await shot('V15-home-on-return');
      // A second day: N01 may open over Home; "Not now", then the step.
      if (await present(find.byValueKey('reminder_soft_ask_not_now'))) {
        await tap(find.byValueKey('reminder_soft_ask_not_now'));
        await wait(2500);
        await shot('V15-step-after-N01');
      }
      await wait(5000);
      await shot('V15-home-after-test');
      await scroll(find.byValueKey('home_greeting_line'), -700);
      await wait(1000);
      await shot('V15-home-after-test-scrolled');
      // Topic Practice from Home's practice card (a topic chip).
      var opened = false;
      for (final name in ['Modal Verbs', 'Articles', 'Gerund vs. Infinitive']) {
        if (await present(first(find.text(name)), ms: 800)) {
          await tap(first(find.text(name)));
          opened = true;
          break;
        }
      }
      stdout.writeln('topic practice opened from Home: $opened');
      await wait(1800);
      await shot('R01-topics');
      await scroll(find.byValueKey('topic_card_tenseSelection'), -900);
      await wait(1200);
      await shot('R01-topics-end');
      await tap(find.byValueKey('topic_card_conditionals'));
      await wait(1500);
      if (await present(find.text(t('aiConsentAgree')))) {
        await shot('V17-consent');
        await tap(find.text(t('aiConsentAgree')));
        await wait(1500);
      }
      await shot('R02-length');
      // An ICU plural: the `other` branch with the default length, 5.
      final startLabel = RegExp(r'other\{([^}]*\{count\}[^}]*)\}')
          .firstMatch(t('lengthPickerStart'))!
          .group(1)!
          .replaceAll('{count}', '5');
      await tap(first(find.text(startLabel)));
      await wait(1200);
      await practice('topic');
      // "Back to topics" returns to the first route, Home.
      await tap(find.text(t('resultsBackToTopics')));
      await wait(1500);
      await tap(find.text(t('featureReview')));
      await wait(1800);
      await shot('R12-review-premium');
      await tap(first(find.byType('ReviewSpotCard')));
      await wait(1800);
      await shot('R03-weak-spot');
      await back();
      await wait(1200);
      await tap(find.text(t('navProfile')));
      await wait(1500);
      await shot('V23-profile-premium');
    } else {
      await wait(5000);
      await shot('$lang-home');
      await scroll(find.byValueKey('home_greeting_line'), -700);
      await wait(1000);
      await shot('$lang-home-scrolled');
      await tap(find.byValueKey('home_unlock_topics'));
      await wait(2200);
      await paywallViews('$lang-V13');
      await closePaywall();
      await d.runUnsynchronized(() => d.scrollIntoView(
          find.byValueKey('daily_test_card_button'),
          timeout: _timeout));
      await wait(800);
      await tap(find.byValueKey('daily_test_card_button'));
      await wait(2500);
      await shot('$lang-V07-question');
      await hintOpen('$lang-V07-hint-open');
      await type(find.byValueKey('question_answer_field'), 'a');
      await wait(400);
      await tap(find.byValueKey('daily_test_check'));
      await wait(900);
      await shot('$lang-V09-wrong');
    }
  } catch (e) {
    stdout.writeln('tour stopped: $e');
    await shot('stopped-here');
    exitCode = 1;
  } finally {
    await appearance('light');
    await d.close();
  }
}
