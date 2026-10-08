import 'dart:io';

import 'package:adl_reminder/app_controller.dart';
import 'package:adl_reminder/l10n/app_localizations.dart';
import 'package:adl_reminder/models.dart';
import 'package:adl_reminder/services/notification_service.dart';
import 'package:adl_reminder/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records scheduler calls instead of talking to the platform.
class FakeScheduler implements ReminderScheduler {
  final List<String> calls = [];

  @override
  Future<void> syncTask(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n,
  ) async => calls.add('sync:${task.id}');

  @override
  Future<void> syncAll(
    List<ReminderTask> tasks,
    AppSettings settings,
    AppLocalizations l10n,
  ) async => calls.add('syncAll:${tasks.length}');

  @override
  Future<void> cancelTask(ReminderTask task) async =>
      calls.add('cancel:${task.id}');

  @override
  Future<void> cancelAll(List<ReminderTask> tasks) async =>
      calls.add('cancelAll');
}

ReminderTask _oneTime(String id, {List<SubTask> subTasks = const []}) =>
    ReminderTask(
      id: id,
      categoryId: 'personal',
      title: id,
      subTasks: subTasks,
      schedule: ReminderSchedule(
        type: ReminderType.specificDate,
        calendarSystem: CalendarSystem.gregorian,
        date: DateTime.now().add(const Duration(days: 1)),
        time: const TimeOfDay(hour: 9, minute: 0),
      ),
    );

const _daily = ReminderTask(
  id: 'daily',
  categoryId: 'health',
  title: 'Daily',
  schedule: ReminderSchedule(
    type: ReminderType.everyday,
    calendarSystem: CalendarSystem.gregorian,
    time: TimeOfDay(hour: 9, minute: 0),
  ),
);

