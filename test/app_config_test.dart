import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isConfigured tracks whether anthropicApiKey is set', () {
      expect(AppConfig.isConfigured, AppConfig.anthropicApiKey.isNotEmpty);
    });

    test('anthropicApiKey is empty when no --dart-define is passed', () {
      // This test suite runs without --dart-define=ANTHROPIC_API_KEY=...,
      // so the const should fall back to the empty default rather than
      // throwing or reading some ambient environment variable.
      expect(AppConfig.anthropicApiKey, isEmpty);
      expect(AppConfig.isConfigured, isFalse);
    });
  });
}
