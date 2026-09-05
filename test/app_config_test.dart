import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isConfigured is true only when both proxyBaseUrl and appToken are set', () {
      expect(
        AppConfig.isConfigured,
        AppConfig.proxyBaseUrl.isNotEmpty && AppConfig.appToken.isNotEmpty,
      );
    });

    test('proxyBaseUrl/appToken are empty when no --dart-define is passed', () {
      // This test suite runs without --dart-define=PROXY_BASE_URL=...
      // /APP_TOKEN=..., so both consts should fall back to the empty
      // default rather than throwing or reading some ambient environment
      // variable.
      expect(AppConfig.proxyBaseUrl, isEmpty);
      expect(AppConfig.appToken, isEmpty);
      expect(AppConfig.isConfigured, isFalse);
    });
  });
}
