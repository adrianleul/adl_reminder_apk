import 'package:adl_reminder/app_controller.dart';
import 'package:adl_reminder/models.dart';
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
}
