import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/early_error_reporting.dart';

/// The launch splash draws before Firebase is ready; errors from that window
/// must still reach crash reporting once it is.
void main() {
  late FlutterExceptionHandler? savedFlutterHandler;
  late ErrorCallback? savedPlatformHandler;
  late List<String> printed;
  late DebugPrintCallback savedPrint;

  setUp(() {
    savedFlutterHandler = FlutterError.onError;
    savedPlatformHandler = PlatformDispatcher.instance.onError;
    printed = [];
    savedPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() {
    FlutterError.onError = savedFlutterHandler;
    PlatformDispatcher.instance.onError = savedPlatformHandler;
    debugPrint = savedPrint;
  });

  FlutterErrorDetails details(String message) =>
      FlutterErrorDetails(exception: StateError(message));

  test('errors before hand-over are kept and passed on in order', () {
    final early = EarlyErrorReporting()..install();

    FlutterError.onError!(details('one'));
    expect(
        PlatformDispatcher.instance.onError!('two', StackTrace.empty), isFalse,
        reason: 'unhandled, so the engine still reports it');
    FlutterError.onError!(details('three'));

    final flutterSeen = <String>[];
    final platformSeen = <Object>[];
    early.handOver(
      onFlutterError: (d) =>
          flutterSeen.add((d.exception as StateError).message),
      onPlatformError: (error, _) {
        platformSeen.add(error);
        return true;
      },
    );

    expect(flutterSeen, ['one', 'three']);
    expect(platformSeen, ['two']);

    // Later errors go straight through, once.
    FlutterError.onError!(details('four'));
    expect(
        PlatformDispatcher.instance.onError!('five', StackTrace.empty), isTrue);
    expect(flutterSeen, ['one', 'three', 'four']);
    expect(platformSeen, ['two', 'five']);
  });

  test('kept Flutter errors are still printed as they happen', () {
    EarlyErrorReporting().install();
    FlutterError.resetErrorCount();
    FlutterError.onError!(details('shown'));
    expect(printed.join('\n'), contains('shown'));
  });

  test('abandon restores the defaults and drops what was kept', () {
    final early = EarlyErrorReporting()..install();
    FlutterError.onError!(details('dropped'));

    early.abandon();

    expect(FlutterError.onError, FlutterError.presentError);
    expect(PlatformDispatcher.instance.onError, isNull);
  });
}
