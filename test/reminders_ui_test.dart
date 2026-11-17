import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/screens/notification_settings_screen.dart';
import 'package:grammar_lens/screens/reminder_soft_ask.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/reminder_controller.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/rest_reminder_row.dart';
import 'package:grammar_lens/widgets/time_wheel_picker.dart';

import 'support/fake_native_bridge.dart';
import 'support/l10n_support.dart';

class _Storage extends StorageService {
  ReminderSettings settings = const ReminderSettings();
  int writes = 0;

  @override
  Future<ReminderSettings> getReminderSettings() async => settings;

  @override
  Future<void> setReminderSettings(ReminderSettings settings) async {
    this.settings = settings;
    writes++;
  }
}

class _Subscription extends SubscriptionService {
  _Subscription(this.premium);
  final bool premium;
  @override
  Future<bool> get hasFullAccess async => premium;
}

late _Storage _storage;
late FakeNativeBridge _bridge;
late ReminderController _controller;

Future<void> _pump(WidgetTester tester, Widget child,
    {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(brightness),
    scaffoldMessengerKey: AppMessenger.key,
    home: child,
  ));
  await tester.pumpAndSettle();
}

/// A page with a button that opens N01 and remembers what it returned.
class _AskHost extends StatefulWidget {
  const _AskHost();
  @override
  State<_AskHost> createState() => _AskHostState();
}

bool? askResult;

class _AskHostState extends State<_AskHost> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => askResult = await showReminderSoftAsk(
                context,
                controller: _controller,
                hero: Avatar.fox),
            child: const Text('open'),
          ),
        ),
      );
}

