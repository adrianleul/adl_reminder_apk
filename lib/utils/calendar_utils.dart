import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import 'ethiopian_calendar.dart';

export 'ethiopian_calendar.dart';

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

const List<String> ethiopianMonthNamesAmharic = <String>[
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሣሥ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];

/// Weekdays in display order (Sunday first, as on Ethiopian calendars), using
/// [DateTime.weekday] numbering.
const List<int> weekdayDisplayOrder = <int>[
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

const Map<int, String> _weekdaysEnglish = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

const Map<int, String> _weekdaysAmharic = {
  DateTime.monday: 'ሰኞ',
  DateTime.tuesday: 'ማክሰኞ',
  DateTime.wednesday: 'ረቡዕ',
  DateTime.thursday: 'ሐሙስ',
  DateTime.friday: 'ዓርብ',
  DateTime.saturday: 'ቅዳሜ',
  DateTime.sunday: 'እሑድ',
};

String weekdayName(AppLocalizations l10n, int weekday) =>
    (l10n.isAmharic ? _weekdaysAmharic : _weekdaysEnglish)[weekday]!;

String ethiopianMonthName(AppLocalizations l10n, int month) => (l10n.isAmharic
    ? ethiopianMonthNamesAmharic
    : ethiopianMonthNames)[month - 1];

String formatEthiopianDate(AppLocalizations l10n, EthiopianDateValue value) =>
    '${ethiopianMonthName(l10n, value.month)} ${value.day}, '
    '${value.year} ${l10n.text('ecSuffix')}';

/// Formats a Gregorian date in the calendar the user picked for the task.
String formatCalendarDate(
  BuildContext context,
  DateTime date,
  CalendarSystem calendar,
) {
  if (calendar == CalendarSystem.ethiopian) {
    return formatEthiopianDate(context.l10n, gregorianToEthiopian(date));
  }
  return MaterialLocalizations.of(context).formatMediumDate(date);
}

String formatTaskSchedule(ReminderSchedule schedule, BuildContext context) {
  final l10n = context.l10n;
  final time = MaterialLocalizations.of(context).formatTimeOfDay(schedule.time);
  String date(DateTime value) =>
      formatCalendarDate(context, value, schedule.calendarSystem);

  switch (schedule.type) {
    case ReminderType.everyday:
      return l10n.text('everyDayAt', {'time': time});
    case ReminderType.specificDate:
      if (schedule.date == null) return time;
      return l10n.text('dateAtTime', {
        'date': date(schedule.date!),
        'time': time,
      });
    case ReminderType.dateRange:
      if (schedule.date == null || schedule.endDate == null) return time;
      return l10n.text('rangeSchedule', {
        'start': date(schedule.date!),
        'end': date(schedule.endDate!),
        'time': time,
      });
    case ReminderType.custom:
      final start = schedule.date;
      switch (schedule.recurrenceUnit) {
        case RecurrenceUnit.weekly:
          final days = [
            for (final day in weekdayDisplayOrder)
              if (schedule.weekdays.contains(day)) weekdayName(l10n, day),
          ].join(', ');
          return l10n.text('weeklyOn', {'days': days, 'time': time});
        case RecurrenceUnit.monthly:
          if (start == null) return time;
          final ethiopian = schedule.calendarSystem == CalendarSystem.ethiopian;
          return l10n.text(ethiopian ? 'monthlyOnEthiopian' : 'monthlyOn', {
            'day': ethiopian ? gregorianToEthiopian(start).day : start.day,
            'time': time,
          });
        case RecurrenceUnit.yearly:
          if (start == null) return time;
          final String day;
          if (schedule.calendarSystem == CalendarSystem.ethiopian) {
            final value = gregorianToEthiopian(start);
            day = '${ethiopianMonthName(l10n, value.month)} ${value.day}';
          } else {
            day = MaterialLocalizations.of(context).formatShortMonthDay(start);
          }
          return l10n.text('yearlyOn', {'date': day, 'time': time});
        case null:
          return time;
      }
  }
}

/// Days, hours and minutes until a reminder fires, rounded up to the minute
/// like a phone alarm (4 min 10 s counts as 5 minutes).
({int days, int hours, int minutes}) countdownParts(Duration remaining) {
  final totalMinutes = remaining.isNegative
      ? 0
      : (remaining.inSeconds + 59) ~/ 60;
  return (
    days: totalMinutes ~/ (24 * 60),
    hours: totalMinutes % (24 * 60) ~/ 60,
    minutes: totalMinutes % 60,
  );
}

String unitLabel(AppLocalizations l10n, int count, String unit) =>
    l10n.text(count == 1 ? 'unit$unit' : 'unit${unit}s');

/// Time left until a reminder fires: "2 days, 3 hours, 5 minutes" from one
/// day on, "3 hours, 5 minutes" under a day, and "5 minutes" under an hour.
/// Units that are zero are left out.
String formatTimeUntil(AppLocalizations l10n, Duration remaining) {
  final parts = countdownParts(remaining);
  if (parts.days == 0 && parts.hours == 0 && parts.minutes == 0) {
    return l10n.text('lessThanMinute');
  }
  String unit(int count, String one, String many) =>
      l10n.text(count == 1 ? one : many, {'count': count});

  return [
    if (parts.days > 0) unit(parts.days, 'durationDay', 'durationDays'),
    if (parts.hours > 0) unit(parts.hours, 'durationHour', 'durationHours'),
    if (parts.minutes > 0)
      unit(parts.minutes, 'durationMinute', 'durationMinutes'),
  ].join(l10n.text('listSeparator'));
}

/// Short form for chips and the Next up card: "2d 3h", "7h 15m", "45 min".
String formatCompactTimeUntil(AppLocalizations l10n, Duration remaining) {
  final parts = countdownParts(remaining);
  if (parts.days > 0) {
    return l10n.text('compactDays', {'d': parts.days, 'h': parts.hours});
  }
  if (parts.hours > 0) {
    return l10n.text('compactHours', {'h': parts.hours, 'm': parts.minutes});
  }
  return l10n.text('compactMinutes', {
    'm': parts.minutes < 1 ? 1 : parts.minutes,
  });
}
