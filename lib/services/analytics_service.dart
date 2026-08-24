import 'package:firebase_analytics/firebase_analytics.dart';

/// Minimal local event logging (PRD v2 §9's "measurement approach for
/// launch") plus crash reporting, both anonymous and device-based — no
/// account/login involved, so this doesn't touch the guest-first identity
/// model (PRD v2 §5). Three custom events only, matching what §9 actually
/// needs to answer at launch: onboarding completion, which mode people
/// pick, and session completion.
///
/// Every method here is a best-effort no-op until a Firebase project is
/// actually connected (`flutterfire configure` — see main.dart's comment on
/// [initializeFirebase]) — analytics is a nice-to-have signal, not
/// something that should ever be able to crash or block the app it's
/// instrumenting.
class AnalyticsService {
  /// Practice mode identifiers for the `mode_selected` event — matches the
  /// four entries on Home (PRD v2 §4): the three practice-mode cards plus
  /// the Early Access banner, since knowing what people tap there is
  /// exactly the kind of pre-launch interest signal analytics exists for.
  static const String modeTopic = 'topic';
  static const String modeStreak = 'streak';
  static const String modeVoice = 'voice';
  static const String modeEarlyAccess = 'early_access';

  Future<void> onboardingCompleted() {
    return _logEvent('onboarding_completed');
  }

  Future<void> modeSelected(String mode) {
    return _logEvent('mode_selected', {'mode': mode});
  }

  Future<void> sessionCompleted({
    required String topicId,
    required int questionCount,
  }) {
    return _logEvent('session_completed', {
      'topic_id': topicId,
      'question_count': questionCount,
    });
  }

  Future<void> _logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await FirebaseAnalytics.instance
          .logEvent(name: name, parameters: parameters);
    } catch (_) {
      // No Firebase project connected yet, or a transient failure — never
      // let instrumentation take down the feature it's measuring.
    }
  }
}