void main() {
  group('persistence', () {
    test(
      'tasks, categories, settings and language survive a restart',
      () async {
        final storage = MemoryReminderStorage();
        final first = await AppController.load(
          storage: storage,
          scheduler: FakeScheduler(),
        );
        final category = first.addCategory('Bills');
        final added = first.addTask(_oneTime('pay-rent'));
        first.setLanguage(AppLanguage.amharic);
        first.updateSettings(() => first.settings.snoozeMinutes = 30);

        final second = await AppController.load(
          storage: storage,
          scheduler: FakeScheduler(),
        );
        expect(second.categoryById(category.id)?.name, 'Bills');
        expect(
          second.taskById('pay-rent')?.notificationId,
          added.notificationId,
        );
        expect(second.language, AppLanguage.amharic);
        expect(second.settings.snoozeMinutes, 30);
        // Demo data is only created on the very first launch.
        expect(second.tasks.length, first.tasks.length);
      },
    );

    test('every task gets a unique, stable notification ID', () async {
      final storage = MemoryReminderStorage();
      final controller = await AppController.load(
        storage: storage,
        scheduler: FakeScheduler(),
      );
      controller.addTask(_oneTime('x'));
      final ids = controller.tasks.map((task) => task.notificationId).toSet();
      expect(ids.length, controller.tasks.length);
      expect(ids.contains(0), isFalse);

      final reloaded = await AppController.load(
        storage: storage,
        scheduler: FakeScheduler(),
      );
      expect(reloaded.tasks.map((task) => task.notificationId).toSet(), ids);
    });

    test(
      'file storage writes atomically and recovers from corruption',
      () async {
        final directory = await Directory.systemTemp.createTemp('adl_test');
        addTearDown(() => directory.delete(recursive: true));
        final storage = FileReminderStorage(directory: () async => directory);

        expect(await storage.load(), isNull);
        await storage.save({'version': 1, 'tasks': []});
        expect(await storage.load(), {'version': 1, 'tasks': []});
        expect(
          File('${directory.path}/reminders.json.tmp').existsSync(),
          isFalse,
        );

        File('${directory.path}/reminders.json').writeAsStringSync('{broken');
        expect(await storage.load(), isNull);
        expect(
          File('${directory.path}/reminders.json.corrupt').existsSync(),
          isTrue,
        );
      },
    );
  });

  group('scheduling', () {
    late FakeScheduler scheduler;
    late AppController controller;

    setUp(() {
      scheduler = FakeScheduler();
      controller = AppController(scheduler: scheduler);
    });

    tearDown(() => controller.dispose());

    test('adding, editing, completing and deleting keep reminders in sync', () {
      final task = controller.addTask(_oneTime('t'));
      controller.updateTask(task.copyWith(title: 'renamed'));
      controller.setTaskCompleted(task, true);
      controller.setTaskCompleted(task, false);
      controller.deleteTask(task);
      expect(scheduler.calls, [
        'sync:t',
        'sync:t',
        'sync:t',
        'sync:t',
        'cancel:t',
      ]);
    });

    test(
      'turning notifications off cancels everything; on reschedules all',
      () {
        controller.updateSettings(
          () => controller.settings.notificationsEnabled = false,
        );
        controller.updateSettings(
          () => controller.settings.notificationsEnabled = true,
        );
        expect(scheduler.calls, [
          'cancelAll',
          'syncAll:${controller.tasks.length}',
        ]);
      },
    );

    test('changing sound settings rebuilds reminders', () {
      controller.updateSettings(
        () => controller.settings.builtInSound = BuiltInSound.systemAlarm,
      );
      expect(scheduler.calls.single, startsWith('syncAll'));
    });

    test('editing a task keeps its notification ID', () {
      final task = controller.addTask(_oneTime('t'));
      final updated = controller.updateTask(
        _oneTime('t'), // a fresh copy from the editor has no ID
      );
      expect(updated.notificationId, task.notificationId);
    });

    test('deleted tasks and categories can be restored', () {
      final task = controller.addTask(_oneTime('t'));
      final index = controller.deleteTask(task);
      controller.restoreTask(task, index);
      expect(controller.taskById('t'), isNotNull);

      final category = controller.categoryById('personal')!;
      final count = controller.categoryTotalTaskCount('personal');
      final deleted = controller.deleteCategory(category)!;
      expect(controller.categoryById('personal'), isNull);
      controller.restoreCategory(deleted);
      expect(controller.categoryById('personal'), isNotNull);
      expect(controller.categoryTotalTaskCount('personal'), count);
    });
  });

  group('completion', () {
    test('a completed daily task comes back the next day', () {
      final now = DateTime(2026, 10, 7, 12);
      final done = _daily.copyWith(completedAt: () => now);
      expect(done.stateAt(now), DashboardTaskState.completed);
      expect(
        done.stateAt(DateTime(2026, 10, 7, 23, 59)),
        DashboardTaskState.completed,
      );
      expect(done.stateAt(DateTime(2026, 10, 8, 8)), DashboardTaskState.active);
    });

    test('a completed weekly task stays done until its next weekday', () {
      final task = ReminderTask(
        id: 'w',
        categoryId: 'c',
        title: 'w',
        schedule: ReminderSchedule(
          type: ReminderType.custom,
          calendarSystem: CalendarSystem.gregorian,
          time: const TimeOfDay(hour: 9, minute: 0),
          date: DateTime(2026, 9, 1),
          recurrenceUnit: RecurrenceUnit.weekly,
          weekdays: const {DateTime.monday},
        ),
        completedAt: DateTime(2026, 10, 5, 10), // Monday
      );
      expect(
        task.stateAt(DateTime(2026, 10, 9)), // Friday
        DashboardTaskState.completed,
      );
      expect(
        task.stateAt(DateTime(2026, 10, 12, 8)), // next Monday
        DashboardTaskState.active,
      );
    });

    test('ticking every subtask finishes the task; unticking reopens it', () {
      final controller = AppController(scheduler: FakeScheduler());
      addTearDown(controller.dispose);
      controller.addTask(
        _oneTime(
          's',
          subTasks: const [
            SubTask(id: 'a', title: 'a'),
            SubTask(id: 'b', title: 'b'),
          ],
        ),
      );
      ReminderTask task() => controller.taskById('s')!;

      controller.setSubTaskCompleted(task(), task().subTasks[0], true);
      expect(task().isCompleted, isFalse);
      controller.setSubTaskCompleted(task(), task().subTasks[1], true);
      expect(task().isCompleted, isTrue);
      controller.setSubTaskCompleted(task(), task().subTasks[1], false);
      expect(task().isCompleted, isFalse);
    });

    test('reopening a task with all subtasks ticked clears them', () {
      final controller = AppController(scheduler: FakeScheduler());
      addTearDown(controller.dispose);
      controller.addTask(
        _oneTime(
          's',
          subTasks: const [SubTask(id: 'a', title: 'a')],
        ),
      );
      final task = controller.taskById('s')!;
      controller.setSubTaskCompleted(task, task.subTasks.single, true);
      controller.setTaskCompleted(controller.taskById('s')!, false);
      expect(controller.taskById('s')!.progressAt(DateTime.now()), 0);
    });
  });

  test('drawer badges count only unfinished tasks', () {
    final controller = AppController(scheduler: FakeScheduler());
    addTearDown(controller.dispose);
    // Demo data: "Call family" in Personal is completed.
    expect(controller.categoryTotalTaskCount('personal'), 2);
    expect(controller.categoryTaskCount('personal'), 1);
  });

  test('categories reject duplicate names and get distinct colors', () {
    final controller = AppController(scheduler: FakeScheduler());
    addTearDown(controller.dispose);
    expect(controller.categoryNameExists(' personal '), isTrue);
    expect(
      controller.categoryNameExists('Personal', exceptId: 'personal'),
      isFalse,
    );

    final a = controller.addCategory('A');
    final b = controller.addCategory('B');
    expect(a.colorValue, isNot(b.colorValue));
    controller.deleteCategory(a);
    final c = controller.addCategory('C');
    expect(c.colorValue, isNot(b.colorValue));
  });

  test('English and Amharic define the same strings', () {
    expect(AppLocalizations.keysFor('am'), AppLocalizations.keysFor('en'));
  });
}
