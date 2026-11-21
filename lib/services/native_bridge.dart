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

  /// iOS notification permission (`UNAuthorizationStatus`).
  Future<NotificationPermission> notificationPermission();

  /// Shows the iOS permission dialog (once per install; afterwards iOS
  /// answers at once). True when granted.
  Future<bool> requestNotificationPermission();

  /// Replaces every pending reminder with [reminders]; returns how many
  /// were scheduled.
  Future<int> scheduleReminders(List<ReminderRequest> reminders);

  /// Removes every pending and delivered reminder.
  Future<bool> cancelReminders();

  /// The ids of the pending reminders.
  Future<List<String>> pendingReminders();

  /// Opens this app's page in iOS Settings (notifications on iOS 16+).
  Future<bool> openNotificationSettings();

  /// The names the native side accepts: lower-case letters, digits, `_`,
  /// `-` and `.`, at most 96 characters, not starting with a dot.
  static bool isValidFileName(String name) =>
      name.isNotEmpty &&
      name.length <= 96 &&
      !name.startsWith('.') &&
      RegExp(r'^[a-z0-9_.\-]+$').hasMatch(name);
}

enum NotificationPermission {
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,

  /// No answer (no native side).
  unknown;

  bool get allowsReminders =>
      this == authorized || this == provisional || this == ephemeral;

  static NotificationPermission parse(String? value) =>
      values.firstWhere((p) => p.name == value,
          orElse: () => NotificationPermission.unknown);
}

/// One reminder for iOS: fires once at the local date and time [at].
class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.link,
    this.image,
  });

  final String id;
  final DateTime at;
  final String title;
  final String body;

  /// Opened on a tap (`grammarlens://…`).
  final String link;

  /// An App Group file shown as the notification's picture (the companion).
  final String? image;

  Map<String, Object?> toMap() => {
        'id': id,
        'year': at.year,
        'month': at.month,
        'day': at.day,
        'hour': at.hour,
        'minute': at.minute,
        'title': title,
        'body': body,
        'link': link,
        if (image != null) 'image': image,
      };
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

  @override
  Future<NotificationPermission> notificationPermission() async =>
      NotificationPermission.parse(
          await _invoke<String>('notifications.status'));

  @override
  Future<bool> requestNotificationPermission() async =>
      await _invoke<bool>('notifications.request') ?? false;

  @override
  Future<int> scheduleReminders(List<ReminderRequest> reminders) async =>
      await _invoke<int>('notifications.schedule', {
        'items': [for (final r in reminders) r.toMap()],
      }) ??
      0;

  @override
  Future<bool> cancelReminders() async =>
      await _invoke<bool>('notifications.cancelAll') ?? false;

  @override
  Future<List<String>> pendingReminders() async {
    final ids = await _invoke<List<Object?>>('notifications.pending');
    return [...?ids?.whereType<String>()];
  }

  @override
  Future<bool> openNotificationSettings() async =>
      await _invoke<bool>('settings.openNotifications') ?? false;
}
