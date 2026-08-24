import 'package:flutter/material.dart';

import '../services/claude_service.dart';
import '../services/storage_service.dart';
import 'topic_practice_screen.dart';

/// Mode-selection Home (PRD v2 §4) — replaces the old topic-list-first Home.
/// Per-topic progress now lives inside Topic Practice's own screen; this
/// screen's only job is the personalized greeting and picking a mode.
class HomeScreen extends StatelessWidget {
  final String userName;
  final ClaudeService claudeService;
  final StorageService storageService;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.claudeService,
    required this.storageService,
  });

  void _openTopicPractice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicPracticeScreen(
          claudeService: claudeService,
          storageService: storageService,
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'GrammarLens',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: appBarFg,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
        children: [
          Text(
            'Welcome back, $userName',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: appBarFg),
          ),
          const SizedBox(height: 4),
          Text(
            'What do you want to practice today?',
            style: theme.textTheme.bodyLarge?.copyWith(color: appBarFg),
          ),
          const SizedBox(height: 24),
          _ModeCard(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description:
                'Deep practice by grammar topic, with plain-language '
                'feedback on every mistake.',
            onTap: () => _openTopicPractice(context),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.local_fire_department_rounded,
            title: 'Streak Mode',
            description: 'Fast daily rounds to build a practice streak.',
            badgeLabel: 'Coming soon',
            onTap: () => _showComingSoon(
              context,
              'Streak Mode is coming soon.',
            ),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.mic_rounded,
            title: 'Voice Practice',
            description: 'Practice speaking and get feedback on your voice.',
            badgeLabel: 'Premium',
            locked: true,
            onTap: () => _showComingSoon(
              context,
              'Voice Practice will be part of premium, in a later update.',
            ),
          ),
        ],
      ),
    );
  }
}

/// One mode-selection card. [badgeLabel] shows a small pill in the corner
/// for non-active modes ("Coming soon" / "Premium"); [locked] additionally
/// mutes the card and swaps the trailing chevron for a lock icon. Every
/// card stays tappable even when not yet available — PRD v2 §4 calls for
/// either non-tappable or informative, and a short explanation on tap reads
/// less like a dead end than a disabled card would.
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? badgeLabel;
  final bool locked;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    this.badgeLabel,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final iconBg =
        locked ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer;
    final iconFg = locked ? muted : colorScheme.onPrimaryContainer;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBg,
                foregroundColor: iconFg,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: locked ? muted : null,
                            ),
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: 8),
                          _Badge(label: badgeLabel!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: muted,
                size: locked ? 20 : 24,
              ),
            ],
          ),
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
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
