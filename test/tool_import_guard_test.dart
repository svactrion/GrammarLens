import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The screenshot tooling (`tool/screenshots/`: a seeded learner, debug
/// overrides switched on, a `flutter_driver` extension) must never reach
/// the app. Release builds start from `lib/main.dart`, so it is enough
/// that nothing in lib/ imports anything under tool/, or the capture or
/// seed files by name, and that `flutter_driver` stays out of lib/.
void main() {
  test('nothing in lib/ imports tool/ or the screenshot tooling', () {
    final offenders = <String>[];
    final directive = RegExp(r'''^\s*(import|export|part)\s+['"]([^'"]+)['"]''',
        multiLine: true);
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in directive.allMatches(file.readAsStringSync())) {
        final uri = m.group(2)!;
        if (uri.contains('tool/') ||
            uri.contains('capture_app') ||
            uri.contains('capture_driver') ||
            uri.contains('screenshots/seed') ||
            uri.startsWith('package:flutter_driver')) {
          offenders.add('${file.path}: $uri');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the guard sees the screenshot files it protects against', () {
    // If these move, the patterns above must move with them.
    expect(File('tool/screenshots/capture_app.dart').existsSync(), isTrue);
    expect(File('tool/screenshots/seed.dart').existsSync(), isTrue);
  });
}
