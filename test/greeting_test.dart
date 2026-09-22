import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/greeting.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 1, 1, hour, minute);

  test('04:59 is still evening, 05:00 becomes morning', () {
    expect(timeOfDayGreeting(at(4, 59)), 'Good evening');
    expect(timeOfDayGreeting(at(5, 0)), 'Good morning');
  });

  test('11:59 is still morning, 12:00 becomes afternoon', () {
    expect(timeOfDayGreeting(at(11, 59)), 'Good morning');
    expect(timeOfDayGreeting(at(12, 0)), 'Good afternoon');
  });

  test('17:59 is still afternoon, 18:00 becomes evening', () {
    expect(timeOfDayGreeting(at(17, 59)), 'Good afternoon');
    expect(timeOfDayGreeting(at(18, 0)), 'Good evening');
  });

  test(
      '23:59 is still evening, 00:00 (past midnight) is still evening too '
      "— there is no fourth slice, and never 'Good night'", () {
    expect(timeOfDayGreeting(at(23, 59)), 'Good evening');
    expect(timeOfDayGreeting(DateTime(2026, 1, 2, 0, 0)), 'Good evening');
  });

  test('never returns "Good night" for any hour of the day', () {
    for (var hour = 0; hour < 24; hour++) {
      expect(timeOfDayGreeting(at(hour, 0)), isNot(contains('night')));
    }
  });

  test('covers every hour with exactly one of the three greetings', () {
    const allowed = {'Good morning', 'Good afternoon', 'Good evening'};
    for (var hour = 0; hour < 24; hour++) {
      expect(allowed, contains(timeOfDayGreeting(at(hour, 0))));
    }
  });
}
