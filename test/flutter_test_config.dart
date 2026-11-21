import 'dart:async';

import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/utils/haptics.dart';

/// Runs before every test file in test/ (UI polish B1).
///
/// - The ambient loops (breathe, float, shine, pulse) are off, so
///   `pumpAndSettle` settles; a test of a loop sets
///   `AppMotion.loopsEnabled = true` itself.
/// - Haptics are recorded in `HapticMap.log` instead of reaching the
///   platform, so the delayed second tap of success / warning leaves no
///   pending timer behind.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppMotion.loopsEnabled = false;
  HapticMap.log = <String>[];
  await testMain();
}
