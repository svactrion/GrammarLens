import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite has no platform-channel implementation on web; point the global
  // factory at the WASM/IndexedDB-backed one instead, or every DB call
  // (writes in ResultsScreen, reads in ReviewScreen) throws.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await _initializeFirebase();
  await SubscriptionService().initialize();
  runApp(const GrammarLensApp());
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
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase failed to initialize — analytics and crash reporting simply
    // stay off; nothing else about the app depends on them.
  }
}
