import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/ai_consent.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/app_links.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';
import '../utils/content_width.dart';
import '../theme.dart';

/// The one-time permission screen for sending practice answers (Topic
/// Practice and a weak spot's practice alike, every session that goes
/// through `launchPracticeSet`) to a third-party AI provider (App Review
/// guideline 5.1.2(i)). A free user's only practice is a weak spot's, so the
/// screen names practice sessions, never Topic Practice alone. Pops `true` on
/// "Agree and continue", `false` on "Not now", and `null` on the back arrow or
/// a system back gesture; only `true` is a yes, so leaving any other way is a
/// decline.
///
/// Every claim here was checked against the code (docs/build-log.md,
/// 2026-09-21): what goes to Anthropic is `score_answers`' items (question
/// text and the user's typed answer) and nothing else, the proxy never
/// forwards the anonymous device id, and the Daily Test is graded on the
/// device. The screen deliberately says nothing about how the provider stores
/// or uses the data; that is the provider's and the privacy policy's to state.
///
/// Reaching this screen is [ensureAiConsent]'s job; nothing else should push it.
class AiConsentScreen extends StatelessWidget {
  const AiConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // P1: held to the centred content column on an iPad (`ContentWidth`).
    final hPad = ContentWidth.sidePaddingOf(context);
    final body = theme.textTheme.bodyMedium;

    return BrandScaffold(
      title: PageTitle(context.l10n.aiConsentTitle),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const Key('aiConsentBody'),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.aiConsentHeading,
                      style: theme.textTheme.titleLarge
                          ?.withWeight(FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.aiConsentIntro, style: body),
                  _Section(
                    heading: context.l10n.aiConsentSentHeading,
                    text: context.l10n.aiConsentSentBody,
                  ),
                  _Section(
                    heading: context.l10n.aiConsentRecipientHeading,
                    text: context.l10n.aiConsentRecipientBody,
                  ),
                  _Section(
                    heading: context.l10n.aiConsentNeverHeading,
                    text: context.l10n.aiConsentNeverBody,
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.aiConsentPersonalDetails, style: body),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.aiConsentChangeLater,
                    style: body?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: LegalLink(
                      label: context.l10n.commonPrivacyPolicy,
                      url: AppLinks.privacyPolicyUrl,
                      flush: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ConsentFooter(horizontalPadding: hPad),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String heading;
  final String text;

  const _Section({required this.heading, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              heading,
              style: theme.textTheme.titleSmall?.withWeight(FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Pinned below the scrolling text, like Premium's footer, so both answers are
/// reachable at every text size without scrolling to the bottom first.
class _ConsentFooter extends StatelessWidget {
  final double horizontalPadding;

  const _ConsentFooter({required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      key: const Key('aiConsentFooter'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.aiConsentAgree),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.aiConsentNotNow),
              ),
              Text(
                context.l10n.aiConsentNotNowNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// True while a permission check or its screen is in progress, so a second tap
/// on the same entry point cannot stack a second screen (and, downstream, a
/// second practice launch) on top of the first.
bool _promptInProgress = false;

/// Clears the re-entrancy guard; for a test that abandons the screen midway.
@visibleForTesting
void resetAiConsentPromptGuard() => _promptInProgress = false;

/// Returns whether practice answers may be sent to the AI provider,
/// asking the user first if they have not agreed yet.
///
/// Fails closed: if the stored decision cannot be read, the user is asked
/// (unlike the quota checks around it, which fail open). A decline is stored
/// and returns false; the screen is shown again next time. If saving the
/// user's yes fails, this launch still goes ahead (they did agree), and the
/// next one asks again.
///
/// A call that arrives while another is in progress returns false without
/// showing anything.
Future<bool> ensureAiConsent({
  required BuildContext context,
  required StorageService storageService,
  required AnalyticsService analyticsService,
}) async {
  if (_promptInProgress) return false;
  _promptInProgress = true;
  try {
    AiConsent? current;
    try {
      current = await storageService.getAiConsent();
    } catch (_) {
      current = null;
    }
    if (current?.allowsSending ?? false) return true;
    if (!context.mounted) return false;
    return await _askAndRecord(
      context,
      storageService,
      analyticsService,
      AiConsentSource.practiceLaunch,
    );
  } finally {
    _promptInProgress = false;
  }
}

/// Shows the permission screen regardless of any stored decision: Profile →
/// Data uses it when the user switches the permission back on, so turning it
/// on always goes through the same wording. Same result and guard rules as
/// [ensureAiConsent].
Future<bool> requestAiConsent({
  required BuildContext context,
  required StorageService storageService,
  required AnalyticsService analyticsService,
  required AiConsentSource source,
}) async {
  if (_promptInProgress) return false;
  _promptInProgress = true;
  try {
    return await _askAndRecord(
        context, storageService, analyticsService, source);
  } finally {
    _promptInProgress = false;
  }
}

Future<bool> _askAndRecord(
  BuildContext context,
  StorageService storageService,
  AnalyticsService analyticsService,
  AiConsentSource source,
) async {
  final agreed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const AiConsentScreen()),
  );
  final granted = agreed == true;
  unawaited(analyticsService.aiConsentResult(
    outcome: granted ? AiConsentOutcome.granted : AiConsentOutcome.declined,
    source: source,
    consentVersion: AiConsent.currentVersion,
  ));
  try {
    await storageService.setAiConsent(granted: granted);
  } catch (_) {
    // Best effort: see [ensureAiConsent].
  }
  return granted;
}
