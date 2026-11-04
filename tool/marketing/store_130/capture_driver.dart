// Extends tool/marketing/capture_driver.dart: real widgets, native PNGs.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

const timeout = Duration(seconds: 40);
late FlutterDriver driver;
late Map<String, dynamic> labels;
String label(String key) => labels[key] as String;
final device = Platform.environment['SCREENSHOT_UDID']!;
final output = Platform.environment['SCREENSHOT_OUT']!;
final isIpad = Platform.environment['SCREENSHOT_FAMILY'] == 'ipad';
final onboardingOnly = Platform.environment['SCREENSHOT_MODE'] == 'onboarding';
Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
Future<void> tap(SerializableFinder finder) async {
  await driver.waitFor(finder, timeout: timeout);
  await driver.tap(finder, timeout: timeout);
}

SerializableFinder tab(String label) => find.descendant(
    of: find.byType('_FloatingNavBar'),
    matching: find.text(label),
    firstMatchOnly: true);
SerializableFinder list(String screen) => find.descendant(
    of: find.byType(screen),
    matching: find.byType('ListView'),
    firstMatchOnly: true);
Future<void> shot(String name) async {
  await wait(1600);
  final result = await Process.run('xcrun', [
    'simctl',
    'io',
    device,
    'screenshot',
    '--type=png',
    '$output/$name.png'
  ]);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  stdout.writeln('Captured $name');
}

Future<void> onboarding() async {
  // Welcome never settles: reuse the original screenshot driver's rule.
  await driver.runUnsynchronized(() async {
    await driver.waitFor(find.text(label('getStarted')), timeout: timeout);
    await wait(1500);
    await driver.tap(find.text(label('getStarted')), timeout: timeout);
  });
  await driver.waitFor(find.byValueKey('onboarding_name'), timeout: timeout);
  await tap(find.byValueKey('onboarding_name'));
  await driver.enterText('Sam', timeout: timeout);
  await driver.requestData('unfocus');
  for (var n = 0; n < 17; n++) {
    if (await driver.getText(find.byValueKey('avatar_carousel_caption')) ==
        label('fox')) {
      break;
    }
    await tap(find.byValueKey('avatar_carousel_next'));
    await wait(700);
  }
  if (await driver.getText(find.byValueKey('avatar_carousel_caption')) !=
      label('fox')) {
    throw StateError('Fox selection did not settle.');
  }
  await shot('07-onboarding');
}

Future<void> main() async {
  Directory(output).createSync(recursive: true);
  driver = await FlutterDriver.connect(timeout: const Duration(minutes: 2));
  try {
    await driver
        .waitUntilFirstFrameRasterized()
        .timeout(const Duration(minutes: 2));
    await wait(3000);
    labels = jsonDecode(await driver.requestData('labels')) as Map<String, dynamic>;
    final expected = Platform.environment['SCREENSHOT_LANGUAGE']!.split('-').first;
    if (labels['locale'] != expected || labels['languageSetting'] != 'system') {
      throw StateError('Wrong interface language: $labels, expected $expected / system');
    }
    File('$output/locale-audit.json').writeAsStringSync(jsonEncode(labels));
    if (onboardingOnly) {
      await onboarding();
      return;
    }
    await driver.waitFor(find.text(label('start')), timeout: timeout);
    await wait(3500);
    final answers = (jsonDecode(await driver.requestData('answers')) as List)
        .cast<String>();
    await tap(find.text(label('start')));
    await shot('04-question');
    await driver.requestData('hold_hint');
    await driver.waitFor(find.byValueKey('topic_hint_card'), timeout: timeout);
    await shot('02-hint');
    final hintAudit = jsonDecode(await driver.requestData('hint_audit'))
        as Map<String, dynamic>;
    await driver.requestData('release_hint');
    await driver.waitForAbsent(find.byValueKey('topic_hint_card'),
        timeout: timeout);
    hintAudit['releasedAndCardClosed'] = true;
    File('$output/hint-state.json').writeAsStringSync(jsonEncode(hintAudit));
    for (final (i, answer) in answers.indexed) {
      await tap(find.byType('TextField'));
      await driver.enterText(answer, timeout: timeout);
      await tap(find.text(i == answers.length - 1 ? label('finish') : label('next')));
      await wait(700);
    }
    await driver.waitFor(find.text(label('climb')), timeout: timeout);
    await shot('01-results');
    await tap(find.text(label('climb')));
    await wait(7000);
    await driver.scroll(
        list('HomeScreen'), 0, 4000, const Duration(milliseconds: 400),
        timeout: timeout);
    await shot('03-home');
    await tap(tab(label('review')));
    await shot('05-review');
    await tap(tab(label('profile')));
    if (!isIpad) {
      await driver.scrollIntoView(find.text(label('collection')),
          alignment: 0.02, timeout: timeout);
    }
    await shot('06-collection');
    if (!isIpad) {
      await driver.requestData('articles');
      await driver.waitFor(find.byValueKey('question_blank_box_0'),
          timeout: timeout);
      await tap(find.byValueKey('question_no_article_0'));
      await tap(find.byValueKey('question_blank_box_1'));
      await driver.enterText('an', timeout: timeout);
      await driver.requestData('unfocus');
      await shot('08-multi-blank');
      await driver.requestData('onboarding');
      await onboarding();
    }
  } finally {
    await driver.close();
  }
}
