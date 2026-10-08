import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/alarm_sound_picker.dart';
import '../widgets/logo_mark.dart';
import '../widgets/ui.dart';

String priorityLabel(AppLocalizations l10n, NotificationPriority value) =>
    l10n.text(switch (value) {
      NotificationPriority.low => 'priorityLow',
      NotificationPriority.normal => 'priorityNormal',
      NotificationPriority.high => 'priorityHigh',
      NotificationPriority.urgent => 'priorityUrgent',
    });

String vibrationPatternLabel(
  AppLocalizations l10n,
  VibrationPatternOption value,
) => l10n.text(switch (value) {
  VibrationPatternOption.short => 'patternShort',
  VibrationPatternOption.standard => 'patternStandard',
  VibrationPatternOption.long => 'patternLong',
  VibrationPatternOption.pulse => 'patternPulse',
});

String builtInSoundLabel(AppLocalizations l10n, BuiltInSound value) =>
    l10n.text(switch (value) {
      BuiltInSound.systemDefault => 'soundSystemDefault',
      BuiltInSound.systemAlarm => 'soundSystemAlarm',
      BuiltInSound.silent => 'soundSilent',
    });

/// The Settings tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  static const List<int> snoozeOptions = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = controller.settings;
    final enabled = settings.notificationsEnabled;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text(l10n.text('settings'), style: displayStyle(34)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ToggleTile(
                  icon: Icons.notifications_none,
                  title: l10n.text('notifications'),
                  value: enabled,
                  onChanged: (value) =>
                      _setNotificationsEnabled(context, value: value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleTile(
                  icon: Icons.vibration,
                  title: l10n.text('vibrate'),
                  value: settings.vibrationEnabled,
                  subtitle: settings.vibrationEnabled
                      ? vibrationPatternLabel(l10n, settings.vibrationPattern)
                      : null,
                  onChanged: enabled
                      ? (value) => controller.updateSettings(
                          () => settings.vibrationEnabled = value,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              _RowButton(
                title: l10n.text('alarmSound'),
                value:
                    settings.selectedCustomSound?.name ??
                    builtInSoundLabel(l10n, settings.builtInSound),
                onTap: enabled
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => FractionallySizedBox(
                          heightFactor: 0.85,
                          child: AlarmSoundPicker(controller: controller),
                        ),
                      )
                    : null,
              ),
              _RowButton(
                title: l10n.text('priority'),
                value: priorityLabel(l10n, settings.notificationPriority),
                onTap: enabled
                    ? () => _selectPriority(context, l10n, settings)
                    : null,
              ),
              if (settings.vibrationEnabled)
                _Labeled(
                  title: l10n.text('vibrationPattern'),
                  child: PillGroup<VibrationPatternOption>(
                    expand: true,
                    background: AppColors.background,
                    options: [
                      for (final pattern in VibrationPatternOption.values)
                        PillOption(
                          pattern,
                          vibrationPatternLabel(l10n, pattern),
                        ),
                    ],
                    selected: settings.vibrationPattern,
                    onSelected: (value) {
                      _previewVibration(value);
                      controller.updateSettings(
                        () => settings.vibrationPattern = value,
                      );
                    },
                  ),
                ),
              _Labeled(
                title: l10n.text('defaultSnooze'),
                footer: l10n.text('minutes', {'count': settings.snoozeMinutes}),
                child: PillGroup<int>(
                  expand: true,
                  selectedColor: AppColors.accent,
                  selectedTextColor: AppColors.ink,
                  options: [
                    for (final minutes in snoozeOptions)
                      PillOption(minutes, '$minutes'),
                  ],
                  selected: settings.snoozeMinutes,
                  onSelected: (value) => controller.updateSettings(
                    () => settings.snoozeMinutes = value,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              _Labeled(
                title: l10n.text('languageAndCalendar'),
                child: Column(
                  children: [
                    PillGroup<AppLanguage>(
                      expand: true,
                      options: [
                        // Each language is named in itself, so it can be
                        // found whichever one is active.
                        const PillOption(AppLanguage.english, 'English'),
                        const PillOption(AppLanguage.amharic, 'አማርኛ'),
                      ],
                      selected: controller.language,
                      onSelected: controller.setLanguage,
                    ),
                    const SizedBox(height: 6),
                    PillGroup<CalendarSystem>(
                      expand: true,
                      options: [
                        PillOption(
                          CalendarSystem.ethiopian,
                          l10n.text('ethiopian'),
                        ),
                        PillOption(
                          CalendarSystem.gregorian,
                          l10n.text('gregorian'),
                        ),
                      ],
                      selected: settings.defaultCalendar,
                      onSelected: (value) => controller.updatePreferences(
                        () => settings.defaultCalendar = value,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoMark(size: 36),
              const SizedBox(width: 10),
              Text(l10n.text('appName'), style: displayStyle(18)),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              l10n.text('tagline'),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPriority(
    BuildContext context,
    AppLocalizations l10n,
    AppSettings settings,
  ) async {
    final value = await showModalBottomSheet<NotificationPriority>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<NotificationPriority>(
          groupValue: settings.notificationPriority,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.text('priority'), style: displayStyle(22)),
                ),
              ),
              for (final priority in NotificationPriority.values)
                RadioListTile<NotificationPriority>(
                  value: priority,
                  title: Text(priorityLabel(l10n, priority)),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (value != null && value != settings.notificationPriority) {
      controller.updateSettings(() => settings.notificationPriority = value);
    }
  }

  Future<void> _setNotificationsEnabled(
    BuildContext context, {
    required bool value,
  }) async {
    final settings = controller.settings;
    if (!value) {
      // Turning off cancels every reminder (handled by updateSettings).
      controller.updateSettings(() => settings.notificationsEnabled = false);
      return;
    }
    final issue = await NotificationService.instance.requestPermissions();
    if (!context.mounted) return;
    // Turning on reschedules every unfinished reminder.
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

  void _previewVibration(VibrationPatternOption pattern) {
    unawaited(() async {
      try {
        await Vibration.cancel();
        await Vibration.vibrate(pattern: vibrationTimings(pattern));
      } catch (_) {
        // No vibrator (or tests).
      }
    }());
  }
}

/// A big square switch tile: black when on.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final bool value;
  final String? subtitle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final foreground = value ? Colors.white : AppColors.ink;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: Material(
        color: value ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Container(
            height: 112,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                Text(
                  subtitle ?? l10n.text(value ? 'on' : 'off'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: value ? AppColors.mutedOnInk : AppColors.muted,
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

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(height: 1),
            child,
          ],
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({required this.title, required this.value, this.onTap});

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.title, required this.child, this.footer});

  final String title;
  final Widget child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(
              footer!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
