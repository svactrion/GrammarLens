import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/avatar.dart';
import '../spacing.dart';
import '../theme.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/monthly_climb/monthly_mountain.dart';

/// Standalone visual fixture: deliberately does not initialize app services.
void main() {
  if (!kDebugMode) throw StateError('This preview is debug-only.');
  runApp(const MonthlyClimbPreview());
}

class MonthlyClimbPreview extends StatefulWidget {
  const MonthlyClimbPreview({super.key});
  @override
  State<MonthlyClimbPreview> createState() => _MonthlyClimbPreviewState();
}

class _MonthlyClimbPreviewState extends State<MonthlyClimbPreview> {
  bool _dark = const bool.fromEnvironment('CLIMB_PREVIEW_DARK');
  bool _reduceMotion = false;
  int _days = 30;
  int _progress = 8;
  Avatar _avatar = Avatar.values.first;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  _reduceMotion || MediaQuery.disableAnimationsOf(context)),
          child: child!,
        ),
        home: Builder(builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return BrandScaffold(
            appBar: AppBar(
                title: const Text('Monthly Climb preview'),
                backgroundColor: colors.surfaceContainerLow,
                foregroundColor: colors.onSurface,
                actions: [
                  IconButton(
                      tooltip: 'Toggle dark mode',
                      onPressed: () => setState(() => _dark = !_dark),
                      icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode))
                ]),
            children: [
              const Text('Green Slope',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: Spacing.sm),
              const Text('Visual preview · sample progress'),
              const SizedBox(height: Spacing.lg),
              ClipRRect(
                  borderRadius: BorderRadius.circular(Spacing.lg),
                  child: MonthlyMountain(
                      days: _days, completedDays: _progress, avatar: _avatar)),
              const SizedBox(height: Spacing.sm),
              const Text('Scroll to explore your milestones',
                  textAlign: TextAlign.center),
              const SizedBox(height: Spacing.lg),
              Semantics(
                  liveRegion: true,
                  child: Text('$_progress / $_days days',
                      style: Theme.of(context).textTheme.headlineSmall)),
              const Text('One test. One step.'),
              const SizedBox(height: Spacing.md),
              FilledButton(
                  onPressed: _progress < _days
                      ? () => setState(() => _progress++)
                      : null,
                  child: Text(_progress == _days
                      ? 'Summit reached'
                      : 'Preview next step')),
              const SizedBox(height: Spacing.lg),
              const Text('Month length'),
              Wrap(spacing: Spacing.sm, children: [
                for (final days in [28, 29, 30, 31])
                  ChoiceChip(
                      label: Text('$days days'),
                      selected: days == _days,
                      onSelected: (_) => setState(() {
                            _days = days;
                            _progress = _progress.clamp(0, days);
                          }))
              ]),
              Slider(
                  value: _progress.toDouble(),
                  min: 0,
                  max: _days.toDouble(),
                  divisions: _days,
                  label: '$_progress steps',
                  semanticFormatterCallback: (value) =>
                      '${value.round()} of $_days steps',
                  onChanged: (value) =>
                      setState(() => _progress = value.round())),
              DropdownButtonFormField<Avatar>(
                  initialValue: _avatar,
                  decoration:
                      const InputDecoration(labelText: 'Preview avatar'),
                  items: [
                    for (final avatar in Avatar.values)
                      DropdownMenuItem(
                          value: avatar, child: Text(avatar.semanticLabel))
                  ],
                  onChanged: (avatar) => setState(() => _avatar = avatar!)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                      'Device accessibility settings are also respected.'),
                  value: _reduceMotion,
                  onChanged: (value) => setState(() => _reduceMotion = value)),
            ],
          );
        }),
      );
}
