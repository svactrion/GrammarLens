import 'package:flutter/material.dart';

/// First screen a new install ever sees (PRD v2 §4). One job: say what this
/// app does in a sentence or two before asking for anything, then hand off
/// to onboarding. No sign-up, no account — see `first_launch_flow.dart`.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.08).clamp(24.0, 40.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            children: [
              const Spacer(flex: 3),
              CircleAvatar(
                radius: 44,
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                child: const Icon(Icons.auto_awesome_rounded, size: 44),
              ),
              const SizedBox(height: 28),
              Text(
                'GrammarLens',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: appBarFg,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Practice English grammar with instant, plain-language '
                'feedback — no jargon, no judgment, just what to fix and why.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: appBarFg,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onGetStarted,
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
