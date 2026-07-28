import 'package:flutter/material.dart';

import '../models.dart';

const List<String> ethiopianMonthNames = <String>[
  'Meskerem',
  'Tikimt',
  'Hidar',
  'Tahsas',
  'Tir',
  'Yekatit',
  'Megabit',
  'Miazia',
  'Ginbot',
  'Sene',
  'Hamle',
  'Nehase',
  'Pagume',
];

bool isEthiopianLeapYear(int year) => year % 4 == 3;

int ethiopianMonthLength(int year, int month) {
  if (month < 1 || month > 13) {
    throw ArgumentError.value(month, 'month', 'Must be between 1 and 13.');
  }
  if (month <= 12) return 30;
  return isEthiopianLeapYear(year) ? 6 : 5;
}

DateTime ethiopianToGregorian(EthiopianDateValue value) {
  final jdn = 1724221 +
      365 * (value.year - 1) +
      value.year ~/ 4 +
      30 * (value.month - 1) +
      value.day -
      1;
  return _jdnToGregorian(jdn);
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
  return 1724221 +
      365 * (year - 1) +
      year ~/ 4 +
      30 * (month - 1) +
      day -
      1;
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

String formatTaskSchedule(ReminderSchedule schedule, BuildContext context) {
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(schedule.time);

  switch (schedule.type) {
    case ReminderType.everyday:
      return 'Every day at $time';
    case ReminderType.specificDate:
      if (schedule.calendarSystem == CalendarSystem.ethiopian &&
          schedule.ethiopianDate != null) {
        final value = schedule.ethiopianDate!;
        return '${ethiopianMonthNames[value.month - 1]} ${value.day}, ${value.year} EC • $time';
      }
      if (schedule.date == null) return time;
      return '${localizations.formatMediumDate(schedule.date!)} • $time';
    case ReminderType.custom:
      final unit = switch (schedule.recurrenceUnit) {
        RecurrenceUnit.weekly => 'Weekly',
        RecurrenceUnit.monthly => 'Monthly',
        RecurrenceUnit.yearly => 'Yearly',
        null => 'Custom',
      };
      return '$unit at $time';
  }
}
