// UI polish board gallery: the host side of `flutter drive`. Asks the
// gallery app (`gallery_app.dart`) for each board and saves the simulator's
// screen with `xcrun simctl io <udid> screenshot`.
//
// Environment (set by capture.sh): CAPTURE_UDID, the simulator;
// CAPTURE_OUT, the folder for the PNGs; CAPTURE_BOARDS, a comma-separated
// list of board ids (default: every board the app lists). An id may end in
// ":dark" for the dark theme.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Boards that need longer than the default to reach the frame worth
/// comparing (an entrance, a fill, a count-up).
const _settleMs = <String, int>{
  'V05b-GettingReady': 2600,
  'V10-Results': 3200,
  'V12-Climb': 2500,
  'R04-MonthCard': 3500,
  'V11-Badge': 2200,
  'R05-Medal': 2200,
  'PW05-PremiumOn': 2200,
  'V16b-TicketTear': 420,
};

Future<void> main() async {
  final udid = Platform.environment['CAPTURE_UDID']!;
  final out = Platform.environment['CAPTURE_OUT']!;
  Directory(out).createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  try {
    final listed = (await driver.requestData('boards')).split(',');
    final wanted = Platform.environment['CAPTURE_BOARDS'];
    final boards = wanted == null || wanted.isEmpty
        ? listed
        : wanted.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final board in boards) {
      final reply = await driver.requestData('board:$board');
      if (reply != 'ok') {
        stdout.writeln('unknown board $board');
        continue;
      }
      final id = board.split(':').first;
      await Future<void>.delayed(
          Duration(milliseconds: _settleMs[id] ?? 1600));
      final file = '$out/${board.replaceAll(':', '-')}.png';
      final r = await Process.run(
          'xcrun', ['simctl', 'io', udid, 'screenshot', '--type=png', file]);
      if (r.exitCode != 0) {
        stdout.writeln('screenshot failed for $board: ${r.stderr}');
      } else {
        stdout.writeln('captured $file');
      }
    }
  } finally {
    await driver.close();
  }
}
