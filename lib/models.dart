import 'package:flutter/material.dart';

import 'utils/ethiopian_calendar.dart';

export 'utils/ethiopian_calendar.dart' show EthiopianDateValue;

enum DashboardTaskState { active, overdue, completed }

enum ReminderScheduleGroup {
  oneTime,
  dateRange,
  daily,
  weekly,
  monthly,
  yearly,
}

enum ReminderType { specificDate, dateRange, everyday, custom }

enum RecurrenceUnit { weekly, monthly, yearly }

enum CalendarSystem { gregorian, ethiopian }

enum ReminderDelivery { notification, alarm }

enum NotificationPriority { low, normal, high, urgent }

enum VibrationPatternOption { short, standard, long, pulse }

/// Sounds that ship with every Android device. Custom recordings and imported
/// files are stored separately in [AppSettings.customAlarmSounds].
enum BuiltInSound { systemDefault, systemAlarm, silent }

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class TaskStatusSummary {
  const TaskStatusSummary({this.done = 0, this.overdue = 0, this.undone = 0});

  final int done;
  final int overdue;
  final int undone;

  int get total => done + overdue + undone;
}

/// Icons are stored by key so categories survive serialization and icon
/// tree-shaking in release builds.
const Map<String, IconData> categoryIcons = <String, IconData>{
  'person': Icons.person_outline,
  'work': Icons.work_outline,
  'health': Icons.favorite_outline,
  'bookmark': Icons.bookmark_outline,
  'star': Icons.star_outline,
  'folder': Icons.folder_outlined,
  'flag': Icons.flag_outlined,
  'lightbulb': Icons.lightbulb_outline,
  'category': Icons.category_outlined,
};

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
  });

  factory TaskCategory.fromJson(Map<String, Object?> json) => TaskCategory(
    id: json['id']! as String,
    name: json['name']! as String,
    iconKey: json['icon'] as String? ?? 'category',
    colorValue: json['color'] as int? ?? Colors.teal.toARGB32(),
  );

  final String id;
  final String name;
  final String iconKey;
  final int colorValue;

  IconData get icon => categoryIcons[iconKey] ?? Icons.category_outlined;
  Color get color => Color(colorValue);

  TaskCategory copyWith({String? name}) => TaskCategory(
    id: id,
    name: name ?? this.name,
    iconKey: iconKey,
    colorValue: colorValue,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'icon': iconKey,
    'color': colorValue,
  };
}

class SubTask {
  const SubTask({required this.id, required this.title, this.doneAt});

  factory SubTask.fromJson(Map<String, Object?> json) => SubTask(
    id: json['id']! as String,
    title: json['title']! as String,
    doneAt: _parseDate(json['doneAt']),
  );

  final String id;
  final String title;

  /// When the subtask was last ticked. For recurring tasks it only counts for
  /// the occurrence it was ticked in (see [ReminderTask.isSubTaskDoneAt]).
  final DateTime? doneAt;

  SubTask copyWith({String? title, DateTime? Function()? doneAt}) => SubTask(
    id: id,
    title: title ?? this.title,
    doneAt: doneAt == null ? this.doneAt : doneAt(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'doneAt': doneAt?.toIso8601String(),
  };
}

class ReminderSchedule {
  const ReminderSchedule({
    required this.type,
    required this.calendarSystem,
    required this.time,
    this.date,
    this.endDate,
    this.recurrenceUnit,
    this.weekdays = const <int>{},
    this.delivery = ReminderDelivery.notification,
  });

  factory ReminderSchedule.fromJson(Map<String, Object?> json) {
    final minutes = json['time'] as int? ?? 9 * 60;
    return ReminderSchedule(
      type: _enumByName(
        ReminderType.values,
        json['type'],
        ReminderType.specificDate,
      ),
      calendarSystem: _enumByName(
        CalendarSystem.values,
        json['calendar'],
        CalendarSystem.gregorian,
      ),
      time: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      date: _parseDate(json['date']),
      endDate: _parseDate(json['endDate']),
      recurrenceUnit: json['recurrence'] == null
          ? null
          : _enumByName(
              RecurrenceUnit.values,
              json['recurrence'],
              RecurrenceUnit.weekly,
            ),
      weekdays: {
        for (final day in (json['weekdays'] as List<Object?>? ?? const []))
          day! as int,
      },
      delivery: _enumByName(
        ReminderDelivery.values,
        json['delivery'],
        ReminderDelivery.notification,
      ),
    );
  }

