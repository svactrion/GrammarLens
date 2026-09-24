import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/app_orientation.dart';

/// The app is portrait-only on iPhone and iPad. Flutter's preferred
/// orientations and Info.plist's lists are two sources for the same rule;
/// these tests pin both and keep them from drifting apart.

final _plist = File('ios/Runner/Info.plist').readAsStringSync();

/// The `<string>` entries of the array under [key] in Info.plist.
List<String> _plistArray(String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(_plist);
  expect(match, isNotNull, reason: '$key is missing from Info.plist');
  return RegExp('<string>([^<]*)</string>')
      .allMatches(match!.group(1)!)
      .map((m) => m.group(1)!)
      .toList();
}

const _plistName = {
  DeviceOrientation.portraitUp: 'UIInterfaceOrientationPortrait',
  DeviceOrientation.portraitDown: 'UIInterfaceOrientationPortraitUpsideDown',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lockAppOrientation asks the platform for portrait up and down only',
      () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await lockAppOrientation();

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(orientationCalls, hasLength(1));
    expect(orientationCalls.single.arguments, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
  });

  test('appOrientations holds no landscape orientation', () {
    expect(appOrientations, isNot(contains(DeviceOrientation.landscapeLeft)));
    expect(appOrientations, isNot(contains(DeviceOrientation.landscapeRight)));
  });

  test('Info.plist allows portrait only on iPhone', () {
    expect(_plistArray('UISupportedInterfaceOrientations'),
        ['UIInterfaceOrientationPortrait']);
  });

  test('Info.plist iPad list matches appOrientations exactly', () {
    expect(_plistArray('UISupportedInterfaceOrientations~ipad'),
        appOrientations.map((o) => _plistName[o]).toList());
  });

  test('Info.plist opts out of iPad multitasking', () {
    // A portrait-only iPad app must require full screen: an app that
    // supports Split View/Slide Over has to support all four orientations,
    // and App Store validation rejects the upload otherwise.
    expect(
      RegExp(r'<key>UIRequiresFullScreen</key>\s*<true/>').hasMatch(_plist),
      isTrue,
    );
  });
}
