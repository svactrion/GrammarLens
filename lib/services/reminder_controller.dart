import 'package:flutter/foundation.dart';

import '../models/reminder_settings.dart';
import 'device_sync.dart';
import 'native_bridge.dart';
import 'storage_service.dart';

/// "20:30": the reminder time, the same in every language (24-hour clock,
/// Western digits), as on N01, N03 and V24.
String reminderTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// The reminder settings as N01, N03 and V24's switch change them
/// (TASK-widgets fixed decisions 5–7): stored on the device, then the plan
/// is rebuilt (`StorageService.onChanged` → `DeviceSync`).
class ReminderController extends ChangeNotifier {
  ReminderController({required this.storage, NativeBridge? bridge})
      : bridge = bridge ?? NativeBridge.instance;

  final StorageService storage;
  final NativeBridge bridge;

  ReminderSettings _settings = const ReminderSettings();
  NotificationPermission _permission = NotificationPermission.unknown;
  bool _loaded = false;
  bool _settingsRead = false;
  bool _askShowing = false;

  ReminderSettings get settings => _settings;
  NotificationPermission get permission => _permission;
  bool get loaded => _loaded;

  /// iOS said no: Settings shows the state and a link (fixed decision 5).
  bool get deniedByIos => _permission == NotificationPermission.denied;

  /// Our own question (N01) may open on its own: never asked yet (and the
  /// stored answer was actually read).
  bool get mayAsk =>
      _settingsRead && _settings.ask == ReminderAsk.notAsked && !_askShowing;

  /// A row's switch: on only once reminders were accepted.
  bool isOn(ReminderKind kind) =>
      _settings.ask == ReminderAsk.accepted && _settings.isOn(kind);

  Future<void> load() async {
    try {
      _settings = await storage.getReminderSettings();
      _settingsRead = true;
    } catch (_) {
      // Storage unavailable: the defaults (off, not asked) stay.
    }
    _permission = await bridge.notificationPermission();
    _loaded = true;
    notifyListeners();
  }

  /// N01 is open: it must not open twice.
  void askOpened() => _askShowing = true;
  void askClosed() => _askShowing = false;

  /// "Turn on reminders" (N01) or the first switch turned on (N03, V24):
  /// every kind on at [minutes] (fixed decision 6), then the iOS dialog when
  /// iOS has not asked yet. True when iOS allows reminders.
  Future<bool> turnOn({int? minutes}) async {
    await _save(_settings.turnedOn(minutes: minutes));
    return _ensurePermission();
  }

  /// "Not now" (or N01 dismissed): never asked again on its own.
  Future<void> notNow() => _save(_settings.copyWith(ask: ReminderAsk.declined));

  /// One row's switch. Turning one on before reminders were accepted turns
  /// reminders on (all four). True when iOS allows reminders.
  Future<bool> setKind(ReminderKind kind, bool on) async {
    if (on && _settings.ask != ReminderAsk.accepted) return turnOn();
    await _save(_settings.withKind(kind, on));
    if (!on) return true;
    return _ensurePermission();
  }

  Future<void> setMinutes(int minutes) =>
      _save(_settings.copyWith(minutes: minutes.clamp(0, 1439)));

  Future<bool> openSystemSettings() => bridge.openNotificationSettings();

  /// After iOS Settings: the permission may have changed.
  Future<void> refreshPermission() async {
    final before = _permission;
    _permission = await bridge.notificationPermission();
    if (_permission != before) {
      notifyListeners();
      DeviceSync.requestUpdate();
    }
  }

  Future<bool> _ensurePermission() async {
    var permission = await bridge.notificationPermission();
    if (permission == NotificationPermission.notDetermined) {
      await bridge.requestNotificationPermission();
      permission = await bridge.notificationPermission();
    }
    _permission = permission;
    notifyListeners();
    // The settings were saved before iOS answered; schedule again now.
    DeviceSync.requestUpdate();
    return permission.allowsReminders;
  }

  Future<void> _save(ReminderSettings settings) async {
    _settings = settings;
    notifyListeners();
    try {
      await storage.setReminderSettings(settings);
    } catch (_) {
      // Kept in memory for this run; the next launch reads what was stored.
    }
  }
}
