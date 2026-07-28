import 'package:adl_reminder/models.dart';
import 'package:adl_reminder/utils/calendar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ethiopian calendar conversion', () {
    test('2016 Meskerem 1 converts to September 12, 2023', () {
      final result = ethiopianToGregorian(
        const EthiopianDateValue(year: 2016, month: 1, day: 1),
      );
      expect(result, DateTime(2023, 9, 12));
    });

    test('2017 Meskerem 1 converts to September 11, 2024', () {
      final result = ethiopianToGregorian(
        const EthiopianDateValue(year: 2017, month: 1, day: 1),
      );
      expect(result, DateTime(2024, 9, 11));
    });

    test('Gregorian conversion round-trips', () {
      final input = DateTime(2026, 7, 29);
      final ethiopian = gregorianToEthiopian(input);
      final result = ethiopianToGregorian(ethiopian);
      expect(result, DateTime(2026, 7, 29));
    });

    test('Ethiopian leap year Pagume has six days', () {
      expect(ethiopianMonthLength(2015, 13), 6);
      expect(ethiopianMonthLength(2016, 13), 5);
    });
  });
}
