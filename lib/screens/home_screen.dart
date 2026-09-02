import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/layout_constants.dart';
import '../widgets/avatar_tile.dart';
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
  // Nullable, same as ReviewScreen's `onGoToPractice`: the bottom-nav tab
  // switch lives in app.dart's State, not here, so this is a hook rather
  // than HomeScreen owning navigation itself.
  final VoidCallback? onAvatarTap;

  const HomeScreen({
    super.key,
    required this.userName,
    this.avatar,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    this.onAvatarTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, navBarClearance),
        children: [
          // PRD v2 §11: an avatar next to the greeting, not floating
          // elsewhere on the page, so it reads as "whose home screen this
          // is" rather than a decorative icon. Greeting leads on the left,
          // avatar pinned to the far right edge (trailing, not centered
          // against the text) — `spaceBetween` with a `Flexible` (not
          // `Expanded`) text so the avatar always lands flush against the
          // trailing edge regardless of how short the greeting is, while a
          // long name still truncates instead of pushing the avatar off
          // the visible row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Welcome back, ${widget.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: appBarFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // PRD v2 §11's natural follow-up: the avatar is the user's
              // own identity marker, and Settings is where it (and the
              // rest of the profile) is edited — tapping it jumps there
              // directly instead of requiring the Settings tab first.
              InkWell(
                // Matches AvatarTile's own corner rounding at radius: 22
                // (radius * 0.6) — a circular ripple would visibly mismatch
                // the tile's now-square shape.
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                onTap: widget.onAvatarTap,
                child: AvatarTile(avatar: widget.avatar, radius: 22),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What do you want to practice today?',
            style: theme.textTheme.bodyLarge?.copyWith(color: appBarFg),
          ),
          const SizedBox(height: 24),
          // Streak Mode and Voice Practice used to fill out a 2-column grid
          // alongside this card, each just a "coming soon" tile leading to
          // an informational dialog — neither is actually built. Apple's
          // App Review guidance flags that pattern as a completeness risk,
          // and both are already listed as coming-soon premium features on
          // the Premium screen below, so keeping them here was pure
          // duplication. With only one real mode left, a single full-width
          // card reads as deliberate rather than a leftover grid slot.
          _PracticeModeCard(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description:
                'Deep grammar practice with plain-language feedback.',
            onTap: () => _openTopicPractice(context),
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

/// The single mode-selection card: a full-width row rather than the
/// icon-on-top grid tile this used to be alongside Streak Mode and Voice
/// Practice — with only one real mode left, a lone icon-on-top tile in a
/// now-empty 2-column grid would read as a layout bug, not a deliberate
/// choice.
class _PracticeModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PracticeModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Icon(icon, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width, solid-fill banner in the app's deep-blue accent — see the
/// call site's comment for why this deliberately doesn't reuse
/// `_PracticeModeCard`'s look. A first pass used a faint tinted fill
/// with just an outline, which read as washed-out against the vivid brand
/// orange in light mode (too close to the page color to register as a
/// distinct surface) — a solid `colorScheme.secondary` fill, the same
/// color/contrast pairing `FilledButton` already uses elsewhere, reads
/// clearly against both the orange page and the cream/white mode cards
/// without needing a border to define its edges.
class _EarlyAccessBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EarlyAccessBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSecondary = colorScheme.onSecondary;

    return Material(
      color: colorScheme.secondary,
      elevation: 4,
      shadowColor: colorScheme.shadow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: onSecondary,
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
                        color: onSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "See what's coming with premium — free for now.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: onSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
