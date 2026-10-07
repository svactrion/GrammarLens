import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/subscription_service.dart';
import 'utils/app_orientation.dart';
import 'utils/early_error_reporting.dart';
import 'widgets/launch_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so no error raised before Firebase is ready goes unreported.
  final earlyErrors = EarlyErrorReporting()..install();

  // sqflite has no platform-channel implementation on web; point the global
  // factory at the WASM/IndexedDB-backed one instead, or every DB call
  // (writes in ResultsScreen, reads in ReviewScreen) throws.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await lockAppOrientation();
  // The splash draws at once; Firebase and RevenueCat start with it, and
  // the app itself is built only after both have finished (LaunchGate), so
  // nothing in it can reach them unconfigured.
  runApp(LaunchGate(
    initialize: () => _initializeLaunchServices(earlyErrors),
    app: (_) => const GrammarLensApp(),
  ));
}

/// Firebase and RevenueCat, in parallel: neither depends on the other.
/// Outside release builds, logs how long each took (the launch splash
/// must not add wait time; see docs/1.1.0-design-side-tracks.md).
Future<void> _initializeLaunchServices(EarlyErrorReporting earlyErrors) async {
  final total = Stopwatch()..start();
  Future<Duration> timed(Future<void> Function() work) async {
    final watch = Stopwatch()..start();
    await work();
    return watch.elapsed;
  }

  final durations = await Future.wait([
    timed(() => _initializeFirebase(earlyErrors)),
    timed(SubscriptionService().initialize),
  ]);
  if (!kReleaseMode) {
    debugPrint('[launch] firebase ${durations[0].inMilliseconds} ms, '
        'revenuecat ${durations[1].inMilliseconds} ms, '
        'total ${total.elapsedMilliseconds} ms');
  }
}

/// Pre-launch checklist item (PRD v2 §10.1): analytics + crash reporting,
/// anonymous/device-based, no account involved (see AnalyticsService's doc
/// comment). Connected via `flutterfire configure` to the `grammarlens-18d47`
/// Firebase project, using the generated `DefaultFirebaseOptions.currentPlatform`
/// rather than relying solely on the native config files.
///
/// If initialization still fails for some reason (misconfigured project,
/// no network, platform quirk), it's caught below — the app runs exactly as
/// it does today, just without analytics/crash reporting, rather than
/// failing to launch over it.
///
/// Errors raised before this finishes are kept by [earlyErrors] and sent to
/// Crashlytics once it is ready.
Future<void> _initializeFirebase(EarlyErrorReporting earlyErrors) async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Firebase failed to initialize — analytics and crash reporting simply
    // stay off; nothing else about the app depends on them.
    earlyErrors.abandon();
    return;
  }
  // P11: a debug or profile build collects nothing, Firebase's automatic
  // events included, unless built with ANALYTICS_DEBUG_EVENTS=true; a
  // release build sets it on (Firebase's default), which also undoes a
  // switch left off on a device by a debug build. Crashlytics' own
  // collection switch is separate and not changed here.
  try {
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(AnalyticsGate.enabled);
  } catch (_) {
    // Best effort, like every analytics call.
  }
  earlyErrors.handOver(
    onFlutterError: FirebaseCrashlytics.instance.recordFlutterFatalError,
    onPlatformError: (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    },
  );
}
