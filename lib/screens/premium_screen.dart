import 'package:flutter/material.dart';

import '../utils/page_title.dart';
import 'paywall_screen.dart';

/// PRD v2 §6's original framing revised for §12.2's free/trial/paid split
/// (decided §12.1: Topic Practice triggers a real Sonnet call per user, so
/// "everything free during early access" stopped being sustainable). Daily
/// Test — deterministic, one shared generation a day — is the only feature
/// that stays unconditionally free; Topic Practice is trial-then-paid.
/// This screen states that split and is the entry point to [PaywallScreen],
/// which itself still has no live product to purchase against (see
/// docs/roadmap.md) — that gap is real and left visible there, not hidden.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaywallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Early Access')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child:
                        const Icon(Icons.workspace_premium_rounded, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You're one of our first users — Daily Test is free, "
                    'always, and Topic Practice starts with a free trial.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No credit card surprises — trial length, price, and '
                    'billing terms are always shown clearly before you '
                    'start anything.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel("What's free, trial, and paid"),
          const SizedBox(height: 8),
          const _FeatureTile(
            icon: Icons.today_rounded,
            title: 'Daily Test',
            description:
                'A quick 5-question warm-up, refreshed every day — free, '
                'no trial or account needed.',
            status: 'Free',
          ),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description:
                'Personalized questions and plain-language feedback on '
                'your own recurring mistakes.',
            status: '3-day trial',
          ),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.local_fire_department_rounded,
            title: 'Unlimited Streak Mode',
            description:
                'Start streak runs instantly, with no daily limit and no '
                'ad to watch first.',
            status: 'Coming soon',
          ),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.mic_rounded,
            title: 'AI Voice Practice',
            description:
                'A speaking mode with real-time voice feedback, on top of '
                "today's writing practice.",
            status: 'Coming soon',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openPaywall(context),
              child: const Text('Start free trial'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Topic Practice generates a real AI call for every session, so '
            "it can't stay free at scale the way Daily Test's single "
            'shared, once-a-day generation can. The trial is there so you '
            'can try the personalized feedback before deciding.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? status;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(width: 8),
                        _Badge(label: status!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