  final ReminderType type;
  final CalendarSystem calendarSystem;
  final TimeOfDay time;

  /// Gregorian start date. Dates are always stored in Gregorian; the Ethiopian
  /// values are derived so both views can never disagree.
  final DateTime? date;
  final DateTime? endDate;
  final RecurrenceUnit? recurrenceUnit;
  final Set<int> weekdays;
  final ReminderDelivery delivery;

  EthiopianDateValue? get ethiopianDate =>
      date == null ? null : gregorianToEthiopian(date!);
  EthiopianDateValue? get ethiopianEndDate =>
      endDate == null ? null : gregorianToEthiopian(endDate!);

  bool get isRecurring =>
      type == ReminderType.everyday || type == ReminderType.custom;

  ReminderScheduleGroup get group {
    return switch (type) {
      ReminderType.specificDate => ReminderScheduleGroup.oneTime,
      ReminderType.dateRange => ReminderScheduleGroup.dateRange,
      ReminderType.everyday => ReminderScheduleGroup.daily,
      ReminderType.custom => switch (recurrenceUnit) {
        RecurrenceUnit.weekly => ReminderScheduleGroup.weekly,
        RecurrenceUnit.monthly => ReminderScheduleGroup.monthly,
        RecurrenceUnit.yearly => ReminderScheduleGroup.yearly,
        null => ReminderScheduleGroup.oneTime,
      },
    };
  }

  DateTime atTime(DateTime day) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  DateTime? get firstOccurrence => date == null ? null : atTime(date!);

  DateTime? get deadline {
    final value = type == ReminderType.dateRange ? endDate : date;
    return value == null ? null : atTime(value);
  }

  bool isOverdueAt(DateTime now) {
    if (isRecurring) return false;
    final dueDate = type == ReminderType.dateRange ? endDate : date;
    if (dueDate == null) return false;

    final dueDay = dateOnly(dueDate);
    final today = dateOnly(now);
    if (dueDay.isBefore(today)) return true;
    if (dueDay.isAfter(today)) return false;

    final dueMinute = time.hour * 60 + time.minute;
    final currentMinute = now.hour * 60 + now.minute;
    return currentMinute > dueMinute;
  }

  bool occursOn(DateTime day) {
    final target = dateOnly(day);
    final start = date == null ? null : dateOnly(date!);
    switch (type) {
      case ReminderType.specificDate:
        return start == target;
      case ReminderType.dateRange:
        return start != null &&
            endDate != null &&
            !target.isBefore(start) &&
            !target.isAfter(dateOnly(endDate!));
      case ReminderType.everyday:
        return true;
      case ReminderType.custom:
        if (start != null && target.isBefore(start)) return false;
        return switch (recurrenceUnit) {
          RecurrenceUnit.weekly => weekdays.contains(target.weekday),
          RecurrenceUnit.monthly =>
            start != null && _sameDayOfMonth(start, target),
          RecurrenceUnit.yearly =>
            start != null && _sameDayOfYear(start, target),
          null => false,
        };
    }
  }

  /// Day-of-month matching that falls back to the month's last day, so a
  /// reminder on the 31st still fires in shorter months instead of drifting.
  bool _sameDayOfMonth(DateTime start, DateTime target) {
    if (calendarSystem == CalendarSystem.ethiopian) {
      final s = gregorianToEthiopian(start);
      final t = gregorianToEthiopian(target);
      final length = ethiopianMonthLength(t.year, t.month);
      return t.day == (s.day < length ? s.day : length);
    }
    final length = _daysInMonth(target.year, target.month);
    return target.day == (start.day < length ? start.day : length);
  }

  bool _sameDayOfYear(DateTime start, DateTime target) {
    if (calendarSystem == CalendarSystem.ethiopian) {
      final s = gregorianToEthiopian(start);
      final t = gregorianToEthiopian(target);
      if (s.month != t.month) return false;
      final length = ethiopianMonthLength(t.year, t.month);
      return t.day == (s.day < length ? s.day : length);
    }
    if (start.month != target.month) return false;
    final length = _daysInMonth(target.year, target.month);
    return target.day == (start.day < length ? start.day : length);
  }

  /// Longest gap between two occurrences we ever need to scan (a yearly
  /// reminder on Pagume 6 only happens every four years).
  static const int _searchDays = 1500;

