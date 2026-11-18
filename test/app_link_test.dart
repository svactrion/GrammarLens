import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/services/app_link.dart';
import 'package:grammar_lens/services/native_bridge.dart';

import 'support/fake_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLink.parse', () {
    test('reads the three places', () {
      expect(AppLink.parse('grammarlens://daily-test'), AppLink.dailyTest);
      expect(AppLink.parse('grammarlens://home'), AppLink.home);
      expect(AppLink.parse('grammarlens://review'), AppLink.review);
    });

    test('ignores case, a trailing slash, a query and the short form', () {
      expect(AppLink.parse('GrammarLens://Daily-Test/'), AppLink.dailyTest);
      expect(AppLink.parse('grammarlens://home?from=widget'), AppLink.home);
      expect(AppLink.parse('grammarlens:review'), AppLink.review);
    });

    test('rejects anything else', () {
      expect(AppLink.parse(null), isNull);
      expect(AppLink.parse(''), isNull);
      expect(AppLink.parse('https://home'), isNull);
      expect(AppLink.parse('grammarlens://settings'), isNull);
      expect(AppLink.parse('grammarlens://'), isNull);
    });

    test('W01 v12: a weak spot\'s link names its topic and type', () {
      final url = AppLink.weakSpotUrl('gerundVsInfinitive', 'gerund_after_x');
      expect(url, startsWith('grammarlens://weak-spot?'));
      expect(AppLink.parse(url), AppLink.weakSpot);
      expect(AppLink.weakSpotOf(url),
          const WeakSpotLink('gerundVsInfinitive', 'gerund_after_x'));
      expect(AppLink.weakSpotOf('grammarlens://weak-spot'), isNull);
      expect(AppLink.weakSpotOf('grammarlens://review?topic=a&type=b'), isNull);
    });

    test('url round-trips', () {
      for (final link in AppLink.values) {
        expect(AppLink.parse(link.url), link);
      }
    });
  });

  group('AppLinkRouter', () {
    test('W01 v12: a weak spot\'s link carries it; without one, Review',
        () async {
      final bridge = FakeNativeBridge();
      final router = AppLinkRouter(bridge);
      await router.start();
      final got = <AppLink>[];
      router.attach(got.add);
      bridge.pushLink(AppLink.weakSpotUrl('articles', 'a_vs_an'));
      await Future<void>.delayed(Duration.zero);
      expect(got, [AppLink.weakSpot]);
      expect(router.weakSpot, const WeakSpotLink('articles', 'a_vs_an'));
      bridge.pushLink('grammarlens://weak-spot');
      await Future<void>.delayed(Duration.zero);
      expect(got, [AppLink.weakSpot, AppLink.review]);
    });

    test('a cold-start link waits for the shell, then arrives once', () async {
      final bridge = FakeNativeBridge(initial: 'grammarlens://daily-test');
      final router = AppLinkRouter(bridge);
      await router.start();
      expect(router.pending, AppLink.dailyTest);

      final got = <AppLink>[];
      router.attach(got.add);
      expect(got, [AppLink.dailyTest]);
      expect(router.pending, isNull);
      router.attach(got.add);
      expect(got, [AppLink.dailyTest], reason: 'not delivered twice');
    });

    test('warm links go straight to the handler', () async {
      final bridge = FakeNativeBridge();
      final router = AppLinkRouter(bridge);
      await router.start();
      final got = <AppLink>[];
      router.attach(got.add);
      bridge.pushLink('grammarlens://review');
      bridge.pushLink('grammarlens://nope');
      bridge.pushLink('grammarlens://home');
      await Future<void>.delayed(Duration.zero);
      expect(got, [AppLink.review, AppLink.home]);
    });

    test('the latest link wins while waiting', () async {
      final bridge = FakeNativeBridge(initial: 'grammarlens://home');
      final router = AppLinkRouter(bridge);
      await router.start();
      bridge.pushLink('grammarlens://review');
      await Future<void>.delayed(Duration.zero);
      expect(router.pending, AppLink.review);
    });

    test('detached (onboarding): links are dropped', () async {
      final bridge = FakeNativeBridge(initial: 'grammarlens://daily-test');
      final router = AppLinkRouter(bridge);
      await router.start();
      router.detach();
      expect(router.pending, isNull);
      bridge.pushLink('grammarlens://home');
      await Future<void>.delayed(Duration.zero);
      final got = <AppLink>[];
      router.attach(got.add);
      expect(got, isEmpty);
    });
  });

  group('MethodChannelNativeBridge', () {
    const channel = MethodChannel('test/bridge');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'appGroup.write':
          case 'appGroup.delete':
          case 'widgets.reload':
          case 'appGroup.available':
            return true;
          case 'appGroup.read':
            return Uint8List.fromList([1, 2, 3]);
          case 'appGroup.list':
            return ['a.png', 'payload.json'];
          case 'links.initial':
            return 'grammarlens://home';
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends each call with its arguments', () async {
      final bridge = MethodChannelNativeBridge(channel: channel);
      expect(
          await bridge.writeAppGroupFile(
              'payload.json', Uint8List.fromList([7])),
          isTrue);
      expect(await bridge.readAppGroupFile('payload.json'), [1, 2, 3]);
      expect(await bridge.listAppGroupFiles(), ['a.png', 'payload.json']);
      expect(await bridge.deleteAppGroupFile('a.png'), isTrue);
      expect(await bridge.reloadWidgets(), isTrue);
      expect(await bridge.appGroupAvailable(), isTrue);
      expect(await bridge.initialLink(), 'grammarlens://home');
      expect(calls.map((c) => c.method), [
        'appGroup.write',
        'appGroup.read',
        'appGroup.list',
        'appGroup.delete',
        'widgets.reload',
        'appGroup.available',
        'links.initial',
      ]);
      expect((calls.first.arguments as Map)['name'], 'payload.json');
    });

    test('never sends an unsafe file name', () async {
      final bridge = MethodChannelNativeBridge(channel: channel);
      for (final name in ['../x', 'a/b', '.hidden', 'UPPER.png', '', 'a b']) {
        expect(await bridge.writeAppGroupFile(name, Uint8List(1)), isFalse);
        expect(await bridge.readAppGroupFile(name), isNull);
      }
      expect(calls, isEmpty);
    });

    test('a link pushed by iOS reaches the stream', () async {
      final bridge = MethodChannelNativeBridge(channel: channel);
      final next = bridge.links.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall(
            'links.open', {'url': 'grammarlens://daily-test'})),
        (_) {},
      );
      expect(await next, 'grammarlens://daily-test');
    });

    test('without the native side every call is a quiet no-op', () async {
      final bridge = MethodChannelNativeBridge(
          channel: const MethodChannel('test/missing'));
      expect(await bridge.reloadWidgets(), isFalse);
      expect(await bridge.initialLink(), isNull);
      expect(await bridge.listAppGroupFiles(), isEmpty);
      expect(await bridge.writeAppGroupFile('a.png', Uint8List(1)), isFalse);
    });

    test('a platform error is swallowed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      final bridge = MethodChannelNativeBridge(channel: channel);
      expect(await bridge.reloadWidgets(), isFalse);
      expect(await bridge.readAppGroupFile('a.png'), isNull);
    });
  });

  test('isValidFileName', () {
    expect(NativeBridge.isValidFileName('mountain_2026-11_light.png'), isTrue);
    expect(NativeBridge.isValidFileName('a' * 97), isFalse);
  });
}
