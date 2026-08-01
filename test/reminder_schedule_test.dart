import 'package:adl_reminder/app_controller.dart';
import 'package:adl_reminder/models.dart';
import 'package:adl_reminder/utils/calendar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date range includes every day from start through end', () {
    final schedule = ReminderSchedule(
      type: ReminderType.dateRange,
      calendarSystem: CalendarSystem.gregorian,
      date: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 12),
      time: const TimeOfDay(hour: 9, minute: 0),
      delivery: ReminderDelivery.alarm,
    );

    expect(schedule.occursOn(DateTime(2026, 7, 9)), isFalse);
    expect(schedule.occursOn(DateTime(2026, 7, 10)), isTrue);
    expect(schedule.occursOn(DateTime(2026, 7, 11)), isTrue);
    expect(schedule.occursOn(DateTime(2026, 7, 12)), isTrue);
    expect(schedule.occursOn(DateTime(2026, 7, 13)), isFalse);
    expect(schedule.delivery, ReminderDelivery.alarm);
  });

  test("Today's tasks smart category filters by schedule", () {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.tasks.clear();

    controller.addTask(
      ReminderTask(
        id: 'daily',
        categoryId: controller.categories.first.id,
        title: 'Daily task',
        schedule: const ReminderSchedule(
          type: ReminderType.everyday,
          calendarSystem: CalendarSystem.gregorian,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
      ),
    );
    controller.addTask(
      ReminderTask(
        id: 'future',
        categoryId: controller.categories.first.id,
        title: 'Future task',
        schedule: ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.gregorian,
          date: DateTime.now().add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 9, minute: 0),
        ),
      ),
    );

    controller.selectCategory(AppController.todayCategoryId);

    expect(
      controller.tasksFor(DashboardTaskState.active).map((task) => task.id),
      ['daily'],
    );
  });

  test('category titles can be edited', () {
    final controller = AppController();
    addTearDown(controller.dispose);
    final category = controller.categories.first;

    controller.renameCategory(category, 'Home');

    expect(category.name, 'Home');
  });

  group('overdue status', () {
    ReminderTask taskWith(ReminderSchedule schedule) => ReminderTask(
      id: 'status-test',
      categoryId: 'test',
      title: 'Status test',
      schedule: schedule,
    );

    test('a one-time reminder later today stays active', () {
      final now = DateTime(2026, 8, 1, 10);
      final task = taskWith(
        ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.gregorian,
          date: DateTime(2026, 8, 1),
          time: const TimeOfDay(hour: 18, minute: 0),
        ),
      );

      expect(task.stateAt(now), DashboardTaskState.active);
    });

    test('a one-time reminder stays active throughout its due minute', () {
      final task = taskWith(
        ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.gregorian,
          date: DateTime(2026, 8, 1),
          time: const TimeOfDay(hour: 12, minute: 15),
        ),
      );

      expect(
        task.stateAt(DateTime(2026, 8, 1, 12, 15, 59)),
        DashboardTaskState.active,
      );
      expect(
        task.stateAt(DateTime(2026, 8, 1, 12, 16)),
        DashboardTaskState.overdue,
      );
    });

    test('an Ethiopian reminder later today stays active', () {
      final gregorianDate = DateTime(2026, 8, 1);
      final ethiopianDate = gregorianToEthiopian(gregorianDate);
      final task = taskWith(
        ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.ethiopian,
          date: ethiopianToGregorian(ethiopianDate),
          ethiopianDate: ethiopianDate,
          time: const TimeOfDay(hour: 18, minute: 0),
        ),
      );

      expect(
        task.stateAt(DateTime(2026, 8, 1, 12, 15)),
        DashboardTaskState.active,
      );
    });

    test('an ongoing recurring reminder does not become overdue', () {
      final task = taskWith(
        ReminderSchedule(
          type: ReminderType.custom,
          calendarSystem: CalendarSystem.gregorian,
          date: DateTime(2026, 7, 1),
          time: const TimeOfDay(hour: 9, minute: 0),
          recurrenceUnit: RecurrenceUnit.weekly,
          weekdays: const {DateTime.monday},
        ),
      );

      expect(task.stateAt(DateTime(2026, 8, 1, 10)), DashboardTaskState.active);
    });

    test('a date range stays active until its end time', () {
      final task = taskWith(
        ReminderSchedule(
          type: ReminderType.dateRange,
          calendarSystem: CalendarSystem.gregorian,
          date: DateTime(2026, 7, 30),
          endDate: DateTime(2026, 8, 2),
          time: const TimeOfDay(hour: 18, minute: 0),
        ),
      );

      expect(task.stateAt(DateTime(2026, 8, 1, 10)), DashboardTaskState.active);
    });
  });
}
