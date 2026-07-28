import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';

class TaskSummaryCard extends StatelessWidget {
  const TaskSummaryCard({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.overallSummary;
    final scheduleSummaries = controller.summaryBySchedule;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.insights_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Task summary',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${summary.total} task${summary.total == 1 ? '' : 's'} overall',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatusMetric(
                        icon: Icons.task_alt,
                        label: 'Done',
                        value: summary.done,
                        foreground: scheme.primary,
                        background: scheme.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusMetric(
                        icon: Icons.warning_amber_rounded,
                        label: 'Overdue',
                        value: summary.overdue,
                        foreground: scheme.error,
                        background: scheme.errorContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusMetric(
                        icon: Icons.pending_actions_outlined,
                        label: 'Undone',
                        value: summary.undone,
                        foreground: scheme.tertiary,
                        background: scheme.tertiaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Undone tasks are active tasks that are not overdue.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.repeat_rounded),
            title: const Text('Status by schedule'),
            subtitle: const Text('Each recurring reminder is counted once'),
            children: [
              const SizedBox(height: 4),
              _ScheduleSummaryTable(summaries: scheduleSummaries),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _ScheduleSummaryTable extends StatelessWidget {
  const _ScheduleSummaryTable({required this.summaries});

  final Map<ReminderScheduleGroup, TaskStatusSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _ScheduleRow(
            label: 'Schedule',
            done: 'Done',
            overdue: 'Overdue',
            undone: 'Undone',
            textStyle: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final group in ReminderScheduleGroup.values) ...[
            const Divider(height: 1),
            Builder(
              builder: (context) {
                final summary = summaries[group] ?? const TaskStatusSummary();
                return _ScheduleRow(
                  label: _groupLabel(group),
                  done: '${summary.done}',
                  overdue: '${summary.overdue}',
                  undone: '${summary.undone}',
                  textStyle: textTheme.bodySmall,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _groupLabel(ReminderScheduleGroup group) {
    return switch (group) {
      ReminderScheduleGroup.oneTime => 'One-time',
      ReminderScheduleGroup.daily => 'Daily',
      ReminderScheduleGroup.weekly => 'Weekly',
      ReminderScheduleGroup.monthly => 'Monthly',
      ReminderScheduleGroup.yearly => 'Yearly',
    };
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.label,
    required this.done,
    required this.overdue,
    required this.undone,
    required this.textStyle,
  });

  final String label;
  final String done;
  final String overdue;
  final String undone;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: textStyle)),
          Expanded(
            child: Text(done, textAlign: TextAlign.center, style: textStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(overdue, textAlign: TextAlign.center, style: textStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(undone, textAlign: TextAlign.center, style: textStyle),
          ),
        ],
      ),
    );
  }
}
