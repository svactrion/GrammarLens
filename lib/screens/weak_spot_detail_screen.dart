import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../models/avatar.dart';
import '../widgets/companion_view.dart';
import '../widgets/pressable_button.dart';
import '../widgets/review_parts.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/ticket.dart';
import '../models/error_entry.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/loading_view.dart';
import '../utils/premium_copy.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/section_title.dart';
import '../widgets/feedback_text.dart';
import '../widgets/mistake_breakdown.dart';
import 'practice_launch.dart';
import 'premium_screen.dart';
import '../theme.dart';

/// Shown before targeted practice starts (Iteration 1 P0, from user testing:
/// tapping a weak spot used to jump straight into fresh questions with no
/// reminder of what was actually wrong). Summarizes the rule, how often it's
/// come up, and recent mistakes, then hands off to the same generation path
/// as every other practice launch.
class WeakSpotDetailScreen extends StatefulWidget {
  final Topic topic;
  final WeakSpot spot;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  /// The user's buddy, saying the rule (R03).
  final Avatar? hero;

  const WeakSpotDetailScreen({
    super.key,
    required this.topic,
    required this.spot,
    this.hero,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
  });

  @override
  State<WeakSpotDetailScreen> createState() => _WeakSpotDetailScreenState();
}

class _WeakSpotDetailScreenState extends State<WeakSpotDetailScreen> {
  late Future<List<ErrorEntry>> _mistakes;
  bool _generating = false;

  /// The ticket is tearing (V16b); practice starts once it has played.
  bool _tearing = false;

  // Starts closed/zero the same way HomeScreen's own `_hasFullAccess` does
  // (fail-closed default while a check is in flight) — this screen only
  // needs a one-shot read, not HomeScreen's addAccessListener live-update
  // wiring: `launchPracticeSet` re-checks both entitlement and quota fresh
  // at the moment of the actual tap regardless, so a value that's gone
  // stale during the brief time this screen is open is a cosmetic risk,
  // not an enforcement one.
  bool _loadingAccess = true;
  bool _hasFullAccess = false;
  int _freePracticeUsedToday = 0;

  @override
  void initState() {
    super.initState();
    _mistakes = _loadMistakes();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    bool hasFullAccess;
    try {
      hasFullAccess = await widget.subscriptionService.hasFullAccess;
    } catch (_) {
      hasFullAccess = false;
    }
    var usedToday = 0;
    if (!hasFullAccess) {
      try {
        usedToday = await widget.storageService.getFreePracticeCountForToday();
      } catch (_) {
        usedToday = 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _hasFullAccess = hasFullAccess;
      _freePracticeUsedToday = usedToday;
      _loadingAccess = false;
    });
  }

  Future<List<ErrorEntry>> _loadMistakes() {
    return widget.storageService.getRecentMistakes(
      widget.spot.topicId,
      widget.spot.errorType,
    );
  }

  void _reloadMistakes() {
    setState(() {
      _mistakes = _loadMistakes();
    });
  }

  Future<void> _practice() {
    return launchPracticeSet(
      context: context,
      topic: widget.topic,
      claudeService: widget.claudeService,
      storageService: widget.storageService,
      analyticsService: widget.analyticsService,
      subscriptionService: widget.subscriptionService,
      setGenerating: (value) {
        if (mounted) setState(() => _generating = value);
      },
      errorPrefix: context.l10n.weakSpotGenerateFailed,
    );
  }

