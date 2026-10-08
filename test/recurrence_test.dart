import 'package:adl_reminder/models.dart';
import 'package:adl_reminder/services/notification_service.dart';
import 'package:adl_reminder/utils/calendar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _nine = TimeOfDay(hour: 9, minute: 0);

ReminderSchedule _custom(
  RecurrenceUnit unit,
  DateTime start, {
  CalendarSystem calendar = CalendarSystem.gregorian,
  Set<int> weekdays = const {},
}) => ReminderSchedule(
  type: ReminderType.custom,
  calendarSystem: calendar,
  time: _nine,
  date: start,
  recurrenceUnit: unit,
  weekdays: weekdays,
);

void main() {
  group('monthly recurrence', () {
    test('day 31 falls back to the last day of shorter months', () {
      final schedule = _custom(RecurrenceUnit.monthly, DateTime(2026, 1, 31));
      expect(schedule.occurrencesAfter(DateTime(2026, 1, 1), limit: 4), [
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 2, 28, 9),
        DateTime(2026, 3, 31, 9),
        DateTime(2026, 4, 30, 9),
      ]);
    });

    test('does not occur before its start date', () {
      final schedule = _custom(RecurrenceUnit.monthly, DateTime(2026, 5, 10));
      expect(schedule.occursOn(DateTime(2026, 4, 10)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 5, 10)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 6, 10)), isTrue);
    });

    test('Ethiopian monthly follows Ethiopian months', () {
      // Meskerem 5, 2019 EC.
      final start = ethiopianToGregorian(
        const EthiopianDateValue(year: 2019, month: 1, day: 5),
      );
      final schedule = _custom(
        RecurrenceUnit.monthly,
        start,
        calendar: CalendarSystem.ethiopian,
      );
      // After the first occurrence (start day, 09:00).
      final next = schedule.occurrencesAfter(
        start.add(const Duration(hours: 10)),
        limit: 2,
      );
      expect(next.map((date) => gregorianToEthiopian(date)), const [
        EthiopianDateValue(year: 2019, month: 2, day: 5),
        EthiopianDateValue(year: 2019, month: 3, day: 5),
      ]);
    });

    test('Ethiopian day 30 still fires in the short month of Pagume', () {
      final start = ethiopianToGregorian(
        const EthiopianDateValue(year: 2018, month: 12, day: 30),
      );
      final schedule = _custom(
        RecurrenceUnit.monthly,
        start,
        calendar: CalendarSystem.ethiopian,
      );
      final next = schedule.nextOccurrenceAfter(
        start.add(const Duration(days: 1)),
      );
      // 2018 is not a leap year (2018 % 4 != 3): Pagume has 5 days.
      expect(
        gregorianToEthiopian(next!),
        const EthiopianDateValue(year: 2018, month: 13, day: 5),
      );
    });
  });

  group('yearly recurrence', () {
    test('Ethiopian yearly keeps the Ethiopian date', () {
      final start = ethiopianToGregorian(
        const EthiopianDateValue(year: 2018, month: 4, day: 29),
      );
      final schedule = _custom(
        RecurrenceUnit.yearly,
        start,
        calendar: CalendarSystem.ethiopian,
      );
      final next = schedule.nextOccurrenceAfter(
        start.add(const Duration(days: 1)),
      );
      expect(
        gregorianToEthiopian(next!),
        const EthiopianDateValue(year: 2019, month: 4, day: 29),
      );
    });

    test('Gregorian February 29 falls back to February 28', () {
      final schedule = _custom(RecurrenceUnit.yearly, DateTime(2028, 2, 29));
      expect(
        schedule.nextOccurrenceAfter(DateTime(2028, 3, 1)),
        DateTime(2029, 2, 28, 9),
      );
    });
  });

  group('weekly recurrence', () {
    test('respects the start date', () {
      final schedule = _custom(
        RecurrenceUnit.weekly,
        DateTime(2026, 10, 14), // a Wednesday
        weekdays: {DateTime.monday},
      );
      expect(schedule.occursOn(DateTime(2026, 10, 12)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 10, 19)), isTrue);
    });
  });

  test('a past one-time reminder has no next occurrence', () {
    final schedule = ReminderSchedule(
      type: ReminderType.specificDate,
      calendarSystem: CalendarSystem.gregorian,
      time: _nine,
      date: DateTime(2026, 1, 1),
    );
    expect(schedule.nextOccurrenceAfter(DateTime(2026, 1, 2)), isNull);
    expect(
      schedule.nextOccurrenceAfter(DateTime(2025, 12, 31)),
      DateTime(2026, 1, 1, 9),
    );
  });

  group('planOccurrences', () {
    final now = DateTime(2026, 10, 7, 12); // Wednesday noon

    test('daily repeats on the platform from the next 9:00', () {
      final plan = planOccurrences(
        const ReminderSchedule(
          type: ReminderType.everyday,
          calendarSystem: CalendarSystem.gregorian,
          time: _nine,
        ),
        now,
      );
      expect(plan, hasLength(1));
      expect(plan.single.at, DateTime(2026, 10, 8, 9));
      expect(plan.single.repeat, DateTimeComponents.time);
    });

    test('weekly schedules one repeating reminder per weekday', () {
      final plan = planOccurrences(
        _custom(
          RecurrenceUnit.weekly,
          DateTime(2026, 10, 1),
          weekdays: {DateTime.monday, DateTime.friday},
        ),
        now,
      );
      expect(plan.map((item) => item.at), [
        DateTime(2026, 10, 9, 9),
        DateTime(2026, 10, 12, 9),
      ]);
      expect(
        plan.every(
          (item) => item.repeat == DateTimeComponents.dayOfWeekAndTime,
        ),
        isTrue,
      );
    });

    test('date ranges are capped to a rolling window', () {
      final plan = planOccurrences(
        ReminderSchedule(
          type: ReminderType.dateRange,
          calendarSystem: CalendarSystem.gregorian,
          time: _nine,
          date: DateTime(2026, 10, 1),
          endDate: DateTime(2027, 10, 1),
        ),
        now,
      );
      expect(plan, hasLength(21));
      expect(plan.first.at, DateTime(2026, 10, 8, 9));
      expect(plan.every((item) => item.repeat == null), isTrue);
    });

    test('monthly reminders are explicit dates, not platform repeats', () {
      final plan = planOccurrences(
        _custom(RecurrenceUnit.monthly, DateTime(2026, 1, 31)),
        now,
      );
      expect(plan, hasLength(6));
      expect(plan.first.at, DateTime(2026, 10, 31, 9));
      expect(plan[1].at, DateTime(2026, 11, 30, 9));
      expect(plan.every((item) => item.repeat == null), isTrue);
    });

    test('every plan fits in the slots reserved per task', () {
      final plans = [
        planOccurrences(
          ReminderSchedule(
            type: ReminderType.dateRange,
            calendarSystem: CalendarSystem.gregorian,
            time: _nine,
            date: DateTime(2026, 1, 1),
            endDate: DateTime(2030, 1, 1),
          ),
          now,
        ),
        planOccurrences(
          _custom(
            RecurrenceUnit.weekly,
            DateTime(2026, 1, 1),
            weekdays: {1, 2, 3, 4, 5, 6, 7},
          ),
          now,
        ),
      ];
      for (final plan in plans) {
        expect(plan.length, lessThan(snoozeSlot));
      }
    });
  });

  test('notification IDs are stable and never overlap between tasks', () {
    const schedule = ReminderSchedule(
      type: ReminderType.everyday,
      calendarSystem: CalendarSystem.gregorian,
      time: _nine,
    );
    const a = ReminderTask(
      id: 'a',
      notificationId: 1,
      categoryId: 'c',
      title: 'A',
      schedule: schedule,
    );
    const b = ReminderTask(
      id: 'b',
      notificationId: 2,
      categoryId: 'c',
      title: 'B',
      schedule: schedule,
    );
    expect(notificationIdFor(a, 0), 32);
    expect(notificationIdFor(a, snoozeSlot), 63);
    expect(notificationIdFor(b, 0), 64);
  });
}
