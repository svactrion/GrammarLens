import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's own Flutter ↔ iOS bridge (TASK-widgets fixed decision 1: no
/// package). One method channel, served by `ios/Runner/GrammarLensBridge.swift`:
/// the App Group files the widgets read, widget reloads, the `grammarlens://`
/// links, and the reminder notifications.
///
/// Every call is best effort, like analytics: on a platform without the
/// bridge (web, a widget test) or on any platform error it returns the
/// "nothing happened" value and never throws.
abstract class NativeBridge {
  /// The bridge the app uses; tests replace it.
  static NativeBridge instance = MethodChannelNativeBridge();

  /// Writes [bytes] to `<App Group>/widget/<name>`. [name] must be a plain
  /// file name (see [isValidFileName]).
  Future<bool> writeAppGroupFile(String name, Uint8List bytes);

  Future<Uint8List?> readAppGroupFile(String name);

  Future<bool> deleteAppGroupFile(String name);

  /// The file names in the shared folder.
  Future<List<String>> listAppGroupFiles();

  /// Whether the App Group container exists (the entitlement is present).
  Future<bool> appGroupAvailable();

  /// `WidgetCenter.reloadAllTimelines()`.
  Future<bool> reloadWidgets();

  /// The link that opened the app (a widget or notification tap on a cold
  /// start), once; null when there is none. Reading it also tells the
  /// native side that [links] is listened to from now on.
  Future<String?> initialLink();

  /// Links that arrive while the app runs.
  Stream<String> get links;

  /// The names the native side accepts: lower-case letters, digits, `_`,
  /// `-` and `.`, at most 96 characters, not starting with a dot.
  static bool isValidFileName(String name) =>
      name.isNotEmpty &&
      name.length <= 96 &&
      !name.startsWith('.') &&
      RegExp(r'^[a-z0-9_.\-]+$').hasMatch(name);
}

class MethodChannelNativeBridge implements NativeBridge {
  MethodChannelNativeBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const channelName = 'com.ahmettayfur.grammarlens/bridge';

  final MethodChannel _channel;
  final _links = StreamController<String>.broadcast();

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'links.open') {
      final url = (call.arguments as Map?)?['url'];
      if (url is String) _links.add(url);
    }
    return null;
  }

  Future<T?> _invoke<T>(String method,
      [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('[bridge] $method failed: ${error.code}');
      return null;
    }
  }

  @override
  Future<bool> writeAppGroupFile(String name, Uint8List bytes) async {
    if (!NativeBridge.isValidFileName(name)) return false;
    return await _invoke<bool>(
            'appGroup.write', {'name': name, 'bytes': bytes}) ??
        false;
  }

  @override
  Future<Uint8List?> readAppGroupFile(String name) async {
    if (!NativeBridge.isValidFileName(name)) return null;
    return _invoke<Uint8List>('appGroup.read', {'name': name});
  }

  @override
  Future<bool> deleteAppGroupFile(String name) async {
    if (!NativeBridge.isValidFileName(name)) return false;
    return await _invoke<bool>('appGroup.delete', {'name': name}) ?? false;
  }

  @override
  Future<List<String>> listAppGroupFiles() async {
    final names = await _invoke<List<Object?>>('appGroup.list');
    return [...?names?.whereType<String>()];
  }

  @override
  Future<bool> appGroupAvailable() async =>
      await _invoke<bool>('appGroup.available') ?? false;

  @override
  Future<bool> reloadWidgets() async =>
      await _invoke<bool>('widgets.reload') ?? false;

  @override
  Future<String?> initialLink() => _invoke<String>('links.initial');

  @override
  Stream<String> get links => _links.stream;
}
