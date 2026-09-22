import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_text_size.dart';
import '../services/monthly_medal_rules.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/welcome_badge_rules.dart';
import '../spacing.dart';
import '../theme.dart';
import '../widgets/app_segmented_button.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/monthly_medal_collection.dart';

/// Standalone visual fixture for `MonthlyMedalCollection`, the same
/// pattern as `monthly_climb_preview.dart` (see that file's own doc
/// comment): deliberately does not initialize `StorageService` or any
/// other app service. Every scenario below is a hand-built
/// [MonthlyMedalProgress]/[MonthlyMedalResult] fixture, not a database
/// read or a clock mock — so a month never actually has to roll over to
/// see every medal state on a device, and nothing here can read or write
/// a real install's `grammar_lens.db`.
///
/// docs/gamification-handoff.md §9/§10.5: this exists to let a device
/// acceptance pass check every medal state (in progress, each finalized
/// tier, "No medal", and several finalized months at once) at Small/
/// Medium/Large text and in both themes, without touching scoring rules
/// or the storage schema. `MonthlyMedalRules` is only *read* here (to
/// compute realistic max scores/thresholds/tiers for the fixtures) —
/// never modified.
void main() {
  if (!kDebugMode) throw StateError('This preview is debug-only.');
  runApp(const MonthlyMedalPreview());
}

/// The states asked for, plus [history]: the shipped app's own real data
/// has only ever shown one finalized month at a time so far, so this adds
/// a scenario with several at once (mixed tiers including "No medal") to
/// check the list layout, not just a single row.
enum _MedalPreviewScenario {
  inProgress(
    'In progress',
    'Only the current month, nothing finalized yet — a brand-new '
        'user\'s first month, or one with no past Daily Test at all.',
  ),
  bronze(
    'Bronze finalized',
    'Last month finalized at Bronze, plus this month already under way.',
  ),
  silver(
    'Silver finalized',
    'Last month finalized at Silver, plus this month already under way.',
  ),
  gold(
    'Gold finalized',
    'Last month finalized at Gold — near-perfect scoring across the '
        'month — plus this month already under way.',
  ),
  noMedal(
    'No medal',
    'Last month finalized below Bronze and frozen as "No medal" rather '
        'than omitted, plus this month already under way.',
  ),
  history(
    'Multiple months',
    'Four finalized months at once (Gold, Silver, No medal, Bronze), '
        'plus this month already under way.',
  );

  const _MedalPreviewScenario(this.label, this.description);
  final String label;
  final String description;
}

/// The fixed "current" month every scenario's in-progress card uses.
/// Arbitrary but fixed, like `monthly_climb_preview.dart`'s own sample
/// data — this file never reads the real clock.
const _currentYear = 2026;
const _currentMonth = 9; // September, 30 days.

MonthlyMedalProgress _progressFixture({
  required int year,
  required int month,
  required int correct,
  required int wrong,
  required int skipped,
  required int activeDays,
}) =>
    MonthlyMedalProgress(
      year: year,
      month: month,
      score: MonthlyMedalRules.score(correct: correct, wrong: wrong),
      maxScore: MonthlyMedalRules.maxScore(year, month),
      activeDays: activeDays,
      correct: correct,
      wrong: wrong,
      skipped: skipped,
    );

/// Tier is derived from the same [MonthlyMedalRules.tierFor] real
/// finalization uses, from the fixture's own score — never hardcoded
/// separately from the numbers that produce it, so a scenario's label
/// (e.g. "Gold finalized") can't silently drift from what the real rule
/// would actually award for these counts.
MonthlyMedalResult _finalizedFixture({
  required int year,
  required int month,
  required int correct,
  required int wrong,
  required int skipped,
  required int activeDays,
}) {
  final score = MonthlyMedalRules.score(correct: correct, wrong: wrong);
  return MonthlyMedalResult(
    year: year,
    month: month,
    score: score,
    maxScore: MonthlyMedalRules.maxScore(year, month),
    activeDays: activeDays,
    correct: correct,
    wrong: wrong,
    skipped: skipped,
    tier: MonthlyMedalRules.tierFor(year: year, month: month, score: score),
    ruleVersion: MonthlyMedalRules.ruleVersion,
    finalizedAt: DateTime.utc(year, month + 1, 3),
  );
}

// docs/gamification-handoff.md §12.5: a toggle orthogonal to the scenario
// dropdown above, not a doubled scenario list — the Welcome badge can
// realistically be earned or not alongside any of the six medal states,
// so this covers every combination with one small addition instead of
// six new entries to keep in sync by hand.
final _welcomeBadgeFixture = WelcomeBadge(
  earnedAt: DateTime.utc(2026, 8, 15),
  ruleVersion: WelcomeBadgeRules.ruleVersion,
  backfilled: false,
);

final _currentInProgress = _progressFixture(
  year: _currentYear,
  month: _currentMonth,
  correct: 48,
  wrong: 8,
  skipped: 4,
  activeDays: 12,
);

// August 2026 (31 days, max score 310, thresholds ~78/155/233) carries
// the single-month scenarios; the multi-month scenario below reuses the
// same shape across four different months instead.
final _augustBronze = _finalizedFixture(
  year: 2026,
  month: 8,
  correct: 35,
  wrong: 10,
  skipped: 55,
  activeDays: 20,
);
final _augustSilver = _finalizedFixture(
  year: 2026,
  month: 8,
  correct: 70,
  wrong: 20,
  skipped: 35,
  activeDays: 25,
);
final _augustGold = _finalizedFixture(
  year: 2026,
  month: 8,
  correct: 150,
  wrong: 5,
  skipped: 0,
  activeDays: 31,
);
final _augustNoMedal = _finalizedFixture(
  year: 2026,
  month: 8,
  correct: 10,
  wrong: 5,
  skipped: 15,
  activeDays: 6,
);