  /// The first occurrence strictly after [after], or null if there is none.
  DateTime? nextOccurrenceAfter(DateTime after) {
    final first = dateOnly(after);
    final start = date == null ? null : dateOnly(date!);
    final last = switch (type) {
      ReminderType.specificDate => start,
      ReminderType.dateRange => endDate == null ? null : dateOnly(endDate!),
      _ => null,
    };
    if (!isRecurring && last == null) return null;

    var offset = 0;
    if (start != null && first.isBefore(start)) {
      offset = start.difference(first).inDays;
    }
    for (; offset < _searchDays; offset++) {
      final day = DateTime(first.year, first.month, first.day + offset);
      if (last != null && day.isAfter(last)) return null;
      if (!occursOn(day)) continue;
      final at = atTime(day);
      if (at.isAfter(after)) return at;
    }
    return null;
  }

  List<DateTime> occurrencesAfter(DateTime after, {required int limit}) {
    final result = <DateTime>[];
    var cursor = after;
    while (result.length < limit) {
      final next = nextOccurrenceAfter(cursor);
      if (next == null) break;
      result.add(next);
      cursor = next;
    }
    return result;
  }

  /// The most recent day (today included) on which this reminder occurs.
  DateTime? previousOccurrenceDay(DateTime now) {
    final today = dateOnly(now);
    final start = date == null ? null : dateOnly(date!);
    for (var offset = 0; offset < _searchDays; offset++) {
      final day = DateTime(today.year, today.month, today.day - offset);
      if (start != null && day.isBefore(start)) return null;
      if (occursOn(day)) return day;
    }
    return null;
  }

  ReminderSchedule copyWith({ReminderDelivery? delivery}) => ReminderSchedule(
    type: type,
    calendarSystem: calendarSystem,
    time: time,
    date: date,
    endDate: endDate,
    recurrenceUnit: recurrenceUnit,
    weekdays: weekdays,
    delivery: delivery ?? this.delivery,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'calendar': calendarSystem.name,
    'time': time.hour * 60 + time.minute,
    'date': date?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'recurrence': recurrenceUnit?.name,
    'weekdays': (weekdays.toList()..sort()),
    'delivery': delivery.name,
  };
}

class ReminderTask {
  const ReminderTask({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.schedule,
    this.notificationId = 0,
    this.subTasks = const [],
    this.completedAt,
  });

  factory ReminderTask.fromJson(Map<String, Object?> json) => ReminderTask(
    id: json['id']! as String,
    notificationId: json['notificationId'] as int? ?? 0,
    categoryId: json['categoryId']! as String,
    title: json['title']! as String,
    schedule: ReminderSchedule.fromJson(
      (json['schedule']! as Map).cast<String, Object?>(),
    ),
    subTasks: [
      for (final item in (json['subTasks'] as List<Object?>? ?? const []))
        SubTask.fromJson((item! as Map).cast<String, Object?>()),
    ],
    completedAt: _parseDate(json['completedAt']),
  );

  final String id;

  /// Stable, persisted base for this task's platform notification IDs.
  final int notificationId;
  final String categoryId;
  final String title;
  final ReminderSchedule schedule;
  final List<SubTask> subTasks;

  /// For one-time tasks: when the task was finished. For recurring tasks: when
  /// the most recent occurrence was finished.
  final DateTime? completedAt;

  /// Whether a mark is still valid for the occurrence in progress at [now].
  bool _markValidAt(DateTime mark, DateTime now) {
    if (!schedule.isRecurring) return true;
    final period = schedule.previousOccurrenceDay(now);
    // Finished before the first occurrence even started.
    if (period == null) return true;
    return !mark.isBefore(period);
  }

  bool isCompletedAt(DateTime now) =>
      completedAt != null && _markValidAt(completedAt!, now);

  bool get isCompleted => isCompletedAt(DateTime.now());

  bool isSubTaskDoneAt(SubTask subTask, DateTime now) =>
      subTask.doneAt != null && _markValidAt(subTask.doneAt!, now);

  /// The next time this task needs attention: the deadline for one-time tasks,
  /// the next occurrence for recurring ones.
  DateTime? dueAt(DateTime now) => schedule.isRecurring
      ? schedule.nextOccurrenceAfter(now)
      : schedule.deadline;

  DashboardTaskState stateAt(DateTime now) {
    if (isCompletedAt(now)) return DashboardTaskState.completed;
    if (schedule.isOverdueAt(now)) return DashboardTaskState.overdue;
    return DashboardTaskState.active;
  }

