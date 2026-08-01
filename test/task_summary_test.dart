import 'package:adl_reminder/app_controller.dart';
import 'package:adl_reminder/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overall summary separates done, overdue, and undone tasks', () {
    final controller = AppController();
    controller.tasks.clear();

    final now = DateTime.now();
    controller.tasks.addAll(<ReminderTask>[
      _task(
        id: 'done',
        date: now.subtract(const Duration(days: 2)),
        completedAt: now.subtract(const Duration(days: 1)),
      ),
      _task(id: 'overdue', date: now.subtract(const Duration(days: 1))),
      _task(id: 'undone', date: now.add(const Duration(days: 1))),
    ]);

    final summary = controller.overallSummary;

    expect(summary.total, 3);
    expect(summary.done, 1);
    expect(summary.overdue, 1);
    expect(summary.undone, 1);
  });

  test('schedule summary counts each recurring task once', () {
    final controller = AppController();
    controller.tasks.clear();

    final now = DateTime.now();
    controller.tasks.addAll(<ReminderTask>[
      ReminderTask(
        id: 'daily-active',
        categoryId: 'personal',
        title: 'Daily active',
        schedule: const ReminderSchedule(
          type: ReminderType.everyday,
          calendarSystem: CalendarSystem.gregorian,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
      ),
      ReminderTask(
        id: 'weekly-overdue',
        categoryId: 'personal',
        title: 'Weekly overdue',
        schedule: ReminderSchedule(
          type: ReminderType.custom,
          recurrenceUnit: RecurrenceUnit.weekly,
          calendarSystem: CalendarSystem.gregorian,
          date: now.subtract(const Duration(days: 1)),
          time: const TimeOfDay(hour: 9, minute: 0),
        ),
      ),
      ReminderTask(
        id: 'monthly-done',
        categoryId: 'personal',
        title: 'Monthly done',
        completedAt: now,
        schedule: ReminderSchedule(
          type: ReminderType.custom,
          recurrenceUnit: RecurrenceUnit.monthly,
          calendarSystem: CalendarSystem.gregorian,
          date: now,
          time: const TimeOfDay(hour: 9, minute: 0),
        ),
      ),
    ]);

    final bySchedule = controller.summaryBySchedule;

    expect(bySchedule[ReminderScheduleGroup.daily]?.undone, 1);
    expect(bySchedule[ReminderScheduleGroup.weekly]?.undone, 1);
    expect(bySchedule[ReminderScheduleGroup.monthly]?.done, 1);
  });
}

ReminderTask _task({
  required String id,
  required DateTime date,
  DateTime? completedAt,
}) {
  return ReminderTask(
    id: id,
    categoryId: 'personal',
    title: id,
    completedAt: completedAt,
    schedule: ReminderSchedule(
      type: ReminderType.specificDate,
      calendarSystem: CalendarSystem.gregorian,
      date: date,
      time: TimeOfDay(hour: date.hour, minute: date.minute),
    ),
  );
}
