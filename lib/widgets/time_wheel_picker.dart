import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import 'app_sheet.dart';
import 'pressable_button.dart';

/// The reminder time as a wheel (TASK-widgets fixed decision 6): N01's
/// "Pick a time", N03's time chip and V24's. A 24-hour wheel in every
/// language, like the time it sets. Returns the minutes after midnight, or
/// null when closed without saving.
Future<int?> showReminderTimePicker(BuildContext context,
    {required int initialMinutes}) {
  return showAppSheet<int>(
    context: context,
    builder: (context) => _TimeWheelSheet(initialMinutes: initialMinutes),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initialMinutes});

  final int initialMinutes;

  static const wheelKey = ValueKey('reminder_time_wheel');
  static const saveKey = ValueKey('reminder_time_save');

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

/// Keys for tests.
abstract final class ReminderTimePickerKeys {
  static const wheel = _TimeWheelSheet.wheelKey;
  static const save = _TimeWheelSheet.saveKey;
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _minutes = widget.initialMinutes;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final start = DateTime(2000, 1, 1, _minutes ~/ 60, _minutes % 60);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reminderTimeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge!
                .withWeight(FontWeight.w900)
                .copyWith(color: c.text),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: theme.textTheme.headlineSmall!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: c.text),
                ),
              ),
              child: Directionality(
                // Hours before minutes in every language.
                textDirection: TextDirection.ltr,
                child: CupertinoDatePicker(
                  key: _TimeWheelSheet.wheelKey,
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: start,
                  onDateTimeChanged: (time) =>
                      setState(() => _minutes = time.hour * 60 + time.minute),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PressableButton(
            key: _TimeWheelSheet.saveKey,
            label: l10n.commonSave,
            tone: ButtonTone.navy,
            haptic: ButtonHaptic.light,
            onPressed: () => Navigator.of(context).pop(_minutes),
          ),
        ],
      ),
    );
  }
}
