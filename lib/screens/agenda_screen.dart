import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

/// Every reminder in the next 30 days, grouped by day in both calendars.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({
    super.key,
    required this.controller,
    required this.actions,
  });

  final AppController controller;
  final HomeActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final entries = controller.agenda(now);

    final days = <DateTime, List<({ReminderTask task, DateTime at})>>{};
    for (final entry in entries) {
      days.putIfAbsent(dateOnly(entry.at), () => []).add(entry);
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text(l10n.text('tabCalendar'), style: displayStyle(28)),
          const SizedBox(height: 2),
          Text(
            l10n.text('next30Days'),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (days.isEmpty)
            EmptyMessage(
              icon: Icons.calendar_month_outlined,
              title: l10n.text('nothingScheduled'),
              message: l10n.text('nothingNextHelp'),
            ),
          for (final day in days.entries) ...[
            _DayHeader(day: day.key, today: dateOnly(now)),
            const SizedBox(height: 6),
            for (final entry in day.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => actions.openTask(entry.task),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              material.formatTimeOfDay(
                                TimeOfDay.fromDateTime(entry.at),
                              ),
                              style: displayStyle(14, weight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.task.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  controller
                                          .categoryById(entry.task.categoryId)
                                          ?.name ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (entry.task.schedule.delivery ==
                              ReminderDelivery.alarm) ...[
                            Icon(
                              Icons.alarm,
                              size: 16,
                              semanticLabel: l10n.text('alarm'),
                            ),
                            const SizedBox(width: 8),
                          ],
                          CountdownChip(at: entry.at),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today});

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weekday = day == today
        ? l10n.text('tabToday')
        : weekdayName(l10n, day.weekday);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            '$weekday · ${formatEthiopianDate(l10n, gregorianToEthiopian(day))}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          MaterialLocalizations.of(context).formatShortMonthDay(day),
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}
