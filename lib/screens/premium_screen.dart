import 'package:flutter/material.dart';

import '../utils/page_title.dart';

/// PRD v2 §6 — informational only. No payment flow, no price, no "buy"
/// button anywhere on this screen: its only job is to make the commercial
/// frame real ("this becomes a paid product eventually") without promising
/// free access will last forever, since that promise would become a
/// constraint the moment real pricing ships.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
                    "You're one of our first users — everything is free "
                    'while we\'re in early access.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No credit card, no purchase, nothing to set up — just '
                    'full access, on us, for now.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('What premium will include'),
          const SizedBox(height: 8),
          const _FeatureTile(
            icon: Icons.local_fire_department_rounded,
            title: 'Unlimited Streak Mode',
            description:
                'Start streak runs instantly, with no daily limit and no '
                'ad to watch first.',
            comingSoon: true,
          ),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.mic_rounded,
            title: 'AI Voice Practice',
            description:
                'A speaking mode with real-time voice feedback, on top of '
                "today's writing practice.",
            comingSoon: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Both modes are still being built. This screen exists so it\'s '
            'clear up front what premium will be, and that right now — '
            'during early access — it costs nothing.',
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
  final bool comingSoon;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    this.comingSoon = false,
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
                      if (comingSoon) ...[
                        const SizedBox(width: 8),
                        const _Badge(label: 'Coming soon'),
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
