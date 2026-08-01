import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'services/notification_service.dart';

enum AppLanguage { english, amharic }

class AppController extends ChangeNotifier {
  static const String todayCategoryId = '__today__';

  AppController() {
    _seedDemoData();
  }

  final AppSettings settings = AppSettings();

  final List<TaskCategory> categories = <TaskCategory>[];
  final List<ReminderTask> tasks = <ReminderTask>[];

  String searchQuery = '';
  String? selectedCategoryId;
  AppLanguage language = AppLanguage.english;

  Locale get locale => Locale(language == AppLanguage.amharic ? 'am' : 'en');

  void setLanguage(AppLanguage value) {
    if (language == value) return;
    language = value;
    notifyListeners();
  }

  List<ReminderTask> tasksFor(DashboardTaskState state) {
    final normalized = searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    return tasks.where((task) {
      final categoryMatches =
          selectedCategoryId == null ||
          (selectedCategoryId == todayCategoryId
              ? task.schedule.occursOn(now)
              : task.categoryId == selectedCategoryId);
      final queryMatches =
          normalized.isEmpty ||
          task.title.toLowerCase().contains(normalized) ||
          task.subTasks.any(
            (item) => item.title.toLowerCase().contains(normalized),
          );
      return categoryMatches && queryMatches && task.stateAt(now) == state;
    }).toList()..sort((a, b) {
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue == null && bDue == null) return a.title.compareTo(b.title);
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });
  }

  Map<TaskCategory, List<ReminderTask>> groupedTasks(DashboardTaskState state) {
    final visibleTasks = tasksFor(state);
    final result = <TaskCategory, List<ReminderTask>>{};
    for (final category in categories) {
      final matching = visibleTasks
          .where((task) => task.categoryId == category.id)
          .toList();
      if (matching.isNotEmpty) result[category] = matching;
    }
    return result;
  }

  int categoryTaskCount(String categoryId) {
    if (categoryId == todayCategoryId) {
      final today = DateTime.now();
      return tasks.where((task) => task.schedule.occursOn(today)).length;
    }
    return tasks.where((task) => task.categoryId == categoryId).length;
  }

  TaskStatusSummary get overallSummary {
    return _summarizeTasks(tasks, DateTime.now());
  }

  Map<ReminderScheduleGroup, TaskStatusSummary> get summaryBySchedule {
    final now = DateTime.now();
    return <ReminderScheduleGroup, TaskStatusSummary>{
      for (final group in ReminderScheduleGroup.values)
        group: _summarizeTasks(
          tasks.where((task) => task.schedule.group == group),
          now,
        ),
    };
  }

  TaskStatusSummary _summarizeTasks(
    Iterable<ReminderTask> source,
    DateTime now,
  ) {
    var done = 0;
    var overdue = 0;
    var undone = 0;

    for (final task in source) {
      switch (task.stateAt(now)) {
        case DashboardTaskState.completed:
          done++;
          break;
        case DashboardTaskState.overdue:
          overdue++;
          break;
        case DashboardTaskState.active:
          undone++;
          break;
      }
    }

    return TaskStatusSummary(done: done, overdue: overdue, undone: undone);
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
  }

  TaskCategory addCategory(String name) {
    final palette = <Color>[
      Colors.teal,
      Colors.indigo,
      Colors.orange,
      Colors.pink,
      Colors.blueGrey,
      Colors.deepPurple,
    ];
    final icons = <IconData>[
      Icons.bookmark_outline,
      Icons.star_outline,
      Icons.folder_outlined,
      Icons.flag_outlined,
      Icons.lightbulb_outline,
      Icons.category_outlined,
    ];
    final category = TaskCategory(
      id: 'category-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      icon: icons[categories.length % icons.length],
      color: palette[categories.length % palette.length],
    );
    categories.add(category);
    notifyListeners();
    return category;
  }

  void renameCategory(TaskCategory category, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == category.name) return;
    category.name = normalized;
    notifyListeners();
  }

  void deleteCategory(TaskCategory category) {
    final removedTasks = tasks
        .where((task) => task.categoryId == category.id)
        .toList();
    categories.removeWhere((item) => item.id == category.id);
    tasks.removeWhere((task) => task.categoryId == category.id);
    for (final task in removedTasks) {
      unawaited(NotificationService.instance.cancelTask(task));
    }
    if (selectedCategoryId == category.id) {
      selectedCategoryId = null;
    }
    notifyListeners();
  }

  void addTask(ReminderTask task) {
    tasks.add(task);
    notifyListeners();
  }

  void setTaskCompleted(ReminderTask task, bool completed) {
    task.completedAt = completed ? DateTime.now() : null;
    unawaited(
      completed
          ? NotificationService.instance.cancelTask(task)
          : NotificationService.instance.scheduleTask(task),
    );
    notifyListeners();
  }

  void setSubTaskCompleted(ReminderTask task, SubTask subTask, bool completed) {
    subTask.isDone = completed;
    notifyListeners();
  }

  void updateSettings(VoidCallback mutation) {
    mutation();
    notifyListeners();
  }

  void _seedDemoData() {
    final personal = TaskCategory(
      id: 'personal',
      name: 'Personal',
      icon: Icons.person_outline,
      color: Colors.teal,
    );
    final work = TaskCategory(
      id: 'work',
      name: 'Work',
      icon: Icons.work_outline,
      color: Colors.indigo,
    );
    final health = TaskCategory(
      id: 'health',
      name: 'Health',
      icon: Icons.favorite_outline,
      color: Colors.redAccent,
    );
    categories.addAll(<TaskCategory>[personal, work, health]);

    final now = DateTime.now();
    tasks.addAll(<ReminderTask>[
      ReminderTask(
        id: 'task-1',
        categoryId: personal.id,
        title: 'Renew driving license',
        schedule: ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.ethiopian,
          date: now.add(const Duration(days: 2)),
          ethiopianDate: const EthiopianDateValue(
            year: 2018,
            month: 12,
            day: 1,
          ),
          time: const TimeOfDay(hour: 9, minute: 0),
        ),
      ),
      ReminderTask(
        id: 'task-2',
        categoryId: work.id,
        title: 'Prepare production deployment',
        schedule: ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.gregorian,
          date: now.add(const Duration(hours: 5)),
          time: const TimeOfDay(hour: 16, minute: 30),
        ),
        subTasks: <SubTask>[
          SubTask(id: 'sub-1', title: 'Review environment variables'),
          SubTask(id: 'sub-2', title: 'Run smoke tests'),
          SubTask(id: 'sub-3', title: 'Notify test team'),
        ],
      ),
      ReminderTask(
        id: 'task-3',
        categoryId: health.id,
        title: 'Drink water',
        schedule: const ReminderSchedule(
          type: ReminderType.everyday,
          calendarSystem: CalendarSystem.gregorian,
          time: TimeOfDay(hour: 10, minute: 0),
        ),
      ),
      ReminderTask(
        id: 'task-4',
        categoryId: work.id,
        title: 'Submit weekly progress report',
        schedule: ReminderSchedule(
          type: ReminderType.custom,
          calendarSystem: CalendarSystem.gregorian,
          date: now.subtract(const Duration(days: 1)),
          recurrenceUnit: RecurrenceUnit.weekly,
          weekdays: const <int>{DateTime.friday},
          time: const TimeOfDay(hour: 17, minute: 0),
        ),
      ),
      ReminderTask(
        id: 'task-5',
        categoryId: personal.id,
        title: 'Call family',
        schedule: ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.gregorian,
          date: now.subtract(const Duration(days: 3)),
          time: const TimeOfDay(hour: 19, minute: 0),
        ),
        completedAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
  }
}