Future<void> _openAsk(WidgetTester tester) async {
  await _pump(tester, const _AskHost());
  await _controller.load();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _storage = _Storage();
    _bridge = FakeNativeBridge()
      ..permission = NotificationPermission.notDetermined;
    _controller = ReminderController(storage: _storage, bridge: _bridge);
    askResult = null;
  });

  group('N01 soft ask', () {
    testWidgets('the board\'s copy; Evening 20:00 is preselected',
        (tester) async {
      await _openAsk(tester);
      for (final text in [
        en.softAskBubble,
        en.softAskTitle,
        en.softAskMorning,
        '08:30',
        en.softAskLunch,
        '12:30',
        en.softAskEvening,
        '20:00',
        en.softAskPick,
        en.softAskNote,
        en.softAskTurnOn,
        en.softAskNotNow,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      final evening =
          tester.getSemantics(find.byKey(ReminderSoftAsk.optionKey('evening')));
      expect(evening.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets(
        'Turn on reminders: iOS is asked after our question, every kind '
        'starts on, at the chosen time', (tester) async {
      await _openAsk(tester);
      expect(_bridge.permissionRequests, 0,
          reason: 'our question comes before the iOS dialog');
      await tester.tap(find.byKey(ReminderSoftAsk.optionKey('morning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReminderSoftAsk.turnOnKey));
      await tester.pumpAndSettle();
      expect(_bridge.permissionRequests, 1);
      expect(askResult, isTrue);
      expect(_storage.settings,
          const ReminderSettings().turnedOn(minutes: ReminderSettings.morning));
      expect(_controller.mayAsk, isFalse);
    });

    testWidgets('Not now: declined, iOS never asked, not asked again',
        (tester) async {
      await _openAsk(tester);
      await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
      await tester.pumpAndSettle();
      expect(askResult, isFalse);
      expect(_storage.settings.ask, ReminderAsk.declined);
      expect(_storage.settings.anyOn, isFalse);
      expect(_bridge.permissionRequests, 0);
      expect(_controller.mayAsk, isFalse);
    });

    testWidgets('closing the sheet counts as Not now', (tester) async {
      await _openAsk(tester);
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(_storage.settings.ask, ReminderAsk.declined);
    });

    testWidgets('Pick a time opens the wheel; the time shows on the choice',
        (tester) async {
      await _openAsk(tester);
      await tester.tap(find.byKey(ReminderSoftAsk.optionKey('custom')));
      await tester.pumpAndSettle();
      expect(find.byKey(ReminderTimePickerKeys.wheel), findsOneWidget);
      expect(find.text(en.reminderTimeTitle), findsOneWidget);
      await tester.drag(
          find.byKey(ReminderTimePickerKeys.wheel), const Offset(0, -40),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReminderTimePickerKeys.save));
      await tester.pumpAndSettle();
      final custom =
          tester.getSemantics(find.byKey(ReminderSoftAsk.optionKey('custom')));
      expect(custom.flagsCollection.isSelected, Tristate.isTrue);
      await tester.tap(find.byKey(ReminderSoftAsk.turnOnKey));
      await tester.pumpAndSettle();
      expect(_storage.settings.ask, ReminderAsk.accepted);
      expect(
          find.descendant(
              of: find.byType(ReminderSoftAsk),
              matching:
                  find.text(reminderTimeLabel(_storage.settings.minutes))),
          findsNothing,
          reason: 'the sheet has closed');
    });

    testWidgets('iOS says no: a snackbar points to iOS Settings',
        (tester) async {
      _bridge.grantOnRequest = false;
      await _openAsk(tester);
      await tester.tap(find.byKey(ReminderSoftAsk.turnOnKey));
      await tester.pumpAndSettle();
      expect(askResult, isFalse);
      expect(find.text(en.notifDeniedSnack), findsOneWidget);
      await tester.tap(find.text(en.notifOpenSettings));
      await tester.pumpAndSettle();
      expect(_bridge.settingsOpened, 1);
    });
  });

  group('N03 notification settings', () {
    Future<void> pumpN03(WidgetTester tester, {bool premium = false}) => _pump(
        tester,
        NotificationSettingsScreen(
          controller: _controller,
          hero: Avatar.fox,
          subscriptionService: _Subscription(premium),
        ));

    Switch switchOf(WidgetTester tester, ReminderKind kind) => tester
        .widget<Switch>(find.byKey(NotificationSettingsScreen.switchKey(kind)));

    testWidgets('four rows for a free user, the promise; all off before',
        (tester) async {
      await pumpN03(tester);
      for (final text in [
        en.notifTitle,
        en.notifDailyTitle,
        en.notifDailyBody,
        en.notifDailyTime('20:00'),
        en.notifTicketTitle,
        en.notifTicketBody,
        en.notifMedalTitle,
        en.notifMedalBody(5),
        en.notifMountainTitle,
        en.notifMountainBody,
        en.notifPromise,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('When you’re 5 points or less away.'), findsOneWidget);
      for (final kind in ReminderKind.values) {
        expect(switchOf(tester, kind).value, isFalse);
      }
      expect(find.byKey(NotificationSettingsScreen.deniedKey), findsNothing);
    });

    testWidgets('Premium: no free-ticket row', (tester) async {
      await pumpN03(tester, premium: true);
      expect(find.text(en.notifTicketTitle), findsNothing);
      expect(
          find.byKey(
              NotificationSettingsScreen.switchKey(ReminderKind.freeTicket)),
          findsNothing);
    });

    testWidgets(
        'the first switch turned on turns all four on and asks iOS; then '
        'each switch is its own', (tester) async {
      await pumpN03(tester);
      await tester.tap(find.byKey(
          NotificationSettingsScreen.switchKey(ReminderKind.closeToMedal)));
      await tester.pumpAndSettle();
      expect(_bridge.permissionRequests, 1);
      for (final kind in ReminderKind.values) {
        expect(switchOf(tester, kind).value, isTrue, reason: kind.name);
      }
      await tester.tap(find.byKey(
          NotificationSettingsScreen.switchKey(ReminderKind.newMountain)));
      await tester.pumpAndSettle();
      expect(switchOf(tester, ReminderKind.newMountain).value, isFalse);
      expect(switchOf(tester, ReminderKind.dailyTest).value, isTrue);
      expect(_storage.settings.newMountain, isFalse);
      expect(_storage.settings.ask, ReminderAsk.accepted);
    });

    testWidgets('the time chip opens the wheel; Save keeps the new time',
        (tester) async {
      _storage.settings = const ReminderSettings().turnedOn();
      await pumpN03(tester);
      await tester.tap(find.byKey(NotificationSettingsScreen.timeChipKey));
      await tester.pumpAndSettle();
      await tester.drag(
          find.byKey(ReminderTimePickerKeys.wheel), const Offset(0, -40),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReminderTimePickerKeys.save));
      await tester.pumpAndSettle();
      expect(
          find.text(
              en.notifDailyTime(reminderTimeLabel(_storage.settings.minutes))),
          findsOneWidget);
    });

    testWidgets('iOS refused: the state and a way to iOS Settings',
        (tester) async {
      _bridge.permission = NotificationPermission.denied;
      _storage.settings = const ReminderSettings().turnedOn();
      await pumpN03(tester);
      expect(find.byKey(NotificationSettingsScreen.deniedKey), findsOneWidget);
      expect(find.text(en.notifDeniedTitle), findsOneWidget);
      await tester.tap(find.byKey(NotificationSettingsScreen.openSettingsKey));
      await tester.pumpAndSettle();
      expect(_bridge.settingsOpened, 1);
    });

    testWidgets('dark theme and the largest text: nothing overflows',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      _storage.settings = const ReminderSettings().turnedOn();
      _bridge.permission = NotificationPermission.denied;
      await _pump(
          tester,
          NotificationSettingsScreen(
              controller: _controller,
              hero: Avatar.fox,
              subscriptionService: _Subscription(false)),
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });

  group('V24 "Remind me tomorrow"', () {
    Future<void> pumpRow(WidgetTester tester) => _pump(
        tester,
        Scaffold(
          backgroundColor: Colors.indigo,
          body: Center(
              child:
                  RestReminderRow(controller: _controller, hero: Avatar.fox)),
        ));

    testWidgets('before reminders were accepted the switch opens N01',
        (tester) async {
      await pumpRow(tester);
      expect(find.text(en.restRemind), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      await tester.tap(find.byKey(RestReminderRow.switchKey));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSoftAsk), findsOneWidget);
      await tester.tap(find.byKey(ReminderSoftAsk.turnOnKey));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byKey(RestReminderRow.switchKey)).value,
          isTrue);
    });

    testWidgets('afterwards it is the Daily Test reminder\'s switch',
        (tester) async {
      _storage.settings = const ReminderSettings().turnedOn();
      await pumpRow(tester);
      await tester.tap(find.byKey(RestReminderRow.switchKey));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSoftAsk), findsNothing);
      expect(_storage.settings.dailyTest, isFalse);
      expect(_storage.settings.freeTicket, isTrue, reason: 'the others stay');
      await tester.tap(find.byKey(RestReminderRow.switchKey));
      await tester.pumpAndSettle();
      expect(_storage.settings.dailyTest, isTrue);
    });

    testWidgets('one line at 320 pt with the largest text, nothing overflows',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: Scaffold(
          backgroundColor: Colors.indigo,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Center(
                child:
                    RestReminderRow(controller: _controller, hero: Avatar.fox)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(find.text(en.restRemind));
      expect(label.maxLines, 1);
    });

    testWidgets('the time opens the wheel', (tester) async {
      await pumpRow(tester);
      await tester.tap(find.byKey(RestReminderRow.timeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReminderTimePickerKeys.wheel), findsOneWidget);
    });
  });

  test('reminderTimeLabel: 24-hour, two digits', () {
    expect(reminderTimeLabel(0), '00:00');
    expect(reminderTimeLabel(8 * 60 + 5), '08:05');
    expect(reminderTimeLabel(23 * 60 + 59), '23:59');
  });
}
