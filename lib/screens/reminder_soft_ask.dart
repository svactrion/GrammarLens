import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/reminder_settings.dart';
import '../motion.dart';
import '../services/reminder_controller.dart';
import '../theme.dart';
import '../utils/app_messenger.dart';
import '../utils/haptics.dart';
import '../widgets/app_sheet.dart';
import '../widgets/companion_view.dart';
import '../widgets/pressable_button.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/time_wheel_picker.dart';

/// N01: our own reminder question, asked once and before the iOS dialog
/// (TASK-widgets fixed decision 5). "Turn on reminders" → iOS permission →
/// the plan; "Not now" (or closing the sheet) → never asked again on its
/// own. Returns whether reminders are on and allowed by iOS.
Future<bool> showReminderSoftAsk(
  BuildContext context, {
  required ReminderController controller,
  required Avatar hero,
}) async {
  controller.askOpened();
  final minutes = await showAppSheet<int>(
    context: context,
    builder: (_) => ReminderSoftAsk(
        hero: hero, initialMinutes: controller.settings.minutes),
  );
  controller.askClosed();
  if (minutes == null) {
    await controller.notNow();
    return false;
  }
  final allowed = await controller.turnOn(minutes: minutes);
  if (!allowed && controller.deniedByIos && context.mounted) {
    showRemindersDeniedMessage(context, controller);
  }
  return allowed;
}

/// iOS refused notifications: a snackbar with a way to iOS Settings.
void showRemindersDeniedMessage(
    BuildContext context, ReminderController controller) {
  final l10n = context.l10n;
  AppMessenger.show(
    l10n.notifDeniedSnack,
    kind: MessageKind.warning,
    actionLabel: l10n.notifOpenSettings,
    onAction: controller.openSystemSettings,
  );
}

/// The sheet's choices: N01's three times and "Pick a time".
enum _Choice { morning, lunch, evening, custom }

class ReminderSoftAsk extends StatefulWidget {
  const ReminderSoftAsk(
      {super.key, required this.hero, required this.initialMinutes});

  final Avatar hero;

  /// The time preselected: Evening 20:00 unless one was stored.
  final int initialMinutes;

  static const turnOnKey = ValueKey('reminder_soft_ask_turn_on');
  static const notNowKey = ValueKey('reminder_soft_ask_not_now');
  static ValueKey<String> optionKey(String name) =>
      ValueKey('reminder_soft_ask_$name');

  @override
  State<ReminderSoftAsk> createState() => _ReminderSoftAskState();
}

class _ReminderSoftAskState extends State<ReminderSoftAsk> {
  late _Choice _choice = switch (widget.initialMinutes) {
    ReminderSettings.morning => _Choice.morning,
    ReminderSettings.lunch => _Choice.lunch,
    ReminderSettings.evening => _Choice.evening,
    _ => _Choice.custom,
  };
  late int _custom = widget.initialMinutes;

  int get _minutes => switch (_choice) {
        _Choice.morning => ReminderSettings.morning,
        _Choice.lunch => ReminderSettings.lunch,
        _Choice.evening => ReminderSettings.evening,
        _Choice.custom => _custom,
      };

  Future<void> _pick(_Choice choice) async {
    HapticMap.selection();
    if (choice != _Choice.custom) {
      setState(() => _choice = choice);
      return;
    }
    final picked =
        await showReminderTimePicker(context, initialMinutes: _minutes);
    if (picked == null || !mounted) return;
    setState(() {
      _custom = picked;
      _choice = _Choice.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final customPicked = _choice == _Choice.custom;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CompanionView(
                hero: widget.hero,
                mood: CompanionMood.wave,
                size: 76,
                decorative: true),
            const SizedBox(width: 8),
            Expanded(
              child: SpeechBubble(
                text: l10n.softAskBubble,
                pointer: BubblePointer.start,
                compact: true,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l10n.softAskTitle,
              style: theme.textTheme.titleLarge!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.text, letterSpacing: -0.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final (choice, label, time) in [
            (
              _Choice.morning,
              l10n.softAskMorning,
              reminderTimeLabel(ReminderSettings.morning)
            ),
            (
              _Choice.lunch,
              l10n.softAskLunch,
              reminderTimeLabel(ReminderSettings.lunch)
            ),
            (
              _Choice.evening,
              l10n.softAskEvening,
              reminderTimeLabel(ReminderSettings.evening)
            ),
            (
              _Choice.custom,
              l10n.softAskPick,
              customPicked ? reminderTimeLabel(_custom) : null
            ),
          ]) ...[
            _Option(
              key: ReminderSoftAsk.optionKey(choice.name),
              label: label,
              time: time,
              selected: _choice == choice,
              onTap: () => _pick(choice),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            l10n.softAskNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!
                .withWeight(FontWeight.w600)
                .copyWith(color: c.muted),
          ),
          const SizedBox(height: 12),
          PressableButton(
            key: ReminderSoftAsk.turnOnKey,
            label: l10n.softAskTurnOn,
            tone: ButtonTone.orange,
            trailingIcon: Icons.arrow_forward_rounded,
            haptic: ButtonHaptic.medium,
            onPressed: () => Navigator.of(context).pop(_minutes),
          ),
          const SizedBox(height: 4),
          PressableButton(
            key: ReminderSoftAsk.notNowKey,
            label: l10n.softAskNotNow,
            tone: ButtonTone.text,
            haptic: ButtonHaptic.none,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium!
        .withWeight(FontWeight.w800)
        .copyWith(color: selected ? c.onSky : c.text);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.orInstant(context, AppMotion.fast),
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? c.sky : c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? c.navy : c.line, width: selected ? 2.5 : 2),
              boxShadow: [BoxShadow(color: c.lip, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              Expanded(child: Text(label, style: style)),
              if (time != null)
                Text(
                  time!, // l10n-guard: a clock time of numbers
                  style: style.copyWith(
                      color: selected ? c.onSky : c.muted,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_rounded, size: 20, color: c.navy),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
