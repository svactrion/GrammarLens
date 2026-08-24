import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite has no platform-channel implementation on web; point the global
  // factory at the WASM/IndexedDB-backed one instead, or every DB call
  // (writes in ResultsScreen, reads in ReviewScreen) throws.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await _initializeFirebase();
  runApp(const GrammarLensApp());
}

/// Pre-launch checklist item (PRD v2 §10.1): analytics + crash reporting,
/// anonymous/device-based, no account involved (see AnalyticsService's doc
/// comment). This calls the classic `Firebase.initializeApp()` with no
/// explicit `options` — it relies on native platform config files
/// (`ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`)
/// rather than a generated `firebase_options.dart`, because no Firebase
/// project is connected yet as of this commit.
///
/// **To actually connect one:** run `flutterfire configure` (needs the
/// Firebase CLI and your own Google/Firebase account — this step can't be
/// done from here). That command both drops the native config files above
/// *and* generates `lib/firebase_options.dart`; once it exists, switch this
/// call to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
/// for the platform-aware, non-file-based setup FlutterFire recommends.
///
/// Until a project is connected, this throws (no config files present) and
/// is caught below — the app runs exactly as it does today, just without
/// analytics/crash reporting, rather than failing to launch over it.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // No Firebase project connected yet — see the comment above. Analytics
    // and crash reporting simply stay off; nothing else about the app
    // depends on them.
  }
}
