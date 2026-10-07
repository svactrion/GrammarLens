import 'package:intl/intl.dart';

/// Two figures for the paywall's annual card, both formatted in the product's
/// currency and the device's locale and both null when they cannot be worked
/// out (no usable price or currency, formatting fails): the paywall then
/// shows nothing rather than a wrong figure.
///
/// [monthlyEquivalent] is the yearly price spread over twelve months
/// ("$4.17"); [twelveMonthsPrice] is twelve months of the monthly plan
/// ("$71.88"), the reference price the saving is measured against.
///
/// Rounded half up in the currency's own minor units, in integers: 49.99 / 12
/// = 4.1658... is "4.17", 59.99 / 12 = 4.9991... is "5.00", and a currency
/// with no decimals (JPY) is rounded to whole units. This is deliberately not
/// RevenueCat's `pricePerMonthString`, which truncates (4.16) and so would
/// disagree with the rounding used everywhere else on the paywall; the
/// number of decimals is [NumberFormat.simpleCurrency]'s, never assumed.
String? monthlyEquivalent({
  required double annualPrice,
  required String currencyCode,
  required String locale,
}) =>
    _format(
      price: annualPrice,
      currencyCode: currencyCode,
      locale: locale,
      // Half up: floor(minor / 12 + 1/2).
      minorUnits: (minor) => (minor + 6) ~/ 12,
    );

/// Twelve months of the monthly plan, exact in minor units (5.99 -> 71.88).
String? twelveMonthsPrice({
  required double monthlyPrice,
  required String currencyCode,
  required String locale,
}) =>
    _format(
      price: monthlyPrice,
      currencyCode: currencyCode,
      locale: locale,
      minorUnits: (minor) => minor * 12,
    );

String? _format({
  required double price,
  required String currencyCode,
  required String locale,
  required int Function(int minor) minorUnits,
}) {
  if (!price.isFinite || price <= 0) return null;
  if (currencyCode.trim().isEmpty) return null;
  try {
    final resolved = Intl.verifiedLocale(
      Intl.canonicalizedLocale(locale),
      NumberFormat.localeExists,
      onFailure: (_) => 'en_US',
    );
    final format = NumberFormat.simpleCurrency(
      locale: resolved,
      name: currencyCode.trim().toUpperCase(),
    );
    final digits = format.decimalDigits ?? 2;
    var scale = 1;
    for (var i = 0; i < digits; i++) {
      scale *= 10;
    }
    final result = minorUnits((price * scale).round());
    if (result <= 0) return null;
    // result / scale is the nearest double to a value that already has
    // [digits] decimals, so the formatter has nothing left to round.
    final text = format.format(result / scale);
    return text.trim().isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}
