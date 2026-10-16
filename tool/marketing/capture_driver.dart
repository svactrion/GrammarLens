// Steers production widgets; saves native simulator screenshots. No UI redraw.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

const timeout = Duration(seconds: 30);
late FlutterDriver driver;
final device = Platform.environment['SCREENSHOT_UDID']!;
final output = Platform.environment['SCREENSHOT_OUT']!;
Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
Future<void> tap(SerializableFinder finder) async {
  await driver.waitFor(finder, timeout: timeout);
  await driver.tap(finder, timeout: timeout);
}
SerializableFinder tab(String label) => find.descendant(
  of: find.byType('_FloatingNavBar'), matching: find.text(label), firstMatchOnly: true);
SerializableFinder list(String screen) => find.descendant(
  of: find.byType(screen), matching: find.byType('ListView'), firstMatchOnly: true);
Future<void> shot(String name) async {
  await wait(1600);
  final result = await Process.run('xcrun', ['simctl', 'io', device,
    'screenshot', '--type=png', '$output/$name.png']);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  stdout.writeln('Captured $name');
}
Future<void> main() async {
  Directory(output).createSync(recursive: true);
  driver = await FlutterDriver.connect(timeout: const Duration(minutes: 2));
  await driver.waitUntilFirstFrameRasterized().timeout(const Duration(minutes: 2));
  await driver.waitFor(find.text('Start daily test'), timeout: timeout);
  await wait(3500);
  await shot('01-home');
  final answers = (jsonDecode(await driver.requestData('answers')) as List).cast<String>();
  await tap(find.text('Start daily test'));
  await tap(find.byType('TextField'));
  await driver.enterText(answers.first, timeout: timeout);
  await driver.requestData('unfocus');
  // Keep the native keyboard closed so the full question and action are readable.
  await shot('02-daily-test');
  for (final (i, answer) in answers.indexed) {
    await tap(find.byType('TextField'));
    await driver.enterText(answer, timeout: timeout);
    await tap(find.text(i == answers.length-1 ? 'Finish' : 'Next'));
    await wait(700);
  }
  await driver.waitFor(find.text('See your climb'), timeout: timeout);
  await shot('03-feedback');
  await tap(find.text('See your climb'));
  await wait(7000);
  await driver.scroll(list('HomeScreen'), 0, 4000, const Duration(milliseconds: 400), timeout: timeout);
  await shot('01-home');
  await tap(tab('Review'));
  await shot('04-review');
  await tap(find.descendant(of: find.byType('ReviewScreen'),
    matching: find.byType('WeakSpotCard'), firstMatchOnly: true));
  await shot('05-weak-spot');
  await tap(find.pageBack());
  await tap(tab('Profile'));
  await driver.requestData('release_look');
  await wait(1600);
  await driver.scrollIntoView(find.text('Medal collection'), alignment: 0.02, timeout: timeout);
  await shot('06-medals');
  await driver.close();
}