  /// The exhausted-quota row's tap target — same mechanism
  /// `HomeScreen._openWeakSpot` already uses to name what prompted the
  /// paywall, via `PremiumScreen.sourceContext`. Logs the same
  /// "quota → paywall" event `launchPracticeSet`'s own backstop check would
  /// log if this row didn't exist — this is the path that actually fires in
  /// practice, since the row is shown specifically to stop the tap from
  /// ever reaching `launchPracticeSet` in the first place.
  void _openPremium() {
    widget.analyticsService.freePracticeQuotaExhausted();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: AnalyticsService.paywallSourceWeakSpotQuota,
          subscriptionService: widget.subscriptionService,
          sourceContext: humanizeSlug(widget.spot.errorType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruleTitle =
        weakSpotTitle(widget.spot.errorType, widget.topic, context.l10n);
    // A Daily Test-sourced weak spot stores its topic id as the error type
    // (it has no finer classification), so its humanized rule title *is*
    // the topic title. Same rule as WeakSpotCard's topic subtitle: name the
    // topic once, and drop the rule line and the rule half of the recap
    // sentence when they would only repeat it.
    final ruleRepeatsTopic = ruleIsTopic(widget.spot.errorType, widget.topic);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The page's own header stays while the set is generated (final
    // screens A3): the back button in the app bar and the weak spot's
    // title in the page, as below; was a centred app bar title.
    if (_generating) {
      return PageLoading(
        header: Text(
          ruleTitle,
          style: theme.textTheme.headlineMedium
              ?.copyWith(color: colorScheme.onSurface),
        ),
        message: context.l10n.weakSpotPreparing,
      );
    }
    // R03 (UI polish): the topic as an eyebrow, the weak spot as the
    // title, how often and when; the buddy says the rule; the latest
    // mistake inline with its explanation; practice through the ticket
    // (free) or "Practice this" (Premium).
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return BrandScaffold(
      title: const SizedBox.shrink(),
      children: [
        if (!ruleRepeatsTopic) ...[
          Text(
            widget.topic.title(l10n).toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w900)
                .copyWith(color: c.orangeDeep, letterSpacing: 1),
          ),
          const SizedBox(height: 7),
        ],
        Semantics(
          container: true,
          header: true,
          child: Text(
            ruleTitle,
            style: theme.textTheme.headlineMedium?.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          formatFrequencyStat(
              widget.spot.frequency, widget.spot.lastSeen, l10n),
          style: theme.textTheme.labelLarge
              ?.withWeight(FontWeight.w800)
              .copyWith(color: c.muted),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<ErrorEntry>>(
          future: _mistakes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.weakSpotLoadFailed('${snapshot.error}')),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _reloadMistakes,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              );
            }
            final mistakes = snapshot.data ?? const <ErrorEntry>[];
            final latest = mistakes.isEmpty ? null : mistakes.first;
            final rule = latest?.rule ?? widget.spot.latestRule;
            final explanation = latest?.explanation ??
                widget.spot.latestExplanation ??
                (ruleRepeatsTopic
                    ? l10n.weakSpotRecap(ruleTitle)
                    : l10n.weakSpotRecapInTopic(
                        ruleTitle, widget.topic.title(l10n)));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rule != null && rule.trim().isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CompanionView(
                          hero: widget.hero ?? Avatar.fox,
                          mood: CompanionMood.think,
                          size: 64,
                          decorative: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SpeechBubble(
                          text: l10n.weakSpotRemember(_sentence(rule)),
                          pointer: BubblePointer.start,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                SectionTitle(l10n.weakSpotYourMistake),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: lipCard(c, radius: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (latest != null &&
                          InlineMistake.parts(latest) != null) ...[
                        InlineMistake(entry: latest),
                        const SizedBox(height: 10),
                      ] else if (latest != null) ...[
                        MistakeBreakdown(
                          prompt: latest.prompt,
                          userAnswer: latest.userAnswer,
                          blankAnswers: latest.userBlanks,
                          correctedAnswer: latest.correctedAnswer,
                          explanation: null,
                          blankFeedback: latest.blankFeedback,
                          summary: latest.summary,
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        Text(l10n.weakSpotNoHistory,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: c.muted)),
                        const SizedBox(height: 10),
                      ],
                      FeedbackText(
                        explanation,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _PracticeAction(
          loadingAccess: _loadingAccess,
          hasFullAccess: _hasFullAccess,
          freePracticeUsedToday: _freePracticeUsedToday,
          tearing: _tearing,
          onUseTicket: () => setState(() => _tearing = true),
          onTorn: () async {
            await _practice();
            if (mounted) setState(() => _tearing = false);
            _loadAccess();
          },
          onPractice: _practice,
          onLockedTap: _openPremium,
        ),
      ],
    );
  }
}

/// A stored rule as a short sentence: a slug's underscores as spaces, the
/// first letter capitalised, the rest as written.
String _sentence(String rule) {
  final text = rule.replaceAll('_', ' ').trim();
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// The bottom action, across the three states this screen can be in.
/// Deliberately never hidden, even when the free quota is exhausted — this
/// batch's explicit call — there's always something to tap: either into
/// the practice session, or into Premium.
class _PracticeAction extends StatelessWidget {
  final bool loadingAccess;
  final bool hasFullAccess;
  final int freePracticeUsedToday;
  final bool tearing;
  final VoidCallback onUseTicket;
  final VoidCallback onTorn;
  final VoidCallback onPractice;
  final VoidCallback onLockedTap;

  const _PracticeAction({
    required this.loadingAccess,
    required this.hasFullAccess,
    required this.freePracticeUsedToday,
    required this.tearing,
    required this.onUseTicket,
    required this.onTorn,
    required this.onPractice,
    required this.onLockedTap,
  });

  static const ticketKey = ValueKey('weak_spot_ticket');

  @override
  Widget build(BuildContext context) {
    if (loadingAccess) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final remaining =
        StorageService.freeDailyPracticeLimit - freePracticeUsedToday;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!hasFullAccess && remaining <= 0) {
      // Used up today (N3): no free-practice button. The way on is
      // Premium, through the same paywall entry as before, with the same
      // message about today's free practice.
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLockedTap,
              style: forwardButtonStyle(context),
              icon: const Icon(Icons.lock_rounded, size: 17),
              label: Text(context.l10n.weakSpotPracticePremium),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            freePracticeUsedMessage(context.l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }
    // R03: a free user practises through today's ticket (it tears, then
    // the set is made); Premium has "Practice this".
    if (!hasFullAccess) {
      return Ticket(
        key: ticketKey,
        state: tearing ? TicketState.tearing : TicketState.free,
        title: tearing
            ? context.l10n.ticketTearingTitle
            : context.l10n.weakSpotUseTicket,
        subtitle: tearing
            ? context.l10n.ticketTearingBody
            : context.l10n.weakSpotTicketLine,
        onTap: tearing ? null : onUseTicket,
        onTorn: onTorn,
      );
    }
    return PressableButton(
      label: context.l10n.weakSpotPracticeThis,
      tone: ButtonTone.orange,
      haptic: ButtonHaptic.medium,
      trailingIcon: Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_back_rounded
          : Icons.arrow_forward_rounded,
      onPressed: onPractice,
    );
  }
}
