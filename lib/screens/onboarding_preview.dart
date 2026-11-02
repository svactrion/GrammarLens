import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import 'welcome_screen.dart';

/// The debug panel's "Preview onboarding" (debug and profile builds; 1.4.0
/// B5, owner 2026-11-02): the real Welcome screen and the two onboarding
/// steps, the "Your data & AI" sheet included, in the interface language,
/// so each translation can be read on a device as it lands.
///
/// Writes nothing, by construction: the preview is given no storage or
/// analytics service, and it drops what onboarding hands back (the name,
/// the avatar and the goal); no profile is saved, no day-0 set is seeded,
/// no event or user property is sent, the first-launch state is untouched.
/// [FirstLaunchFlow] is what does those things, and it is not used here.
/// Finishing ("Start my first test" or "Skip goal & start") or leaving (the
/// back gesture) pops back to where the app was.
class OnboardingPreview extends StatefulWidget {
  const OnboardingPreview({super.key});

  @override
  State<OnboardingPreview> createState() => _OnboardingPreviewState();
}

class _OnboardingPreviewState extends State<OnboardingPreview> {
  bool _onboarding = false;

  @override
  Widget build(BuildContext context) => _onboarding
      ? OnboardingScreen(
          // The profile onboarding builds is discarded.
          onComplete: (_) => Navigator.of(context).pop(),
        )
      : WelcomeScreen(onGetStarted: () => setState(() => _onboarding = true));
}
