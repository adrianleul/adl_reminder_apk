import 'package:flutter/material.dart';

enum DashboardTaskState { active, overdue, completed }

enum ReminderScheduleGroup { oneTime, daily, weekly, monthly, yearly }

enum ReminderType { specificDate, everyday, custom }

enum RecurrenceUnit { weekly, monthly, yearly }

enum CalendarSystem { gregorian, ethiopian }

class TaskStatusSummary {
  const TaskStatusSummary({
    this.done = 0,
    this.overdue = 0,
    this.undone = 0,
  });

  final int done;
  final int overdue;
  final int undone;

  int get total => done + overdue + undone;
}

class EthiopianDateValue {
  const EthiopianDateValue({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String get label => '$day/${month.toString().padLeft(2, '0')}/$year EC';
}

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

class SubTask {
  SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final String id;
  final String title;
  bool isDone;
}

class ReminderSchedule {
  const ReminderSchedule({
    required this.type,
    required this.calendarSystem,
    required this.time,
    this.date,
    this.ethiopianDate,
    this.recurrenceUnit,
    this.weekdays = const <int>{},
    this.notificationsEnabled = true,
  });

  final ReminderType type;
  final CalendarSystem calendarSystem;
  final TimeOfDay time;
  final DateTime? date;
  final EthiopianDateValue? ethiopianDate;
  final RecurrenceUnit? recurrenceUnit;
  final Set<int> weekdays;
  final bool notificationsEnabled;

  ReminderScheduleGroup get group {
    return switch (type) {
      ReminderType.specificDate => ReminderScheduleGroup.oneTime,
      ReminderType.everyday => ReminderScheduleGroup.daily,
      ReminderType.custom => switch (recurrenceUnit) {
          RecurrenceUnit.weekly => ReminderScheduleGroup.weekly,
          RecurrenceUnit.monthly => ReminderScheduleGroup.monthly,
          RecurrenceUnit.yearly => ReminderScheduleGroup.yearly,
          null => ReminderScheduleGroup.oneTime,
        },
    };
  }

  DateTime? get firstOccurrence {
    if (date == null) return null;
    return DateTime(date!.year, date!.month, date!.day, time.hour, time.minute);
  }
}

class ReminderTask {
  ReminderTask({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.schedule,
    this.subTasks = const [],
    this.completedAt,
  });

  final String id;
  final String categoryId;
  final String title;
  final ReminderSchedule schedule;
  final List<SubTask> subTasks;
  DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  DateTime? get dueAt => schedule.firstOccurrence;

  DashboardTaskState stateAt(DateTime now) {
    if (isCompleted) return DashboardTaskState.completed;
    final due = dueAt;
    if (due != null && due.isBefore(now)) return DashboardTaskState.overdue;
    return DashboardTaskState.active;
  }

  double get progress {
    if (isCompleted) return 1;
    if (subTasks.isEmpty) return 0;
    final done = subTasks.where((item) => item.isDone).length;
    return done / subTasks.length;
  }
}

class AppSettings {
  AppSettings({
    this.notificationsEnabled = true,
    this.vibrationEnabled = true,
    this.vibrationPattern = 'Standard',
    this.alarmSound = 'Gentle bell',
    this.notificationPriority = 'High',
    this.snoozeMinutes = 10,
    this.defaultCalendar = CalendarSystem.ethiopian,
  });

  bool notificationsEnabled;
  bool vibrationEnabled;
  String vibrationPattern;
  String alarmSound;
  String notificationPriority;
  int snoozeMinutes;
  CalendarSystem defaultCalendar;
}
