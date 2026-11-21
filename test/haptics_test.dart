import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/haptics.dart';

/// SPEC §3.4: the haptic map over HapticFeedback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records by name while a test log is set', () {
    HapticMap.log = [];
    HapticMap.selection();
    HapticMap.light();
    HapticMap.medium();
    HapticMap.success();
    HapticMap.warning();
    HapticMap.heavy();
    expect(HapticMap.log,
        ['selection', 'light', 'medium', 'success', 'warning', 'heavy']);
  });

  testWidgets('success is medium then light 90 ms later; warning two lights',
      (tester) async {
    HapticMap.log = null;
    addTearDown(() => HapticMap.log = []);
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
    HapticMap.success();
    expect(calls, ['HapticFeedbackType.mediumImpact']);
    await tester.pump(const Duration(milliseconds: 95));
    expect(calls,
        ['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.lightImpact']);
    calls.clear();
    HapticMap.warning();
    await tester.pump(const Duration(milliseconds: 85));
    expect(calls,
        ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.lightImpact']);
    calls.clear();
    HapticMap.heavy();
    expect(calls, ['HapticFeedbackType.heavyImpact']);
  });
}
