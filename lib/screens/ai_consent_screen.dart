import 'package:flutter/material.dart';

import '../models/ai_consent.dart';
import '../services/storage_service.dart';
import '../utils/app_links.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';

/// The one-time permission screen for sending Topic Practice answers to a
/// third-party AI provider (App Review guideline 5.1.2(i)). Pops `true` on
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
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final body = theme.textTheme.bodyMedium;

    return BrandScaffold(
      title: const PageTitle('Topic Practice'),
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
                      'Feedback on your answers',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topic Practice uses an AI service to check your answers '
                    'and explain what to fix.',
                    style: body,
                  ),
                  const _Section(
                    heading: 'What is sent',
                    text: 'The answers you type, together with the question '
                        'each one responds to. This happens when you finish a '
                        'practice session.',
                  ),
                  const _Section(
                    heading: 'Who receives it',
                    text: 'Anthropic, the company that makes Claude. Your '
                        'answers go through GrammarLens\'s server to '
                        'Anthropic\'s Claude model, which writes your '
                        'feedback.',
                  ),
                  const _Section(
                    heading: 'What is never sent',
                    text: 'Your name, your learning goal or your avatar. Daily '
                        'Test answers stay on your device.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please don\'t type personal details such as full names, '
                    'addresses or contact information into your answers.',
                    style: body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You can change this any time in Profile → Data.',
                    style: body?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: LegalLink(
                      label: 'Privacy Policy',
                      url: AppLinks.privacyPolicyUrl,
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
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
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
                  child: const Text('Agree and continue'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              Text(
                'Not now: you can still take the Daily Test.',
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

/// Returns whether Topic Practice answers may be sent to the AI provider,
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

    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AiConsentScreen()),
    );
    final granted = agreed == true;
    try {
      await storageService.setAiConsent(granted: granted);
    } catch (_) {
      // Best effort: see the doc comment above.
    }
    return granted;
  } finally {
    _promptInProgress = false;
  }
}
