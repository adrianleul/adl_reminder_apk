/// Pure Ethiopian <-> Gregorian calendar conversion, free of Flutter imports so
/// it can be shared by models, services and background isolates.
library;

class EthiopianDateValue {
  const EthiopianDateValue({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is EthiopianDateValue &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'EthiopianDateValue($year-$month-$day)';
}

bool isEthiopianLeapYear(int year) => year % 4 == 3;

int ethiopianMonthLength(int year, int month) {
  if (month < 1 || month > 13) {
    throw ArgumentError.value(month, 'month', 'Must be between 1 and 13.');
  }
  if (month <= 12) return 30;
  return isEthiopianLeapYear(year) ? 6 : 5;
}

DateTime ethiopianToGregorian(EthiopianDateValue value) {
  return _jdnToGregorian(_ethiopianToJdn(value.year, value.month, value.day));
}

EthiopianDateValue gregorianToEthiopian(DateTime date) {
  final jdn = _gregorianToJdn(date.year, date.month, date.day);
  var year = date.year - 8;

  while (_ethiopianToJdn(year + 1, 1, 1) <= jdn) {
    year++;
  }
  while (_ethiopianToJdn(year, 1, 1) > jdn) {
    year--;
  }

  final dayOfYear = jdn - _ethiopianToJdn(year, 1, 1);
  final month = dayOfYear ~/ 30 + 1;
  final day = dayOfYear % 30 + 1;
  return EthiopianDateValue(year: year, month: month, day: day);
}

int _ethiopianToJdn(int year, int month, int day) {
  return 1724221 + 365 * (year - 1) + year ~/ 4 + 30 * (month - 1) + day - 1;
}

int _gregorianToJdn(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
}

DateTime _jdnToGregorian(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return DateTime(year, month, day);
}
