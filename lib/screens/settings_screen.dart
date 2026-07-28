import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SettingsSection(
                title: 'Notifications',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notifications'),
                    subtitle: const Text('Allow reminders to alert you.'),
                    value: settings.notificationsEnabled,
                    onChanged: (value) => controller.updateSettings(
                      () => settings.notificationsEnabled = value,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: const Text('Alarm sound'),
                    subtitle: Text(settings.alarmSound),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectString(
                      context,
                      title: 'Alarm sound',
                      values: const [
                        'Gentle bell',
                        'Digital alarm',
                        'Soft chime',
                        'Classic reminder',
                        'Silent',
                      ],
                      selected: settings.alarmSound,
                      onSelected: (value) => controller.updateSettings(
                        () => settings.alarmSound = value,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.priority_high),
                    title: const Text('Notification priority'),
                    subtitle: Text(settings.notificationPriority),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectString(
                      context,
                      title: 'Notification priority',
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
                title: 'Vibration',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration),
                    title: const Text('Vibrate'),
                    subtitle: const Text('Vibrate when a reminder fires.'),
                    value: settings.vibrationEnabled,
                    onChanged: (value) => controller.updateSettings(
                      () => settings.vibrationEnabled = value,
                    ),
                  ),
                  ListTile(
                    enabled: settings.vibrationEnabled,
                    leading: const Icon(Icons.graphic_eq),
                    title: const Text('Vibration pattern'),
                    subtitle: Text(settings.vibrationPattern),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: settings.vibrationEnabled
                        ? () => _selectString(
                              context,
                              title: 'Vibration pattern',
                              values: const [
                                'Short',
                                'Standard',
                                'Long',
                                'Pulse',
                              ],
                              selected: settings.vibrationPattern,
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
                title: 'Reminder defaults',
                children: [
                  ListTile(
                    leading: const Icon(Icons.snooze),
                    title: const Text('Default snooze'),
                    subtitle: Text('${settings.snoozeMinutes} minutes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectInt(
                      context,
                      title: 'Default snooze',
                      values: const [5, 10, 15, 30, 60],
                      selected: settings.snoozeMinutes,
                      onSelected: (value) => controller.updateSettings(
                        () => settings.snoozeMinutes = value,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Default calendar'),
                    subtitle: Text(
                      settings.defaultCalendar == CalendarSystem.ethiopian
                          ? 'Ethiopian'
                          : 'Gregorian',
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
                              title: const Text('Ethiopian calendar'),
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
                              title: const Text('Gregorian calendar'),
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
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            for (final item in values)
              RadioListTile<String>(
                value: item,
                groupValue: selected,
                title: Text(item),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) onSelected(value);
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
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            for (final item in values)
              RadioListTile<int>(
                value: item,
                groupValue: selected,
                title: Text('$item minutes'),
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
