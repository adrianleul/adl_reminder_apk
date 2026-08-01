import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

enum ReminderPermissionIssue { notifications, exactAlarms }

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _settingsChannel = MethodChannel(
    'et.adlreminder.adl_reminder/settings',
  );
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, int> _scheduledCounts = {};
  bool _initialized = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // tz.local remains a safe fallback if a platform timezone is unavailable.
    }

    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'adl_reminders',
          'Reminders',
          description: 'Notifications for scheduled tasks',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'adl_alarms',
          'Alarms',
          description: 'Full-screen alarms for scheduled tasks',
          importance: Importance.max,
          enableVibration: true,
        ),
      );
      _initialized = true;
    } on MissingPluginException {
      // Allows widget tests and unsupported platforms to use the app UI.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<ReminderPermissionIssue?> permissionIssue({
    bool requireExactAlarm = false,
  }) async {
    if (!_isAndroid) return null;
    await initialize();
    try {
      if (await _android?.areNotificationsEnabled() == false) {
        return ReminderPermissionIssue.notifications;
      }
      if (requireExactAlarm &&
          await _android?.canScheduleExactNotifications() == false) {
        return ReminderPermissionIssue.exactAlarms;
      }
    } on MissingPluginException {
      return null;
    }
    return null;
  }

  Future<ReminderPermissionIssue?> requestPermissions({
    bool requireExactAlarm = false,
  }) async {
    if (!_isAndroid) return null;
    await initialize();
    try {
      final notificationAllowed = await _android
          ?.requestNotificationsPermission();
      if (notificationAllowed == false) {
        return ReminderPermissionIssue.notifications;
      }
      if (requireExactAlarm) {
        final exactAllowed = await _android?.requestExactAlarmsPermission();
        if (exactAllowed == false) {
          return ReminderPermissionIssue.exactAlarms;
        }
        await _android?.requestFullScreenIntentPermission();
      }
    } on MissingPluginException {
      return null;
    }
    return permissionIssue(requireExactAlarm: requireExactAlarm);
  }

  Future<void> openPermissionSettings(ReminderPermissionIssue issue) async {
    if (!_isAndroid) return;
    try {
      await _settingsChannel.invokeMethod<void>(
        issue == ReminderPermissionIssue.exactAlarms
            ? 'openExactAlarmSettings'
            : 'openNotificationSettings',
      );
    } on PlatformException {
      await _settingsChannel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // No system settings screen is available in tests/unsupported platforms.
    }
  }

  Future<bool> scheduleTask(ReminderTask task) async {
    await initialize();
    if (await permissionIssue(
          requireExactAlarm: task.schedule.delivery == ReminderDelivery.alarm,
        ) !=
        null) {
      return false;
    }

    try {
      await cancelTask(task);
      final occurrences = _occurrences(task.schedule);
      for (var index = 0; index < occurrences.length; index++) {
        final occurrence = occurrences[index];
        await _notifications.zonedSchedule(
          id: _notificationId(task.id, index),
          title: task.title,
          body: task.subTasks.isEmpty
              ? 'Reminder due now'
              : '${task.subTasks.length} tasks to complete',
          scheduledDate: occurrence.date,
          notificationDetails: _details(task.schedule.delivery),
          androidScheduleMode: task.schedule.delivery == ReminderDelivery.alarm
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: occurrence.match,
          payload: task.id,
        );
      }
      _scheduledCounts[task.id] = occurrences.length;
      return occurrences.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> scheduleTasks(Iterable<ReminderTask> tasks) async {
    for (final task in tasks) {
      if (!task.isCompleted) await scheduleTask(task);
    }
  }

  Future<void> cancelTask(ReminderTask task) async {
    await initialize();
    try {
      final count = _scheduledCounts.remove(task.id) ?? 1;
      for (var index = 0; index < count; index++) {
        await _notifications.cancel(id: _notificationId(task.id, index));
      }
    } on PlatformException {
      // The reminder remains in the app even if the platform cannot cancel it.
    } on MissingPluginException {
      // No scheduled platform notification exists in widget tests.
    }
  }

  NotificationDetails _details(ReminderDelivery delivery) {
    final isAlarm = delivery == ReminderDelivery.alarm;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isAlarm ? 'adl_alarms' : 'adl_reminders',
        isAlarm ? 'Alarms' : 'Reminders',
        channelDescription: isAlarm
            ? 'Full-screen alarms for scheduled tasks'
            : 'Notifications for scheduled tasks',
        importance: isAlarm ? Importance.max : Importance.high,
        priority: isAlarm ? Priority.max : Priority.high,
        category: isAlarm ? AndroidNotificationCategory.alarm : null,
        fullScreenIntent: isAlarm,
        enableVibration: true,
      ),
    );
  }

  List<_Occurrence> _occurrences(ReminderSchedule schedule) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime at(DateTime date) => tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      schedule.time.hour,
      schedule.time.minute,
    );

    switch (schedule.type) {
      case ReminderType.specificDate:
        if (schedule.date == null || !at(schedule.date!).isAfter(now)) {
          return [];
        }
        return [_Occurrence(at(schedule.date!))];
      case ReminderType.dateRange:
        if (schedule.date == null || schedule.endDate == null) return [];
        final result = <_Occurrence>[];
        var day = DateTime(
          schedule.date!.year,
          schedule.date!.month,
          schedule.date!.day,
        );
        final end = DateTime(
          schedule.endDate!.year,
          schedule.endDate!.month,
          schedule.endDate!.day,
        );
        while (!day.isAfter(end) && result.length < 366) {
          if (at(day).isAfter(now)) {
            result.add(_Occurrence(at(day)));
          }
          day = day.add(const Duration(days: 1));
        }
        return result;
      case ReminderType.everyday:
        var next = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          schedule.time.hour,
          schedule.time.minute,
        );
        if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
        return [_Occurrence(next, DateTimeComponents.time)];
      case ReminderType.custom:
        if (schedule.recurrenceUnit == RecurrenceUnit.weekly) {
          final result = <_Occurrence>[];
          final start = schedule.date == null ? now : at(schedule.date!);
          final base = start.isAfter(now) ? start : now;
          for (final weekday in schedule.weekdays) {
            final daysAhead = (weekday - base.weekday) % 7;
            var next = tz.TZDateTime(
              tz.local,
              base.year,
              base.month,
              base.day + daysAhead,
              schedule.time.hour,
              schedule.time.minute,
            );
            if (!next.isAfter(now) || next.isBefore(start)) {
              next = next.add(const Duration(days: 7));
            }
            result.add(_Occurrence(next, DateTimeComponents.dayOfWeekAndTime));
          }
          return result;
        }
        if (schedule.date == null) return [];
        var next = at(schedule.date!);
        final match = schedule.recurrenceUnit == RecurrenceUnit.monthly
            ? DateTimeComponents.dayOfMonthAndTime
            : DateTimeComponents.dateAndTime;
        while (!next.isAfter(now)) {
          next = schedule.recurrenceUnit == RecurrenceUnit.monthly
              ? tz.TZDateTime(
                  tz.local,
                  next.month == 12 ? next.year + 1 : next.year,
                  next.month == 12 ? 1 : next.month + 1,
                  schedule.date!.day,
                  schedule.time.hour,
                  schedule.time.minute,
                )
              : tz.TZDateTime(
                  tz.local,
                  next.year + 1,
                  schedule.date!.month,
                  schedule.date!.day,
                  schedule.time.hour,
                  schedule.time.minute,
                );
        }
        return [_Occurrence(next, match)];
    }
  }

  int _notificationId(String taskId, int index) =>
      (Object.hash(taskId, index) & 0x3fffffff);
}

class _Occurrence {
  const _Occurrence(this.date, [this.match]);

  final tz.TZDateTime date;
  final DateTimeComponents? match;
}
