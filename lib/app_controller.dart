import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

enum AppLanguage { english, amharic }

/// What [AppController.deleteCategory] removed, so it can be restored.
class DeletedCategory {
  const DeletedCategory(this.category, this.index, this.tasks);

  final TaskCategory category;
  final int index;
  final List<ReminderTask> tasks;
}

class AppController extends ChangeNotifier {
  static const String todayCategoryId = '__today__';
  static const int _dataVersion = 1;

  /// Creates a controller from previously saved [data], or with demo data on
  /// first launch. Use [load] to read the data from [storage].
  AppController({
    ReminderStorage? storage,
    ReminderScheduler? scheduler,
    Map<String, Object?>? data,
  }) : _storage = storage ?? MemoryReminderStorage(),
       _scheduler = scheduler ?? NotificationService.instance {
    if (data == null) {
      _seedDemoData();
    } else {
      _restore(data);
    }
  }

  static Future<AppController> load({
    required ReminderStorage storage,
    ReminderScheduler? scheduler,
  }) async {
    Map<String, Object?>? data;
    try {
      data = await storage.load();
    } catch (error) {
      debugPrint('Could not load saved reminders: $error');
    }
    final controller = AppController(
      storage: storage,
      scheduler: scheduler,
      data: data,
    );
    if (data == null) controller._save();
    return controller;
  }

  final ReminderStorage _storage;
  final ReminderScheduler _scheduler;

  AppSettings settings = AppSettings();
  final List<TaskCategory> categories = <TaskCategory>[];
  final List<ReminderTask> tasks = <ReminderTask>[];

  String searchQuery = '';
  String? selectedCategoryId;
  int _nextNotificationId = 1;

  /// Kept separate from the controller so changing tasks does not rebuild
  /// the whole [MaterialApp].
  final ValueNotifier<AppLanguage> languageNotifier = ValueNotifier(
    AppLanguage.english,
  );

  AppLanguage get language => languageNotifier.value;

  Locale get locale => Locale(language == AppLanguage.amharic ? 'am' : 'en');

  AppLocalizations get l10n => AppLocalizations(locale);

  @override
  void dispose() {
    languageNotifier.dispose();
    super.dispose();
  }

  void setLanguage(AppLanguage value) {
    if (language == value) return;
    languageNotifier.value = value;
    notifyListeners();
    _save();
    // Notification text and channel names are localized.
    unawaited(refreshSchedules());
  }

  // ---------------------------------------------------------------------------
  // Queries

  ReminderTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  TaskCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<ReminderTask> tasksFor(DashboardTaskState state) {
    final normalized = searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    final result = tasks.where((task) {
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
    }).toList();

    final due = {for (final task in result) task.id: task.dueAt(now)};
    return result..sort((a, b) {
      final aDue = due[a.id];
      final bDue = due[b.id];
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

  /// Where a task's next reminder search starts: now, or the end of today
  /// for a recurring task already finished today. Null when it is finished
  /// for good.
  DateTime? _searchFrom(ReminderTask task, DateTime now) {
    if (!task.isCompletedAt(now)) return now;
    if (!task.schedule.isRecurring) return null;
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  /// The soonest upcoming reminder across all unfinished tasks.
  ({ReminderTask task, DateTime at})? nextUp(DateTime now) {
    ({ReminderTask task, DateTime at})? best;
    for (final task in tasks) {
      final from = _searchFrom(task, now);
      if (from == null || task.stateAt(now) == DashboardTaskState.overdue) {
        continue;
      }
      final at = task.schedule.nextOccurrenceAfter(from);
      if (at != null && (best == null || at.isBefore(best.at))) {
        best = (task: task, at: at);
      }
    }
    return best;
  }

  /// Tasks that occur on [day], earliest first (the Today timeline).
  List<ReminderTask> tasksOnDay(DateTime day) {
    return tasks.where((task) => task.schedule.occursOn(day)).toList()
      ..sort((a, b) {
        final aMinutes = a.schedule.time.hour * 60 + a.schedule.time.minute;
        final bMinutes = b.schedule.time.hour * 60 + b.schedule.time.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  /// Unfinished tasks whose deadline has passed, oldest first.
  List<ReminderTask> missedTasks(DateTime now) {
    return tasks
        .where((task) => task.stateAt(now) == DashboardTaskState.overdue)
        .toList()
      ..sort((a, b) => a.schedule.deadline!.compareTo(b.schedule.deadline!));
  }

  /// Every reminder in the next [days] days, in time order (Calendar tab).
  List<({ReminderTask task, DateTime at})> agenda(
    DateTime now, {
    int days = 30,
  }) {
    final until = now.add(Duration(days: days));
    final result = <({ReminderTask task, DateTime at})>[];
    for (final task in tasks) {
      final from = _searchFrom(task, now);
      if (from == null) continue;
      for (final at in task.schedule.occurrencesAfter(from, limit: 62)) {
        if (at.isAfter(until)) break;
        result.add((task: task, at: at));
      }
    }
    return result..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Number of unfinished tasks, shown as the badge in the drawer.
  int categoryTaskCount(String categoryId) {
    final now = DateTime.now();
    return tasks.where((task) {
      if (task.isCompletedAt(now)) return false;
      return categoryId == todayCategoryId
          ? task.schedule.occursOn(now)
          : task.categoryId == categoryId;
    }).length;
  }

  /// Every task in a category, finished or not (used before deleting it).
  int categoryTotalTaskCount(String categoryId) =>
      tasks.where((task) => task.categoryId == categoryId).length;

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
        case DashboardTaskState.overdue:
          overdue++;
        case DashboardTaskState.active:
          undone++;
      }
    }

    return TaskStatusSummary(done: done, overdue: overdue, undone: undone);
  }

  // ---------------------------------------------------------------------------
  // Filters

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Categories

  static const List<Color> _palette = <Color>[
    Colors.teal,
    Colors.indigo,
    Colors.orange,
    Colors.pink,
    Colors.blueGrey,
    Colors.deepPurple,
    Colors.green,
    Colors.brown,
  ];

  static const List<String> _iconKeys = <String>[
    'bookmark',
    'star',
    'folder',
    'flag',
    'lightbulb',
    'category',
  ];

  bool categoryNameExists(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    return categories.any(
      (category) =>
          category.id != exceptId &&
          category.name.trim().toLowerCase() == normalized,
    );
  }

  /// Picks the least-used value so categories stay visually distinct even
  /// after some are deleted.
  T _leastUsed<T>(List<T> options, T Function(TaskCategory) valueOf) {
    final counts = {for (final option in options) option: 0};
    for (final category in categories) {
      final value = valueOf(category);
      if (counts.containsKey(value)) counts[value] = counts[value]! + 1;
    }
    var best = options.first;
    for (final option in options) {
      if (counts[option]! < counts[best]!) best = option;
    }
    return best;
  }

  TaskCategory addCategory(String name) {
    final category = TaskCategory(
      id: 'category-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      iconKey: _leastUsed(_iconKeys, (category) => category.iconKey),
      colorValue: _leastUsed([
        for (final color in _palette) color.toARGB32(),
      ], (category) => category.colorValue),
    );
    categories.add(category);
    _changed();
    return category;
  }

  void renameCategory(TaskCategory category, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == category.name) return;
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index < 0) return;
    categories[index] = categories[index].copyWith(name: normalized);
    _changed();
  }

  DeletedCategory? deleteCategory(TaskCategory category) {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index < 0) return null;
    final removedTasks = tasks
        .where((task) => task.categoryId == category.id)
        .toList();
    final removed = categories.removeAt(index);
    tasks.removeWhere((task) => task.categoryId == category.id);
    for (final task in removedTasks) {
      unawaited(_scheduler.cancelTask(task));
    }
    if (selectedCategoryId == category.id) selectedCategoryId = null;
    _changed();
    return DeletedCategory(removed, index, removedTasks);
  }

  void restoreCategory(DeletedCategory deleted) {
    if (categoryById(deleted.category.id) != null) return;
    categories.insert(
      deleted.index.clamp(0, categories.length),
      deleted.category,
    );
    tasks.addAll(deleted.tasks);
    for (final task in deleted.tasks) {
      _sync(task);
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Tasks

  int _allocateNotificationId() => _nextNotificationId++;

  /// Adds [task] and schedules its reminders. Returns the stored task, which
  /// carries the notification ID assigned to it.
  ReminderTask addTask(ReminderTask task) {
    final stored = task.notificationId > 0
        ? task
        : task.copyWith(notificationId: _allocateNotificationId());
    if (stored.notificationId >= _nextNotificationId) {
      _nextNotificationId = stored.notificationId + 1;
    }
    tasks.add(stored);
    _sync(stored);
    _changed();
    return stored;
  }

  /// Replaces the task with the same ID, keeping its notification slots.
  ReminderTask updateTask(ReminderTask task) {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return addTask(task);
    final updated = task.copyWith(notificationId: tasks[index].notificationId);
    tasks[index] = updated;
    _sync(updated);
    _changed();
    return updated;
  }

  /// Removes [task] and returns its position so it can be restored.
  int deleteTask(ReminderTask task) {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return -1;
    final removed = tasks.removeAt(index);
    unawaited(_scheduler.cancelTask(removed));
    _changed();
    return index;
  }

  void restoreTask(ReminderTask task, int index) {
    if (taskById(task.id) != null) return;
    tasks.insert(index.clamp(0, tasks.length), task);
    _sync(task);
    _changed();
  }

  ReminderTask? setTaskCompleted(ReminderTask task, bool completed) {
    final current = taskById(task.id);
    if (current == null) return null;
    final now = DateTime.now();
    // Reopening a task whose subtasks are all ticked clears them; otherwise
    // the task would look finished (100%) while being listed as active.
    final allSubTasksDone =
        current.subTasks.isNotEmpty &&
        current.subTasks.every((item) => current.isSubTaskDoneAt(item, now));
    final updated = current.copyWith(
      completedAt: () => completed ? now : null,
      subTasks: !completed && allSubTasksDone
          ? [
              for (final item in current.subTasks)
                item.copyWith(doneAt: () => null),
            ]
          : null,
    );
    _replace(updated);
    _sync(updated);
    _changed();
    return updated;
  }

  /// Ticks a subtask. Ticking the last open subtask finishes the task;
  /// un-ticking one reopens it.
  void setSubTaskCompleted(ReminderTask task, SubTask subTask, bool completed) {
    final current = taskById(task.id);
    if (current == null) return;
    final now = DateTime.now();
    final subTasks = [
      for (final item in current.subTasks)
        item.id == subTask.id
            ? item.copyWith(doneAt: () => completed ? now : null)
            : item,
    ];
    var updated = current.copyWith(subTasks: subTasks);
    final allDone = subTasks.every(
      (item) => updated.isSubTaskDoneAt(item, now),
    );
    final wasCompleted = current.isCompletedAt(now);
    if (allDone && !wasCompleted) {
      updated = updated.copyWith(completedAt: () => now);
    } else if (!allDone && wasCompleted) {
      updated = updated.copyWith(completedAt: () => null);
    }
    _replace(updated);
    if (updated.isCompletedAt(now) != wasCompleted) _sync(updated);
    _changed();
  }

  void _replace(ReminderTask task) {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) tasks[index] = task;
  }

  // ---------------------------------------------------------------------------
  // Settings and scheduling

  /// Applies [mutation] to [settings], saves, and rebuilds every reminder so
  /// sound, vibration, priority, snooze and the on/off switch take effect.
  void updateSettings(VoidCallback mutation) {
    mutation();
    _changed();
    unawaited(refreshSchedules());
  }

  /// Saves settings that do not affect reminders (e.g. the default calendar).
  void updatePreferences(VoidCallback mutation) {
    mutation();
    _changed();
  }

  /// Rebuilds all platform reminders from the saved tasks. Called on start,
  /// on resume and after permissions or settings change. This also tops up
  /// the rolling window of monthly, yearly and date-range reminders.
  Future<void> refreshSchedules() {
    if (!settings.notificationsEnabled) {
      return _scheduler.cancelAll(List.of(tasks));
    }
    return _scheduler.syncAll(List.of(tasks), settings, l10n);
  }

  /// Re-creates the reminders of one task, e.g. after its shown notification
  /// was dismissed or a permission was granted.
  void rescheduleTask(ReminderTask task) {
    final current = taskById(task.id);
    if (current != null) _sync(current);
  }

  void _sync(ReminderTask task) {
    unawaited(_scheduler.syncTask(task, settings, l10n));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------------------------------------------------------------------------
  // Persistence

  Map<String, Object?> toJson() => {
    'version': _dataVersion,
    'nextNotificationId': _nextNotificationId,
    'language': language.name,
    'settings': settings.toJson(),
    'categories': [for (final category in categories) category.toJson()],
    'tasks': [for (final task in tasks) task.toJson()],
  };

  void _save() {
    unawaited(
      _storage.save(toJson()).catchError((Object error) {
        debugPrint('Could not save reminders: $error');
      }),
    );
  }

  void _restore(Map<String, Object?> data) {
    languageNotifier.value = AppLanguage.values.firstWhere(
      (value) => value.name == data['language'],
      orElse: () => AppLanguage.english,
    );
    final settingsJson = data['settings'];
    if (settingsJson is Map) {
      settings = AppSettings.fromJson(settingsJson.cast<String, Object?>());
    }
    for (final item in (data['categories'] as List<Object?>? ?? const [])) {
      try {
        categories.add(
          TaskCategory.fromJson((item! as Map).cast<String, Object?>()),
        );
      } catch (error) {
        debugPrint('Skipping unreadable category: $error');
      }
    }
    _nextNotificationId = data['nextNotificationId'] as int? ?? 1;
    for (final item in (data['tasks'] as List<Object?>? ?? const [])) {
      try {
        var task = ReminderTask.fromJson(
          (item! as Map).cast<String, Object?>(),
        );
        if (task.notificationId <= 0 ||
            tasks.any((other) => other.notificationId == task.notificationId)) {
          task = task.copyWith(notificationId: _allocateNotificationId());
        }
        if (task.notificationId >= _nextNotificationId) {
          _nextNotificationId = task.notificationId + 1;
        }
        tasks.add(task);
      } catch (error) {
        debugPrint('Skipping unreadable task: $error');
      }
    }
  }

  void _seedDemoData() {
    const personal = TaskCategory(
      id: 'personal',
      name: 'Personal',
      iconKey: 'person',
      colorValue: 0xFF009688,
    );
    const work = TaskCategory(
      id: 'work',
      name: 'Work',
      iconKey: 'work',
      colorValue: 0xFF3F51B5,
    );
    const health = TaskCategory(
      id: 'health',
      name: 'Health',
      iconKey: 'health',
      colorValue: 0xFFFF5252,
    );
    categories.addAll(<TaskCategory>[personal, work, health]);

    final now = DateTime.now();
    final today = dateOnly(now);
    final demo = <ReminderTask>[
      ReminderTask(
        id: 'task-1',
        categoryId: personal.id,
        title: 'Renew driving license',
        schedule: ReminderSchedule(
          type: ReminderType.specificDate,
          calendarSystem: CalendarSystem.ethiopian,
          date: today.add(const Duration(days: 2)),
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
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 16, minute: 30),
        ),
        subTasks: const <SubTask>[
          SubTask(id: 'sub-1', title: 'Review environment variables'),
          SubTask(id: 'sub-2', title: 'Run smoke tests'),
          SubTask(id: 'sub-3', title: 'Notify test team'),
        ],
      ),
      const ReminderTask(
        id: 'task-3',
        categoryId: 'health',
        title: 'Drink water',
        schedule: ReminderSchedule(
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
          date: today.subtract(const Duration(days: 1)),
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
          date: today.subtract(const Duration(days: 3)),
          time: const TimeOfDay(hour: 19, minute: 0),
        ),
        completedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    for (final task in demo) {
      tasks.add(task.copyWith(notificationId: _allocateNotificationId()));
    }
  }
}
