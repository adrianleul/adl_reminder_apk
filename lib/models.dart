import 'package:flutter/material.dart';

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

class TaskStatusSummary {
  const TaskStatusSummary({this.done = 0, this.overdue = 0, this.undone = 0});

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
  TaskCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  String name;
  final IconData icon;
  final Color color;
}

class SubTask {
  SubTask({required this.id, required this.title, this.isDone = false});

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
    this.endDate,
    this.ethiopianDate,
    this.ethiopianEndDate,
    this.recurrenceUnit,
    this.weekdays = const <int>{},
    this.delivery = ReminderDelivery.notification,
  });

  final ReminderType type;
  final CalendarSystem calendarSystem;
  final TimeOfDay time;
  final DateTime? date;
  final DateTime? endDate;
  final EthiopianDateValue? ethiopianDate;
  final EthiopianDateValue? ethiopianEndDate;
  final RecurrenceUnit? recurrenceUnit;
  final Set<int> weekdays;
  final ReminderDelivery delivery;

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

  DateTime? get firstOccurrence {
    if (date == null) return null;
    return DateTime(date!.year, date!.month, date!.day, time.hour, time.minute);
  }

  DateTime? get deadline {
    final value = type == ReminderType.dateRange ? endDate : date;
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day, time.hour, time.minute);
  }

  bool occursOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final start = date == null
        ? null
        : DateTime(date!.year, date!.month, date!.day);
    return switch (type) {
      ReminderType.specificDate => start == target,
      ReminderType.dateRange =>
        start != null &&
            endDate != null &&
            !target.isBefore(start) &&
            !target.isAfter(
              DateTime(endDate!.year, endDate!.month, endDate!.day),
            ),
      ReminderType.everyday => true,
      ReminderType.custom => switch (recurrenceUnit) {
        RecurrenceUnit.weekly => weekdays.contains(target.weekday),
        RecurrenceUnit.monthly => start?.day == target.day,
        RecurrenceUnit.yearly =>
          start?.month == target.month && start?.day == target.day,
        null => false,
      },
    };
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

  DateTime? get dueAt => schedule.deadline;

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
  String? alarmSoundPath;
  final List<CustomAlarmSound> customAlarmSounds = [];
  String notificationPriority;
  int snoozeMinutes;
  CalendarSystem defaultCalendar;
}

class CustomAlarmSound {
  const CustomAlarmSound({
    required this.id,
    required this.name,
    required this.path,
  });

  final String id;
  final String name;
  final String path;
}
