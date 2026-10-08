import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models.dart';

enum ReminderPermissionIssue { notifications, exactAlarms }

const String doneActionId = 'done';
const String snoozeActionId = 'snooze';

/// Schedules and cancels the platform reminders for tasks. The controller
/// talks to this interface so tests can verify scheduling without a device.
abstract class ReminderScheduler {
  /// Replaces every reminder of [task] with ones matching its current state.
  Future<void> syncTask(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n,
  );

  /// Rebuilds all reminders and removes ones that belong to no task.
  Future<void> syncAll(
    List<ReminderTask> tasks,
    AppSettings settings,
    AppLocalizations l10n,
  );

  Future<void> cancelTask(ReminderTask task);

  Future<void> cancelAll(List<ReminderTask> tasks);
}

/// One platform notification to schedule.
class PlannedOccurrence {
  const PlannedOccurrence(this.at, [this.repeat]);

  final DateTime at;

  /// Set for reminders the platform repeats on its own.
  final DateTimeComponents? repeat;
}

/// Each task owns [slotsPerTask] consecutive notification IDs starting at
/// `notificationId * slotsPerTask`. The last slot is reserved for snoozes.
const int slotsPerTask = 32;
const int snoozeSlot = slotsPerTask - 1;

int notificationIdFor(ReminderTask task, int slot) =>
    task.notificationId * slotsPerTask + slot;

/// Works out which notifications to schedule for [schedule], starting after
/// [from]. Daily and weekly reminders repeat on the platform. Monthly, yearly
/// and date-range reminders are scheduled one by one, a rolling window ahead,
/// because the platform cannot express "last day of the month" or Ethiopian
/// months. The window is topped up every time the app starts or resumes.
List<PlannedOccurrence> planOccurrences(
  ReminderSchedule schedule,
  DateTime from,
) {
  switch (schedule.type) {
    case ReminderType.everyday:
      final next = schedule.nextOccurrenceAfter(from);
      return [
        if (next != null) PlannedOccurrence(next, DateTimeComponents.time),
      ];
    case ReminderType.specificDate:
      return [
        for (final at in schedule.occurrencesAfter(from, limit: 1))
          PlannedOccurrence(at),
      ];
    case ReminderType.dateRange:
      return [
        for (final at in schedule.occurrencesAfter(from, limit: 21))
          PlannedOccurrence(at),
      ];
    case ReminderType.custom:
      switch (schedule.recurrenceUnit) {
        case RecurrenceUnit.weekly:
          final result = <PlannedOccurrence>[];
          for (final weekday in schedule.weekdays) {
            final single = ReminderSchedule(
              type: ReminderType.custom,
              calendarSystem: schedule.calendarSystem,
              time: schedule.time,
              date: schedule.date,
              recurrenceUnit: RecurrenceUnit.weekly,
              weekdays: {weekday},
            );
            final next = single.nextOccurrenceAfter(from);
            if (next != null) {
              result.add(
                PlannedOccurrence(next, DateTimeComponents.dayOfWeekAndTime),
              );
            }
          }
          result.sort((a, b) => a.at.compareTo(b.at));
          return result;
        case RecurrenceUnit.monthly:
          return [
            for (final at in schedule.occurrencesAfter(from, limit: 6))
              PlannedOccurrence(at),
          ];
        case RecurrenceUnit.yearly:
          return [
            for (final at in schedule.occurrencesAfter(from, limit: 3))
              PlannedOccurrence(at),
          ];
        case null:
          return const [];
      }
  }
}

/// Everything needed to rebuild a notification, including from the background
/// isolate that handles "Snooze" while the app is closed.
class _NotificationSpec {
  const _NotificationSpec({
    required this.taskId,
    required this.baseId,
    required this.alarm,
    required this.title,
    required this.body,
    required this.snoozeMinutes,
    required this.priority,
    required this.sound,
    required this.vibration,
    required this.channelName,
    required this.channelDescription,
    required this.doneLabel,
    required this.snoozeLabel,
  });