// The multi-month scenario's own four months, deliberately distinct from
// the single-month ones above so both can be spot-checked independently.
final _juneGold = _finalizedFixture(
  year: 2026,
  month: 6,
  correct: 145,
  wrong: 5,
  skipped: 0,
  activeDays: 30,
);
final _julySilver = _finalizedFixture(
  year: 2026,
  month: 7,
  correct: 70,
  wrong: 20,
  skipped: 35,
  activeDays: 25,
);
final _augustNoMedalForHistory = _finalizedFixture(
  year: 2026,
  month: 8,
  correct: 10,
  wrong: 5,
  skipped: 15,
  activeDays: 6,
);
final _mayBronze = _finalizedFixture(
  year: 2026,
  month: 5,
  correct: 33,
  wrong: 13,
  skipped: 44,
  activeDays: 18,
);

({MonthlyMedalProgress? currentProgress, List<MonthlyMedalResult> results})
    _fixturesFor(_MedalPreviewScenario scenario) => switch (scenario) {
          _MedalPreviewScenario.inProgress => (
              currentProgress: _currentInProgress,
              results: const [],
            ),
          _MedalPreviewScenario.bronze => (
              currentProgress: _currentInProgress,
              results: [_augustBronze],
            ),
          _MedalPreviewScenario.silver => (
              currentProgress: _currentInProgress,
              results: [_augustSilver],
            ),
          _MedalPreviewScenario.gold => (
              currentProgress: _currentInProgress,
              results: [_augustGold],
            ),
          _MedalPreviewScenario.noMedal => (
              currentProgress: _currentInProgress,
              results: [_augustNoMedal],
            ),
          _MedalPreviewScenario.history => (
              currentProgress: _currentInProgress,
              // Same order `StorageService.getMonthlyMedalResults` reads
              // real rows in: `month DESC`.
              results: [
                _augustNoMedalForHistory,
                _julySilver,
                _juneGold,
                _mayBronze,
              ],
            ),
        };

class MonthlyMedalPreview extends StatefulWidget {
  const MonthlyMedalPreview({super.key});
  @override
  State<MonthlyMedalPreview> createState() => _MonthlyMedalPreviewState();
}

class _MonthlyMedalPreviewState extends State<MonthlyMedalPreview> {
  bool _dark = const bool.fromEnvironment('MEDAL_PREVIEW_DARK');
  AppTextSize _textSize = AppTextSize.medium;
  _MedalPreviewScenario _scenario = _MedalPreviewScenario.inProgress;
  bool _welcomeEarned = false;

  @override
  Widget build(BuildContext context) {
    final fixtures = _fixturesFor(_scenario);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light, textSize: _textSize),
      darkTheme: buildAppTheme(Brightness.dark, textSize: _textSize),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return BrandScaffold(
          appBar: AppBar(
            title: const Text('Monthly Medal preview'),
            backgroundColor: colors.surfaceContainerLow,
            foregroundColor: colors.onSurface,
            actions: [
              IconButton(
                tooltip: 'Toggle dark mode',
                onPressed: () => setState(() => _dark = !_dark),
                icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
              ),
            ],
          ),
          children: [
            DropdownButtonFormField<_MedalPreviewScenario>(
              initialValue: _scenario,
              // The longest label ("Multiple months") otherwise overflows
              // the field's own row at 320pt width — `isExpanded` lets the
              // selected-value text size to the available width instead of
              // its own natural width.
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Medal state'),
              items: [
                for (final scenario in _MedalPreviewScenario.values)
                  DropdownMenuItem(
                    value: scenario,
                    child: Text(scenario.label),
                  ),
              ],
              onChanged: (scenario) => setState(() => _scenario = scenario!),
            ),
            const SizedBox(height: Spacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                fixtures.results.isEmpty
                    ? _scenario.description
                    : '${_scenario.description} '
                        '(${fixtures.results.length} finalized '
                        '${fixtures.results.length == 1 ? 'month' : 'months'}.)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Text size', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Spacing.sm),
            AppSegmentedButton<AppTextSize>(
              segments: const [
                ButtonSegment(value: AppTextSize.small, label: Text('Small')),
                ButtonSegment(value: AppTextSize.medium, label: Text('Medium')),
                ButtonSegment(value: AppTextSize.large, label: Text('Large')),
              ],
              selected: {_textSize},
              onSelectionChanged: (selection) =>
                  setState(() => _textSize = selection.first),
            ),
            const SizedBox(height: Spacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Welcome badge earned'),
              subtitle: const Text(
                'Independent of the medal state above — a mid-month '
                'starter with no medal history yet, or a returning user '
                'with real history, can each have this on or off.',
              ),
              value: _welcomeEarned,
              onChanged: (value) => setState(() => _welcomeEarned = value),
            ),
            const SizedBox(height: Spacing.xl),
            Text('Monthly medals',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            MonthlyMedalCollection(
              welcomeBadge: _welcomeEarned ? _welcomeBadgeFixture : null,
              currentProgress: fixtures.currentProgress,
              results: fixtures.results,
            ),
          ],
        );
      }),
    );
  }
}
