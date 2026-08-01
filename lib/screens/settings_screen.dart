import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/notification_service.dart';
import '../widgets/alarm_sound_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('settings'))),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SettingsSection(
                title: context.l10n.text('notifications'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(context.l10n.text('notifications')),
                    subtitle: Text(context.l10n.text('notificationsHelp')),
                    value: settings.notificationsEnabled,
                    onChanged: (value) => _setNotificationsEnabled(
                      context,
                      value: value,
                      settings: settings,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: Text(context.l10n.text('alarmSound')),
                    subtitle: Text(settings.alarmSound),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (context) => FractionallySizedBox(
                        heightFactor: 0.85,
                        child: AlarmSoundPicker(controller: controller),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.priority_high),
                    title: Text(context.l10n.text('priority')),
                    subtitle: Text(settings.notificationPriority),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectString(
                      context,
                      title: context.l10n.text('priority'),
                      values: const ['Low', 'Default', 'High', 'Urgent'],
                      selected: settings.notificationPriority,
                      onSelected: (value) => controller.updateSettings(
                        () => settings.notificationPriority = value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: context.l10n.text('vibration'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration),
                    title: Text(context.l10n.text('vibrate')),
                    subtitle: Text(context.l10n.text('vibrateHelp')),
                    value: settings.vibrationEnabled,
                    onChanged: (value) => controller.updateSettings(
                      () => settings.vibrationEnabled = value,
                    ),
                  ),
                  ListTile(
                    enabled: settings.vibrationEnabled,
                    leading: const Icon(Icons.graphic_eq),
                    title: Text(context.l10n.text('vibrationPattern')),
                    subtitle: Text(settings.vibrationPattern),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: settings.vibrationEnabled
                        ? () => _selectString(
                            context,
                            title: context.l10n.text('vibrationPattern'),
                            values: const [
                              'Short',
                              'Standard',
                              'Long',
                              'Pulse',
                            ],
                            selected: settings.vibrationPattern,
                            onPreview: _previewVibration,
                            onSelected: (value) => controller.updateSettings(
                              () => settings.vibrationPattern = value,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: context.l10n.text('reminderDefaults'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.snooze),
                    title: Text(context.l10n.text('defaultSnooze')),
                    subtitle: Text(
                      context.l10n.text('minutes', {
                        'count': settings.snoozeMinutes,
                      }),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectInt(
                      context,
                      title: context.l10n.text('defaultSnooze'),
                      values: const [5, 10, 15, 30, 60],
                      selected: settings.snoozeMinutes,
                      onSelected: (value) => controller.updateSettings(
                        () => settings.snoozeMinutes = value,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(context.l10n.text('defaultCalendar')),
                    subtitle: Text(
                      settings.defaultCalendar == CalendarSystem.ethiopian
                          ? context.l10n.text('ethiopian')
                          : context.l10n.text('gregorian'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<CalendarSystem>(
                              value: CalendarSystem.ethiopian,
                              groupValue: settings.defaultCalendar,
                              title: Text(
                                context.l10n.text('ethiopianCalendar'),
                              ),
                              onChanged: (value) {
                                controller.updateSettings(
                                  () => settings.defaultCalendar = value!,
                                );
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile<CalendarSystem>(
                              value: CalendarSystem.gregorian,
                              groupValue: settings.defaultCalendar,
                              title: Text(
                                context.l10n.text('gregorianCalendar'),
                              ),
                              onChanged: (value) {
                                controller.updateSettings(
                                  () => settings.defaultCalendar = value!,
                                );
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Android notification sounds and vibration are bound to notification channels. The production implementation should create a channel per selected sound/pattern.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectString(
    BuildContext context, {
    required String title,
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
    ValueChanged<String>? onPreview,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final item in values)
              RadioListTile<String>(
                value: item,
                groupValue: selected,
                title: Text(item),
                onChanged: (value) {
                  if (value == null) return;
                  onPreview?.call(value);
                  Navigator.pop(context, value);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) onSelected(value);
  }

  Future<void> _setNotificationsEnabled(
    BuildContext context, {
    required bool value,
    required AppSettings settings,
  }) async {
    if (!value) {
      controller.updateSettings(() => settings.notificationsEnabled = false);
      for (final task in controller.tasks) {
        unawaited(NotificationService.instance.cancelTask(task));
      }
      return;
    }
    final issue = await NotificationService.instance.requestPermissions();
    if (!context.mounted) return;
    controller.updateSettings(
      () => settings.notificationsEnabled = issue == null,
    );
    if (issue != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.notifications_off_outlined),
          title: Text(context.l10n.text('permissionRequired')),
          content: Text(context.l10n.text('notificationPermissionHelp')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.text('notNow')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                NotificationService.instance.openPermissionSettings(issue);
              },
              child: Text(context.l10n.text('openSettings')),
            ),
          ],
        ),
      );
    }
  }

  void _previewVibration(String pattern) {
    unawaited(Vibration.cancel());
    final values = switch (pattern) {
      'Short' => [0, 120],
      'Standard' => [0, 180, 100, 180],
      'Long' => [0, 650],
      'Pulse' => [0, 100, 80, 100, 80, 100],
      _ => [0, 180],
    };
    unawaited(Vibration.vibrate(pattern: values));
  }

  Future<void> _selectInt(
    BuildContext context, {
    required String title,
    required List<int> values,
    required int selected,
    required ValueChanged<int> onSelected,
  }) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final item in values)
              RadioListTile<int>(
                value: item,
                groupValue: selected,
                title: Text(context.l10n.text('minutes', {'count': item})),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) onSelected(value);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
