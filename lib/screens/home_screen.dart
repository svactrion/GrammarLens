import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../widgets/avatar_circle.dart';
import 'premium_screen.dart';
import 'topic_practice_screen.dart';

/// Mode-selection Home (PRD v2 §4) — replaces the old topic-list-first Home.
/// Per-topic progress now lives inside Topic Practice's own screen; this
/// screen's only job is the personalized greeting and picking a mode.
class HomeScreen extends StatefulWidget {
  final String userName;
  final Avatar? avatar;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;

  const HomeScreen({
    super.key,
    required this.userName,
    this.avatar,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Guards against a second dialog opening from a rapid double-tap before
  // the first frame with the modal barrier has rendered. Once that barrier
  // is up, showDialog's own modality already blocks a second tap from
  // reaching the card underneath — this only covers the same-frame race.
  bool _infoDialogOpen = false;

  void _openTopicPractice(BuildContext context) {
    widget.analyticsService.modeSelected(AnalyticsService.modeTopic);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicPracticeScreen(
          claudeService: widget.claudeService,
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
        ),
      ),
    );
  }

  void _openPremium(BuildContext context) {
    widget.analyticsService.modeSelected(AnalyticsService.modeEarlyAccess);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  // A SnackBar here previously used the app-wide ScaffoldMessenger (from
  // MaterialApp, shared by every Scaffold in the tree, not just this one),
  // which caused two bugs: repeated taps queued up multiple snackbars
  // instead of replacing one, and since that messenger lives above the
  // Navigator, the snackbar kept showing over whatever screen the user
  // navigated to next instead of closing with this one. A dialog is a real
  // route on this screen's Navigator — modal (so a second tap on the card
  // can't reach it while one is already open) and tied to this screen's
  // lifecycle instead of the whole app's.
  Future<void> _showComingSoonDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (_infoDialogOpen) return;
    setState(() => _infoDialogOpen = true);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _infoDialogOpen = false);
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
          // PRD v2 §11: an avatar next to the greeting, not floating
          // elsewhere on the page, so it reads as "whose home screen this
          // is" rather than a decorative icon.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarCircle(avatar: widget.avatar, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome back, ${widget.userName}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: appBarFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What do you want to practice today?',
            style: theme.textTheme.bodyLarge?.copyWith(color: appBarFg),
          ),
          const SizedBox(height: 24),
          // 2-column grid rather than the vertical stack this used to be.
          // A single column had a lot of unused width, and a grid is the
          // more natural shape to grow into as more modes arrive — no
          // layout rethink needed to add a 5th tile later. A
          // horizontally-swipeable carousel (Instagram-style mode
          // switching) was considered and set aside as unneeded complexity
          // for this few items; revisit if the mode count grows enough
          // that a grid stops being the simpler choice.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.92,
            children: [
              _ModeCard(
                icon: Icons.school_rounded,
                title: 'Topic Practice',
                description:
                    'Deep grammar practice with plain-language feedback.',
                onTap: () => _openTopicPractice(context),
              ),
              _ModeCard(
                icon: Icons.local_fire_department_rounded,
                title: 'Streak Mode',
                description: 'Fast daily rounds to build a streak.',
                badgeLabel: 'Coming soon',
                onTap: () {
                  widget.analyticsService
                      .modeSelected(AnalyticsService.modeStreak);
                  _showComingSoonDialog(
                    context,
                    title: 'Coming soon',
                    message: 'Streak Mode is coming soon.',
                  );
                },
              ),
              _ModeCard(
                icon: Icons.mic_rounded,
                title: 'Voice Practice',
                description: 'Speaking practice with voice feedback.',
                badgeLabel: 'Premium',
                locked: true,
                onTap: () {
                  widget.analyticsService
                      .modeSelected(AnalyticsService.modeVoice);
                  _showComingSoonDialog(
                    context,
                    title: 'Premium feature',
                    message: 'Voice Practice will be part of premium, in a '
                        'later update.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Deliberately not a fifth grid tile: Early Access is commercial
          // framing (PRD v2 §6), not a practice mode, and looking like one
          // of the learning cards above implied it was. Pulled out of the
          // grid into its own full-width row with a structurally different
          // look — outlined/tinted instead of the grid tiles' solid card
          // fill, horizontal icon+text+chevron instead of their icon-on-top
          // layout — so the "this is a different kind of thing" reads
          // instantly, not just via a different color.
          _EarlyAccessBanner(onTap: () => _openPremium(context)),
        ],
      ),
    );
  }
}

/// One mode-selection grid tile: icon (with a lock badge for locked modes)
/// on top, title, status badge, and a short description below — mixing a
/// horizontal top row with a vertical stack beneath it, rather than the
/// single full-width horizontal row this used before switching to a grid.
/// Every card stays tappable even when not yet available — PRD v2 §4 calls
/// for either non-tappable or informative, and a short explanation on tap
/// reads less like a dead end than a disabled card would.
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
    final iconBg = locked
        ? colorScheme.surfaceContainerHighest
        : colorScheme.primaryContainer;
    final iconFg = locked ? muted : colorScheme.onPrimaryContainer;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg,
                    foregroundColor: iconFg,
                    child: Icon(icon, size: 20),
                  ),
                  const Spacer(),
                  if (locked)
                    Icon(Icons.lock_rounded, color: muted, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: locked ? muted : null,
                ),
              ),
              if (badgeLabel != null) ...[
                const SizedBox(height: 6),
                _Badge(label: badgeLabel!),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width, outlined/tinted banner — see the call site's comment for why
/// this deliberately doesn't reuse `_ModeCard`'s solid-fill, icon-on-top
/// look. A subtle tinted fill (rather than fully transparent) is needed in
/// light mode specifically: the page there sits directly on the vivid brand
/// orange (see theme.dart), where a transparent background made onboarding's
/// unselected goal cards unreadable for the same reason (see that screen's
/// history) — some fill is required for the border+text to read as a
/// surface at all, it just doesn't need to be the same fill the mode cards
/// use.
class _EarlyAccessBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EarlyAccessBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.secondary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.secondary, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: colorScheme.secondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Early Access',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "See what's coming with premium — free for now.",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.secondary),
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
