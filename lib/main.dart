import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';

void main() {
  // sqflite has no platform-channel implementation on web; point the global
  // factory at the WASM/IndexedDB-backed one instead, or every DB call
  // (writes in ResultsScreen, reads in ReviewScreen) throws.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const GrammarLensApp());
}
