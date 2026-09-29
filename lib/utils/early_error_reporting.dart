import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Catches errors raised before crash reporting is ready, so none is lost.
///
/// The app starts drawing (the launch splash) before Firebase has
/// initialized. Installed first thing in `main()`, this keeps every Flutter
/// and uncaught platform error from that window, reporting it to the console
/// exactly as Flutter would without handlers. [handOver] then sends the kept
/// errors, in order, to crash reporting and routes all later errors there
/// directly; [abandon] (Firebase failed) restores Flutter's defaults and
/// drops the kept errors, which is what happened before this existed.
class EarlyErrorReporting {
  final List<FlutterErrorDetails> _flutterErrors = [];
  final List<(Object, StackTrace)> _platformErrors = [];
  bool _settled = false;

  /// Installs the keeping handlers.
  void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (!_settled) _flutterErrors.add(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_settled) _platformErrors.add((error, stack));
      // Not handled: the engine reports it as it would with no handler.
      return false;
    };
  }

  /// Routes all errors to [onFlutterError] and [onPlatformError] from now
  /// on, after first passing them every error kept so far.
  void handOver({
    required FlutterExceptionHandler onFlutterError,
    required ErrorCallback onPlatformError,
  }) {
    _settled = true;
    FlutterError.onError = onFlutterError;
    PlatformDispatcher.instance.onError = onPlatformError;
    for (final details in _flutterErrors) {
      onFlutterError(details);
    }
    for (final (error, stack) in _platformErrors) {
      onPlatformError(error, stack);
    }
    _flutterErrors.clear();
    _platformErrors.clear();
  }

  /// Crash reporting is unavailable: back to Flutter's default handlers.
  void abandon() {
    _settled = true;
    FlutterError.onError = FlutterError.presentError;
    PlatformDispatcher.instance.onError = null;
    _flutterErrors.clear();
    _platformErrors.clear();
  }
}
