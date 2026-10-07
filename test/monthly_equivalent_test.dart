import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/utils/monthly_equivalent.dart';

String? perMonth(double price, String code, [String locale = 'en_US']) =>
    monthlyEquivalent(annualPrice: price, currencyCode: code, locale: locale);

String? twelve(double price, String code, [String locale = 'en_US']) =>
    twelveMonthsPrice(monthlyPrice: price, currencyCode: code, locale: locale);

void main() {
  group('monthlyEquivalent', () {
    test('rounds half up in minor units, not truncated', () {
      expect(perMonth(49.99, 'USD'), '\$4.17'); // 4.1658...
      expect(perMonth(59.99, 'USD'), '\$5.00'); // 4.9991...
      expect(perMonth(89.99, 'USD'), '\$7.50'); // 7.4991...
      expect(perMonth(39.99, 'EUR'), '€3.33'); // 3.3325
    });

    test('an exact half goes up: 0.06 / 12 per cent is decided in integers',
        () {
      // 50.10 / 12 = 4.175 exactly: half up is 4.18 (a double's 4.175 is
      // 4.17499... and would round down).
      expect(perMonth(50.10, 'USD'), '\$4.18');
      expect(perMonth(12.00, 'USD'), '\$1.00');
    });

    test('a currency with no decimals is rounded to whole units', () {
      expect(perMonth(6000, 'JPY'), '¥500');
      expect(perMonth(5990, 'JPY'), '¥499'); // 499.17
      expect(perMonth(5994, 'JPY'), '¥500'); // 499.5 -> up
    });

    test('a currency with three decimals keeps them', () {
      expect(perMonth(15.999, 'KWD'), contains('1.333'));
    });

    test('follows the locale\'s symbol position and separators', () {
      expect(perMonth(49.99, 'EUR', 'de_DE'), '4,17 €');
    });

    test('nothing for a price or currency it cannot use', () {
      expect(perMonth(0, 'USD'), isNull);
      expect(perMonth(-5, 'USD'), isNull);
      expect(perMonth(double.nan, 'USD'), isNull);
      expect(perMonth(double.infinity, 'USD'), isNull);
      expect(perMonth(49.99, ''), isNull);
      expect(perMonth(49.99, '  '), isNull);
      // Rounds to nothing.
      expect(perMonth(0.001, 'USD'), isNull);
    });

    test('an unknown locale still formats, an odd currency code does not throw',
        () {
      expect(perMonth(49.99, 'USD', 'xx_YY'), isNotNull);
      expect(() => perMonth(49.99, 'NOTACODE'), returnsNormally);
    });
  });

  group('twelveMonthsPrice', () {
    test('is twelve exact payments', () {
      expect(twelve(5.99, 'USD'), '\$71.88');
      expect(twelve(9.99, 'USD'), '\$119.88');
      expect(twelve(4.99, 'EUR'), '€59.88');
      expect(twelve(500, 'JPY'), '¥6,000');
    });

    test('nothing without a usable price or currency', () {
      expect(twelve(0, 'USD'), isNull);
      expect(twelve(5.99, ''), isNull);
    });
  });
}
