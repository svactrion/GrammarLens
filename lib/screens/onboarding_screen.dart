import 'package:flutter/material.dart';

import '../models/learning_goal.dart';
import '../models/user_profile.dart';
import '../utils/page_title.dart';

/// Two fields only — name and learning goal (PRD v2 §4). Age and occupation
/// are deliberately left out here: every field asked before the user has
/// experienced any value costs completions on an app with no brand
/// recognition, and those two are marketing data with no in-product use yet.
/// They're available later, optionally, from Settings.
class OnboardingScreen extends StatefulWidget {
  final ValueChanged<UserProfile> onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  LearningGoal? _selectedGoal;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty && _selectedGoal != null;

  void _continue() {
    if (!_canContinue) return;
    widget.onComplete(UserProfile(
      name: _nameController.text.trim(),
      learningGoal: _selectedGoal!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.06).clamp(20.0, 32.0);

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Let\'s get started')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What should we call you?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Your name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Why are you learning English?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This helps us suggest where to start.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final goal in LearningGoal.values) ...[
                      if (goal != LearningGoal.values.first)
                        const SizedBox(height: 12),
                      _GoalOption(
                        goal: goal,
                        selected: goal == _selectedGoal,
                        onTap: () => setState(() => _selectedGoal = goal),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canContinue ? _continue : null,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(LearningGoal goal) {
  switch (goal) {
    case LearningGoal.examPrep:
      return Icons.school_rounded;
    case LearningGoal.work:
      return Icons.work_rounded;
    case LearningGoal.general:
      return Icons.chat_bubble_rounded;
  }
}

/// Selectable goal card — same tap-to-select, icon+title+description,
/// checkmark-on-selected treatment as the practice-length picker's option
/// cards, so onboarding doesn't invent a second selection pattern.
class _GoalOption extends StatelessWidget {
  final LearningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalOption({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onAccent = colorScheme.onSecondary;
    final titleColor = selected ? onAccent : colorScheme.onSurface;
    final subtitleColor = selected ? onAccent : colorScheme.onSurfaceVariant;
    final iconColor = selected ? onAccent : colorScheme.onSurfaceVariant;

    return Material(
      color: selected ? colorScheme.secondary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected ? null : Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(_iconFor(goal), color: iconColor, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: onAccent, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
