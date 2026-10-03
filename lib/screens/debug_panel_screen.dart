import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../utils/debug_sample_collection.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/monthly_climb/climb_debug_controls.dart';
import '../widgets/monthly_climb/climb_debug_day.dart';
import '../widgets/monthly_climb/climb_debug_milestone.dart';
import '../widgets/monthly_climb/climb_debug_month_card.dart';
import '../widgets/monthly_climb/climb_debug_theme.dart';

/// The debug panel (Batch 5, N27): the `CLIMB_DEBUG_*` settings changed
/// while the app runs, in debug and profile builds. Opened from Settings'
/// "Debug" row, which a release build does not have.
///
/// - Theme and day: the scene shows them at once; memory only.
/// - Milestones and month cards: the panel closes, the app shows Home, and
///   Home plays it (`ClimbDebugControls`); the same one can be played again
///   and again. No stored record is read or written, no event is sent.
/// - Sample collection (P6): Profile's shelf shows sample months; memory
///   only, nothing stored is read or written, no event is sent.
/// - "Reset local data": after a confirmation, the app's whole local
///   database goes ([onResetLocalData]) and the app is back at its first
///   launch. The only action here that touches stored data.
class DebugPanelScreen extends StatefulWidget {
  /// Deletes the local data and puts the app back at its first launch.
  final Future<void> Function() onResetLocalData;

  const DebugPanelScreen({super.key, required this.onResetLocalData});

  static const resetKey = ValueKey('debug_reset');
  static const sampleCollectionKey = ValueKey('debug_sample_collection');
  static const dayRealKey = ValueKey('debug_day_real');
  static const daySliderKey = ValueKey('debug_day_slider');
  static ValueKey<String> themeKey(String id) => ValueKey('debug_theme_$id');
  static ValueKey<String> milestoneKey(ClimbDebugMilestoneValue v) =>
      ValueKey('debug_milestone_${v.wireName}');
  static ValueKey<String> monthCardKey(ClimbDebugMonthCardValue v) =>
      ValueKey('debug_month_card_${v.wireName}');

  /// What the reset deletes and what it leaves, said in its confirmation.
  static const resetMessage =
      'This deletes everything this app keeps on this device: your profile '
      '(name, avatar, goal), every Daily Test and its answers, mistakes and '
      'practice counts, the climb and its medals and Welcome badge, the '
      'one-time records (first-day paywall, zooms, month cards), AI '
      'consent, appearance and text size, and the anonymous device id. The '
      'app then starts again at Welcome.\n\nNot touched: your purchases '
      '(App Store and RevenueCat), analytics already sent, and the shared '
      'Daily Test sets on the server.';

  @override
  State<DebugPanelScreen> createState() => _DebugPanelScreenState();
}

class _DebugPanelScreenState extends State<DebugPanelScreen> {
  bool _resetting = false;

  void _setTheme(String? id) =>
      setState(() => ClimbDebugTheme.runtime = id ?? '');

  void _setDay(int? day) => setState(() => ClimbDebugDay.runtime = day ?? -1);

  void _play(VoidCallback ask) {
    Navigator.of(context).pop();
    ask();
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(DebugPanelScreen.resetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete and restart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    final navigator = Navigator.of(context);
    await widget.onResetLocalData();
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final controls = ClimbDebugControls.instance;
    final themeId = ClimbDebugTheme.value?.id;
    final day = ClimbDebugDay.value;
    Widget section(String title, String note) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(note, style: muted),
          ]),
        );
    return BrandScaffold(
      title: const Text('Debug'),
      children: [
        Text(
          'Debug and profile builds only; a release build has none of '
          'this. Theme and day last until the app is closed. Replays send '
          'no events and save nothing.',
          style: muted,
        ),
        section('Theme', 'The scene only; the month keeps its real theme.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            key: DebugPanelScreen.themeKey('real'),
            label: const Text('Real theme'),
            selected: themeId == null,
            onSelected: (_) => _setTheme(null),
          ),
          for (final t in ClimbThemes.all)
            ChoiceChip(
              key: DebugPanelScreen.themeKey(t.id),
              label: Text(t.name),
              selected: themeId == t.id,
              onSelected: (_) => _setTheme(t.id),
            ),
        ]),
        section('Day', 'The step the scene shows; progress is untouched.'),
        SwitchListTile(
          key: DebugPanelScreen.dayRealKey,
          contentPadding: EdgeInsets.zero,
          title: const Text('Real day'),
          value: day == null,
          onChanged: (real) => _setDay(real ? null : 1),
        ),
        if (day != null)
          Row(children: [
            Expanded(
              child: Slider(
                key: DebugPanelScreen.daySliderKey,
                value: day.toDouble(),
                max: 31,
                divisions: 31,
                label: '$day',
                onChanged: (v) => _setDay(v.round()),
              ),
            ),
            SizedBox(width: 56, child: Text('Step $day')),
          ]),
        section(
            'Milestones',
            'Closes the panel and plays it on Home: a tier\'s celebration, '
                'or the step onto a save point and its label.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in ClimbDebugMilestoneValue.values)
            OutlinedButton(
              key: DebugPanelScreen.milestoneKey(v),
              onPressed: () => _play(() => controls.playMilestone(v)),
              child: Text(v.wireName),
            ),
        ]),
        section('Month card', 'Closes the panel and plays it on Home.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in ClimbDebugMonthCardValue.values)
            OutlinedButton(
              key: DebugPanelScreen.monthCardKey(v),
              onPressed: () => _play(() => controls.playMonthCard(v)),
              child: Text(v.wireName),
            ),
        ]),
        section(
            'Profile',
            'For screenshots: the medal shelf shows sample months (the '
                'Welcome badge, seven finished months, this month). Nothing '
                'is saved or sent; off when the app is closed.'),
        SwitchListTile(
          key: DebugPanelScreen.sampleCollectionKey,
          contentPadding: EdgeInsets.zero,
          title: const Text('Sample collection'),
          value: DebugSampleCollection.runtime,
          onChanged: (on) => setState(() => DebugSampleCollection.runtime = on),
        ),
        section(
            'Local data',
            'Deletes this app\'s data on this device and starts again at '
                'Welcome (the first-day flow). Asks first.'),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            key: DebugPanelScreen.resetKey,
            onPressed: _resetting ? null : _reset,
            child: Text(_resetting
                ? 'Resetting…'
                : 'Reset local data (first-day flow)'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
