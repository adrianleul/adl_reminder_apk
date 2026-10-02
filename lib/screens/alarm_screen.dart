import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/device_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';

/// Shown when an alarm reminder fires (full-screen intent) or is tapped.
/// Plays the chosen sound, including custom recordings, until the user acts.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.controller, required this.task});

  final AppController controller;
  final ReminderTask task;

  /// Stop ringing on its own after this long, like a phone alarm.
  static const Duration ringTimeout = Duration(minutes: 5);

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _timeout;

  AppSettings get _settings => widget.controller.settings;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // Removing the notification stops its insistent sound so only this
    // screen rings; then restore the task's upcoming reminders.
    await NotificationService.instance.dismissShown(widget.task);
    widget.controller.rescheduleTask(widget.task);
    _timeout = Timer(AlarmScreen.ringTimeout, _stopRinging);

    final custom = _settings.selectedCustomSound;
    try {
      if (custom != null) {
        await _player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
          ),
        );
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(DeviceFileSource(custom.path));
      } else {
        await DeviceService.instance.playSystemSound(
          _settings.builtInSound,
          loop: true,
        );
      }
    } catch (_) {
      // Fall back to the system alarm tone if the custom file is unusable.
      await DeviceService.instance.playSystemSound(
        BuiltInSound.systemAlarm,
        loop: true,
      );
    }
    if (_settings.vibrationEnabled) {
      try {
        await Vibration.vibrate(
          pattern: [...vibrationTimings(_settings.vibrationPattern), 800],
          repeat: 0,
        );
      } catch (_) {
        // No vibrator.
      }
    }
  }

  Future<void> _stopRinging() async {
    _timeout?.cancel();
    try {
      await _player.stop();
    } catch (_) {
      // Player was never started.
    }
    await DeviceService.instance.stopSystemSound();
    try {
      await Vibration.cancel();
    } catch (_) {
      // No vibrator.
    }
  }

  @override
  void dispose() {
    unawaited(_stopRinging());
    _player.dispose();
    unawaited(DeviceService.instance.setShowWhenLocked(false));
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  // Each action records its result first and stops the sound without
  // waiting, so a stalled audio player can never lose the user's choice.
  void _done() {
    widget.controller.setTaskCompleted(widget.task, true);
    unawaited(_stopRinging());
    _close();
  }

  void _snooze(int minutes) {
    unawaited(
      NotificationService.instance.snoozeTask(
        widget.task,
        _settings,
        widget.controller.l10n,
        minutes: minutes,
      ),
    );
    unawaited(_stopRinging());
    _close();
  }

  void _dismiss() {
    unawaited(_stopRinging());
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final task = widget.task;
    final category = widget.controller.categoryById(task.categoryId);
    final time = task.schedule.time;
    String two(int value) => value.toString().padLeft(2, '0');
    final ethiopian = gregorianToEthiopian(DateTime.now());
    // Offer the user's default snooze alongside the usual choices.
    final snoozeChoices = {5, _settings.snoozeMinutes, 30}.toList()..sort();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_stopRinging());
      },
      child: Scaffold(
        backgroundColor: AppColors.accent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          l10n.text('alarm'),
                          if (category != null) category.name,
                        ].join(' · ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      '${ethiopianMonthName(l10n, ethiopian.month)} '
                      '${ethiopian.day}, ${ethiopian.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Semantics(
                  label: MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(time),
                  excludeSemantics: true,
                  child: Text(
                    '${two(time.hour)}\n${two(time.minute)}',
                    style: displayStyle(
                      120,
                    ).copyWith(height: 0.9, letterSpacing: -6),
                  ),
                ),
                const SizedBox(height: 32),
                Text(task.title, style: displayStyle(34)),
                const SizedBox(height: 10),
                Text(
                  formatTaskSchedule(task.schedule, context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: bodyFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _done,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.text('markDone')),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (index, minutes) in snoozeChoices.indexed)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 10),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: 2,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => _snooze(minutes),
                            child: Text(
                              l10n.text('snoozeShort', {'count': minutes}),
                              semanticsLabel:
                                  '${l10n.text('snooze')} '
                                  '${l10n.text('minutes', {'count': minutes})}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(
                      l10n.text('dismiss'),
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
