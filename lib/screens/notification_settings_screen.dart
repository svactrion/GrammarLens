import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/reminder_settings.dart';
import '../services/monthly_medal_rules.dart';
import '../services/reminder_controller.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/companion_view.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable_button.dart';
import '../widgets/time_wheel_picker.dart';
import 'reminder_soft_ask.dart';

/// N03: the reminder settings, from Profile → Settings → Notifications
/// (TASK-widgets fixed decision 6). Four switches (the free ticket only for
/// free users), the Daily Test reminder's time on a wheel, the one-a-day
/// promise; when iOS refused notifications, the state and a way to iOS
/// Settings.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.controller,
    required this.hero,
    SubscriptionService? subscriptionService,
  }) : _subscription = subscriptionService;

  final ReminderController controller;
  final Avatar hero;
  final SubscriptionService? _subscription;

  static ValueKey<String> switchKey(ReminderKind kind) =>
      ValueKey('notifications_switch_${kind.name}');
  static const timeChipKey = ValueKey('notifications_time_chip');
  static const deniedKey = ValueKey('notifications_denied');
  static const openSettingsKey = ValueKey('notifications_open_settings');

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  late final SubscriptionService _subscription =
      widget._subscription ?? SubscriptionService();
  bool _premium = false;

  ReminderController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_changed);
    _controller.load();
    _subscription.hasFullAccess.then((premium) {
      if (mounted) setState(() => _premium = premium);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Back from iOS Settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refreshPermission();
  }

  Future<void> _toggle(ReminderKind kind, bool on) async {
    HapticMap.selection();
    final allowed = await _controller.setKind(kind, on);
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
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;
    final rows = [
      (
        ReminderKind.dailyTest,
        l10n.notifDailyTitle,
        l10n.notifDailyBody,
      ),
      if (!_premium)
        (
          ReminderKind.freeTicket,
          l10n.notifTicketTitle,
          l10n.notifTicketBody,
        ),
      (
        ReminderKind.closeToMedal,
        l10n.notifMedalTitle,
        l10n.notifMedalBody(MonthlyMedalRules.nearMissPoints),
      ),
      (
        ReminderKind.newMountain,
        l10n.notifMountainTitle,
        l10n.notifMountainBody,
      ),
    ];
    return BrandScaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      ),
      horizontalPadding: hPad,
      children: [
        PageHeader(title: l10n.notifTitle),
        const SizedBox(height: 20),
        if (_controller.deniedByIos) ...[
          _DeniedCard(onOpen: _controller.openSystemSettings),
          const SizedBox(height: 14),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Column(
              children: [
                for (final (index, (kind, title, body)) in rows.indexed) ...[
                  if (index > 0)
                    Divider(height: 1, thickness: 1, color: c.line),
                  _SwitchRow(
                    switchKey: NotificationSettingsScreen.switchKey(kind),
                    title: title,
                    body: body,
                    value: _controller.isOn(kind),
                    onChanged:
                        _controller.loaded ? (on) => _toggle(kind, on) : null,
                    extra: kind == ReminderKind.dailyTest
                        ? _TimeChip(
                            label: l10n.notifDailyTime(reminderTimeLabel(
                                _controller.settings.minutes)),
                            onTap: _pickTime,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          CompanionView(
              hero: widget.hero,
              mood: CompanionMood.idle,
              size: 56,
              decorative: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.notifPromise,
              style: theme.textTheme.bodyMedium!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: c.muted),
            ),
          ),
        ]),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    this.extra,
  });

  final Key switchKey;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: c.text)),
              const SizedBox(height: 2),
              Text(body,
                  style: theme.textTheme.bodySmall!.copyWith(color: c.muted)),
              if (extra != null) ...[const SizedBox(height: 8), extra!],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: title,
          child: Switch(
            key: switchKey,
            value: value,
            // N03's switches are navy (the board).
            activeTrackColor: c.navy,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

/// "Every day at 20:00" (N03): a tap opens the wheel.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: c.sky,
        shape: const StadiumBorder(),
        child: InkWell(
          key: NotificationSettingsScreen.timeChipKey,
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, size: 16, color: c.onSky),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: theme.textTheme.labelLarge!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.onSky)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS refused notifications (fixed decision 5): the state and a way to iOS
/// Settings.
class _DeniedCard extends StatelessWidget {
  const _DeniedCard({required this.onOpen});

  final Future<bool> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      key: NotificationSettingsScreen.deniedKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.redSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.notifications_off_rounded, color: c.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.notifDeniedTitle,
                  style: theme.textTheme.titleSmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.onRedSoft)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(l10n.notifDeniedBody,
              style: theme.textTheme.bodySmall!.copyWith(color: c.onRedSoft)),
          const SizedBox(height: 10),
          PressableButton(
            key: NotificationSettingsScreen.openSettingsKey,
            label: l10n.notifOpenSettings,
            tone: ButtonTone.outline,
            height: 48,
            haptic: ButtonHaptic.light,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
