import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/reminder_settings.dart';
import '../screens/reminder_soft_ask.dart';
import '../services/reminder_controller.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'time_wheel_picker.dart';

/// V24's "Remind me tomorrow · 20:00" (TASK-widgets fixed decision 7): a
/// shortcut to the Daily Test reminder. Before reminders were accepted the
/// switch opens N01 instead; the time chip opens the wheel.
class RestReminderRow extends StatefulWidget {
  const RestReminderRow(
      {super.key, required this.controller, required this.hero});

  final ReminderController controller;
  final Avatar hero;

  static const switchKey = ValueKey('rest_reminder_switch');
  static const timeKey = ValueKey('rest_reminder_time');

  @override
  State<RestReminderRow> createState() => _RestReminderRowState();
}

class _RestReminderRowState extends State<RestReminderRow> {
  ReminderController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    if (!_controller.loaded) _controller.load();
  }

  @override
  void didUpdateWidget(RestReminderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool on) async {
    HapticMap.selection();
    if (_controller.settings.ask != ReminderAsk.accepted) {
      if (on) {
        await showReminderSoftAsk(context,
            controller: _controller, hero: widget.hero);
      }
      return;
    }
    final allowed = await _controller.setKind(ReminderKind.dailyTest, on);
    if (on && !allowed && _controller.deniedByIos && mounted) {
      showRemindersDeniedMessage(context, _controller);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showReminderTimePicker(context,
        initialMinutes: _controller.settings.minutes);
    if (picked != null) await _controller.setMinutes(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    const onPanel = Colors.white;
    final time = reminderTimeLabel(_controller.settings.minutes);
    return Row(children: [
      const Icon(Icons.notifications_none_rounded, color: onPanel, size: 20),
      const SizedBox(width: 8),
      Expanded(
        // One line, as on the board; a long translation or a large text
        // size scales down rather than wrapping.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.restRemind,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.titleSmall!
                .withWeight(FontWeight.w800)
                .copyWith(color: onPanel),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Semantics(
        button: true,
        label: l10n.reminderTimeSemantics(time),
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: RestReminderRow.timeKey,
            borderRadius: BorderRadius.circular(12),
            onTap: _pickTime,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: onPanel.withValues(alpha: .35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  time, // l10n-guard: a clock time of numbers
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.titleSmall!
                      .withWeight(FontWeight.w800)
                      .copyWith(
                          color: onPanel,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more_rounded, color: onPanel, size: 18),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Semantics(
        label: l10n.restRemind,
        child: Switch(
          key: RestReminderRow.switchKey,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          value: _controller.isOn(ReminderKind.dailyTest),
          activeTrackColor: c.green,
          onChanged: _controller.loaded ? _toggle : null,
        ),
      ),
    ]);
  }
}