  double progressAt(DateTime now) {
    if (isCompletedAt(now)) return 1;
    if (subTasks.isEmpty) return 0;
    final done = subTasks.where((item) => isSubTaskDoneAt(item, now)).length;
    return done / subTasks.length;
  }

  ReminderTask copyWith({
    int? notificationId,
    String? categoryId,
    String? title,
    ReminderSchedule? schedule,
    List<SubTask>? subTasks,
    DateTime? Function()? completedAt,
  }) => ReminderTask(
    id: id,
    notificationId: notificationId ?? this.notificationId,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    schedule: schedule ?? this.schedule,
    subTasks: subTasks ?? this.subTasks,
    completedAt: completedAt == null ? this.completedAt : completedAt(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'notificationId': notificationId,
    'categoryId': categoryId,
    'title': title,
    'schedule': schedule.toJson(),
    'subTasks': [for (final item in subTasks) item.toJson()],
    'completedAt': completedAt?.toIso8601String(),
  };
}

class CustomAlarmSound {
  const CustomAlarmSound({
    required this.id,
    required this.name,
    required this.path,
  });

  factory CustomAlarmSound.fromJson(Map<String, Object?> json) =>
      CustomAlarmSound(
        id: json['id']! as String,
        name: json['name']! as String,
        path: json['path']! as String,
      );

  final String id;
  final String name;
  final String path;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'path': path};
}

class AppSettings {
  AppSettings({
    this.notificationsEnabled = true,
    this.vibrationEnabled = true,
    this.vibrationPattern = VibrationPatternOption.standard,
    this.builtInSound = BuiltInSound.systemDefault,
    this.alarmSoundPath,
    List<CustomAlarmSound>? customAlarmSounds,
    this.notificationPriority = NotificationPriority.high,
    this.snoozeMinutes = 10,
    this.defaultCalendar = CalendarSystem.ethiopian,
    this.microphoneRationaleShown = false,
  }) : customAlarmSounds = customAlarmSounds ?? [];

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    vibrationPattern: _enumByName(
      VibrationPatternOption.values,
      json['vibrationPattern'],
      VibrationPatternOption.standard,
    ),
    builtInSound: _enumByName(
      BuiltInSound.values,
      json['builtInSound'],
      BuiltInSound.systemDefault,
    ),
    alarmSoundPath: json['alarmSoundPath'] as String?,
    customAlarmSounds: [
      for (final item in (json['customAlarmSounds'] as List<Object?>? ?? []))
        CustomAlarmSound.fromJson((item! as Map).cast<String, Object?>()),
    ],
    notificationPriority: _enumByName(
      NotificationPriority.values,
      json['notificationPriority'],
      NotificationPriority.high,
    ),
    snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
    defaultCalendar: _enumByName(
      CalendarSystem.values,
      json['defaultCalendar'],
      CalendarSystem.ethiopian,
    ),
    microphoneRationaleShown:
        json['microphoneRationaleShown'] as bool? ?? false,
  );

  bool notificationsEnabled;
  bool vibrationEnabled;
  VibrationPatternOption vibrationPattern;
  BuiltInSound builtInSound;

  /// Path of the selected custom sound; null when a built-in sound is used.
  String? alarmSoundPath;
  final List<CustomAlarmSound> customAlarmSounds;
  NotificationPriority notificationPriority;
  int snoozeMinutes;
  CalendarSystem defaultCalendar;
  bool microphoneRationaleShown;

  CustomAlarmSound? get selectedCustomSound {
    for (final sound in customAlarmSounds) {
      if (sound.path == alarmSoundPath) return sound;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'vibrationEnabled': vibrationEnabled,
    'vibrationPattern': vibrationPattern.name,
    'builtInSound': builtInSound.name,
    'alarmSoundPath': alarmSoundPath,
    'customAlarmSounds': [
      for (final sound in customAlarmSounds) sound.toJson(),
    ],
    'notificationPriority': notificationPriority.name,
    'snoozeMinutes': snoozeMinutes,
    'defaultCalendar': defaultCalendar.name,
    'microphoneRationaleShown': microphoneRationaleShown,
  };
}

/// Vibration timings (ms) shared by notification channels and the alarm screen.
List<int> vibrationTimings(VibrationPatternOption pattern) => switch (pattern) {
  VibrationPatternOption.short => const [0, 120],
  VibrationPatternOption.standard => const [0, 180, 100, 180],
  VibrationPatternOption.long => const [0, 650],
  VibrationPatternOption.pulse => const [0, 100, 80, 100, 80, 100],
};