  factory _NotificationSpec.fromJson(Map<String, Object?> json) =>
      _NotificationSpec(
        taskId: json['taskId']! as String,
        baseId: json['baseId']! as int,
        alarm: json['alarm']! as bool,
        title: json['title']! as String,
        body: json['body']! as String,
        snoozeMinutes: json['snooze']! as int,
        priority: NotificationPriority.values.byName(
          json['priority']! as String,
        ),
        sound: BuiltInSound.values.byName(json['sound']! as String),
        vibration: VibrationPatternOption.values
            .where((value) => value.name == json['vibration'])
            .firstOrNull,
        channelName: json['channelName']! as String,
        channelDescription: json['channelDescription']! as String,
        doneLabel: json['doneLabel']! as String,
        snoozeLabel: json['snoozeLabel']! as String,
      );

  final String taskId;
  final int baseId;
  final bool alarm;
  final String title;
  final String body;
  final int snoozeMinutes;
  final NotificationPriority priority;

  /// The sound the platform plays. Custom files only play on the in-app alarm
  /// screen, so they fall back to a built-in sound here.
  final BuiltInSound sound;

  /// Null when vibration is off.
  final VibrationPatternOption? vibration;
  final String channelName;
  final String channelDescription;
  final String doneLabel;
  final String snoozeLabel;

  /// Channel settings are fixed once Android creates a channel, so every
  /// combination of sound, vibration and priority gets its own channel.
  String get channelId {
    final vibrationKey = vibration?.name ?? 'none';
    return alarm
        ? 'alarm_${sound.name}_$vibrationKey'
        : 'reminder_${priority.name}_${sound.name}_$vibrationKey';
  }

  Importance get importance => alarm
      ? Importance.max
      : switch (priority) {
          NotificationPriority.low => Importance.low,
          NotificationPriority.normal => Importance.defaultImportance,
          NotificationPriority.high => Importance.high,
          NotificationPriority.urgent => Importance.max,
        };

  Priority get androidPriority => alarm
      ? Priority.max
      : switch (priority) {
          NotificationPriority.low => Priority.low,
          NotificationPriority.normal => Priority.defaultPriority,
          NotificationPriority.high => Priority.high,
          NotificationPriority.urgent => Priority.max,
        };

  AndroidNotificationSound? get androidSound => switch (sound) {
    BuiltInSound.systemAlarm => const UriAndroidNotificationSound(
      'content://settings/system/alarm_alert',
    ),
    _ => null,
  };

  Int64List? get vibrationPattern => vibration == null
      ? null
      : Int64List.fromList(vibrationTimings(vibration!));

  AudioAttributesUsage get audioUsage =>
      alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification;

  AndroidNotificationChannel get channel => AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: importance,
    playSound: sound != BuiltInSound.silent,
    sound: androidSound,
    enableVibration: vibration != null,
    vibrationPattern: vibrationPattern,
    audioAttributesUsage: audioUsage,
  );

  NotificationDetails get details => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: androidPriority,
      // Brand orange behind the small icon and on the action buttons.
      color: const Color(0xFFFF6A2B),
      category: alarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      fullScreenIntent: alarm,
      playSound: sound != BuiltInSound.silent,
      sound: androidSound,
      enableVibration: vibration != null,
      vibrationPattern: vibrationPattern,
      audioAttributesUsage: audioUsage,
      // FLAG_INSISTENT: an alarm keeps sounding until the user responds.
      additionalFlags: alarm ? Int32List.fromList(const [4]) : null,
      actions: [
        AndroidNotificationAction(
          doneActionId,
          doneLabel,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(snoozeActionId, snoozeLabel),
      ],
    ),
  );

  String get payload => jsonEncode({
    'taskId': taskId,
    'baseId': baseId,
    'alarm': alarm,
    'title': title,
    'body': body,
    'snooze': snoozeMinutes,
    'priority': priority.name,
    'sound': sound.name,
    'vibration': vibration?.name,
    'channelName': channelName,
    'channelDescription': channelDescription,
    'doneLabel': doneLabel,
    'snoozeLabel': snoozeLabel,
  });
}

/// Reads the task ID and delivery type from a notification payload.
({String taskId, bool alarm})? parseNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final json = jsonDecode(payload);
    if (json is Map<String, Object?> && json['taskId'] is String) {
      return (taskId: json['taskId']! as String, alarm: json['alarm'] == true);
    }
  } on FormatException {
    // Payloads written by older versions were the bare task ID.
  }
  return (taskId: payload, alarm: false);
}

/// Handles notification actions that do not open the app (Snooze) when the
/// app is not running. Runs on a background isolate.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
  NotificationResponse response,
) async {
  if (response.actionId == snoozeActionId) {
    await NotificationService.instance.snooze(response.payload);
  }
}

