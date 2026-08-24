import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import '../utils/loading_view.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

/// Welcome → Onboarding, shown once on first launch (PRD v2 §4). Neither
/// step needs its own place in the back stack — this just swaps a local
/// `_step` between two plain widgets, no nested Navigator, no route to leave
/// behind once onboarding completes and [onComplete] hands control back to
/// the app shell.
class FirstLaunchFlow extends StatefulWidget {
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final ValueChanged<UserProfile> onComplete;

  const FirstLaunchFlow({
    super.key,
    required this.storageService,
    required this.analyticsService,
    required this.onComplete,
  });

  @override
  State<FirstLaunchFlow> createState() => _FirstLaunchFlowState();
}

enum _Step { welcome, onboarding }

class _FirstLaunchFlowState extends State<FirstLaunchFlow> {
  _Step _step = _Step.welcome;
  bool _saving = false;

  Future<void> _completeOnboarding(UserProfile profile) async {
    setState(() => _saving = true);
    try {
      await widget.storageService.saveUserProfile(profile);
      unawaited(widget.analyticsService.onboardingCompleted());
      widget.onComplete(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, 'Could not save your profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const LoadingView(message: 'Setting things up…');
    }
    switch (_step) {
      case _Step.welcome:
        return WelcomeScreen(
          onGetStarted: () => setState(() => _step = _Step.onboarding),
        );
      case _Step.onboarding:
        return OnboardingScreen(onComplete: _completeOnboarding);
    }
  }
}