class NotificationService implements ReminderScheduler {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _settingsChannel = MethodChannel(
    'et.adlreminder.adl_reminder/settings',
  );
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationResponse> _responses =
      StreamController<NotificationResponse>.broadcast();
  final Set<String> _createdChannels = {};
  bool _initialized = false;
  Future<void>? _initializing;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Taps on notifications and the "Done" action while the app is running.
  Stream<NotificationResponse> get responses => _responses.stream;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // tz.local stays UTC. Absolute times are still correct because every
      // scheduled date is converted from the device's local DateTime.
    }

    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
      );
      _initialized = true;
    } catch (error) {
      // Tests and unsupported platforms have no notification plugin
      // (MissingPluginException, or no platform instance registered).
      debugPrint('Notifications unavailable: $error');
    }
  }

  void _handleResponse(NotificationResponse response) {
    if (response.actionId == snoozeActionId) {
      unawaited(snooze(response.payload));
      return;
    }
    _responses.add(response);
  }

  /// The notification tap or full-screen alarm that launched the app, if any.
  Future<NotificationResponse?> takeLaunchResponse() async {
    await initialize();
    if (!_initialized) return null;
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details!.notificationResponse;
      }
    } on MissingPluginException {
      return null;
    }
    return null;
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

  _NotificationSpec _specFor(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final alarm = task.schedule.delivery == ReminderDelivery.alarm;
    final customSelected = settings.selectedCustomSound != null;
    final sound = customSelected
        ? (alarm ? BuiltInSound.systemAlarm : BuiltInSound.systemDefault)
        : settings.builtInSound;
    return _NotificationSpec(
      taskId: task.id,
      baseId: task.notificationId * slotsPerTask,
      alarm: alarm,
      title: task.title,
      body: task.subTasks.isEmpty
          ? l10n.text('notificationBody')
          : l10n.text('notificationBodySubtasks', {
              'count': task.subTasks.length,
            }),
      snoozeMinutes: settings.snoozeMinutes,
      priority: settings.notificationPriority,
      sound: sound,
      vibration: settings.vibrationEnabled ? settings.vibrationPattern : null,
      channelName: l10n.text(alarm ? 'channelAlarms' : 'channelReminders'),
      channelDescription: l10n.text(
        alarm ? 'channelAlarmsHelp' : 'channelRemindersHelp',
      ),
      doneLabel: l10n.text('markDone'),
      snoozeLabel: l10n.text('snooze'),
    );
  }

  Future<void> _ensureChannel(_NotificationSpec spec) async {
    final key = '${spec.channelId}|${spec.channelName}';
    if (_createdChannels.contains(key)) return;
    await _android?.createNotificationChannel(spec.channel);
    _createdChannels.add(key);
  }

  /// Deletes channels left over from earlier settings or app versions, so the
  /// system settings screen only lists the channels in use.
  Future<void> _removeStaleChannels(Set<String> inUse) async {
    final channels = await _android?.getNotificationChannels() ?? const [];
    for (final channel in channels) {
      final ours =
          channel.id.startsWith('alarm_') ||
          channel.id.startsWith('reminder_') ||
          channel.id.startsWith('adl_');
      if (ours && !inUse.contains(channel.id)) {
        await _android?.deleteNotificationChannel(channelId: channel.id);
      }
    }
  }

  Future<bool> _canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  Future<bool> _schedule(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n,
  ) async {
    if (!settings.notificationsEnabled) return false;
    final now = DateTime.now();
    final completed = task.isCompletedAt(now);
    if (completed && !task.schedule.isRecurring) return false;
    final spec = _specFor(task, settings, l10n);
    if (await permissionIssue(requireExactAlarm: spec.alarm) != null) {
      return false;
    }

    // A recurring task finished for today resumes with the next occurrence.
    final from = completed
        ? DateTime(now.year, now.month, now.day, 23, 59, 59)
        : now;
    final occurrences = planOccurrences(task.schedule, from);
    if (occurrences.isEmpty) return false;

    await _ensureChannel(spec);
    final mode = await _canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (var slot = 0; slot < occurrences.length && slot < snoozeSlot; slot++) {
      final occurrence = occurrences[slot];
      await _notifications.zonedSchedule(
        id: spec.baseId + slot,
        title: spec.title,
        body: spec.body,
        scheduledDate: tz.TZDateTime.from(occurrence.at, tz.local),
        notificationDetails: spec.details,
        androidScheduleMode: mode,
        matchDateTimeComponents: occurrence.repeat,
        payload: spec.payload,
      );
    }
    return true;
  }

  @override
  Future<void> syncTask(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n,
  ) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _cancelSlots(task);
      await _schedule(task, settings, l10n);
    } on PlatformException catch (error) {
      debugPrint('Could not schedule ${task.id}: $error');
    } on MissingPluginException {
      // Not available in widget tests.
    }
  }

  @override
  Future<void> syncAll(
    List<ReminderTask> tasks,
    AppSettings settings,
    AppLocalizations l10n,
  ) async {
    await initialize();
    if (!_initialized) return;
    try {
      // Keep pending snoozes of unfinished tasks; drop everything else,
      // including reminders of deleted tasks and of older app versions.
      final now = DateTime.now();
      final keep = {
        if (settings.notificationsEnabled)
          for (final task in tasks)
            if (!task.isCompletedAt(now)) notificationIdFor(task, snoozeSlot),
      };
      for (final request
          in await _notifications.pendingNotificationRequests()) {
        if (!keep.contains(request.id)) {
          await _notifications.cancel(id: request.id);
        }
      }
      final channelsInUse = <String>{};
      for (final task in tasks) {
        channelsInUse.add(_specFor(task, settings, l10n).channelId);
        await _schedule(task, settings, l10n);
      }
      await _removeStaleChannels(channelsInUse);
    } on PlatformException catch (error) {
      debugPrint('Could not refresh reminders: $error');
    } on MissingPluginException {
      // Not available in widget tests.
    }
  }

  Future<void> _cancelSlots(ReminderTask task) async {
    for (var slot = 0; slot < slotsPerTask; slot++) {
      await _notifications.cancel(id: notificationIdFor(task, slot));
    }
  }

  @override
  Future<void> cancelTask(ReminderTask task) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _cancelSlots(task);
    } on PlatformException {
      // The reminder remains in the app even if the platform cannot cancel it.
    } on MissingPluginException {
      // No scheduled platform notification exists in widget tests.
    }
  }

  @override
  Future<void> cancelAll(List<ReminderTask> tasks) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _notifications.cancelAll();
    } on PlatformException {
      for (final task in tasks) {
        await cancelTask(task);
      }
    } on MissingPluginException {
      // Not available in widget tests.
    }
  }

  /// Shows the notification described by [payload] again after its snooze
  /// period. Safe to call from the background isolate.
  Future<void> snooze(String? payload) async {
    if (payload == null) return;
    final _NotificationSpec spec;
    try {
      spec = _NotificationSpec.fromJson(
        (jsonDecode(payload) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return;
    }
    await initialize();
    if (!_initialized) return;
    try {
      await _ensureChannel(spec);
      // Use UTC so the background isolate does not need the device timezone.
      final at = tz.TZDateTime.now(
        tz.UTC,
      ).add(Duration(minutes: spec.snoozeMinutes));
      await _notifications.zonedSchedule(
        id: spec.baseId + snoozeSlot,
        title: spec.title,
        body: spec.body,
        scheduledDate: at,
        notificationDetails: spec.details,
        androidScheduleMode: await _canScheduleExact()
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: spec.payload,
      );
    } on PlatformException catch (error) {
      debugPrint('Could not snooze: $error');
    } on MissingPluginException {
      // Not available in widget tests.
    }
  }

  /// Snoozes [task] from inside the app (alarm screen).
  Future<void> snoozeTask(
    ReminderTask task,
    AppSettings settings,
    AppLocalizations l10n, {
    int? minutes,
  }) {
    final spec = _specFor(task, settings, l10n);
    if (minutes == null) return snooze(spec.payload);
    final payload = (jsonDecode(spec.payload) as Map<String, Object?>)
      ..['snooze'] = minutes;
    return snooze(jsonEncode(payload));
  }

  /// Removes the notification currently shown for [task], which also stops an
  /// insistent alarm sound.
  Future<void> dismissShown(ReminderTask task) async {
    if (!_initialized) return;
    try {
      final active = await _notifications.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id != null && id ~/ slotsPerTask == task.notificationId) {
          await _notifications.cancel(id: id);
        }
      }
    } on PlatformException {
      // Nothing to dismiss.
    } on MissingPluginException {
      // Not available in widget tests.
    }
  }
}
