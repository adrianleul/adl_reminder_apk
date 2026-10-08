import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';
import '../widgets/ui.dart';

/// One reminder: countdown, upcoming dates, steps, edit and done.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.controller,
    required this.taskId,
    required this.onEdit,
    required this.onDelete,
  });

  final AppController controller;
  final String taskId;
  final ValueChanged<ReminderTask> onEdit;
  final ValueChanged<ReminderTask> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final task = controller.taskById(taskId);
        if (task == null) {
          return Scaffold(appBar: AppBar());
        }
        return _buildScreen(context, task);
      },
    );
  }

  Widget _buildScreen(BuildContext context, ReminderTask task) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final state = task.stateAt(now);
    final completed = state == DashboardTaskState.completed;
    final category = controller.categoryById(task.categoryId);
    final upcoming = completed && !task.schedule.isRecurring
        ? const <DateTime>[]
        : task.schedule.occurrencesAfter(
            completed
                ? DateTime(now.year, now.month, now.day, 23, 59, 59)
                : now,
            limit: 3,
          );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: Icons.arrow_back,
                    tooltip: l10n.text('back'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: l10n.text('moreActions'),
                    icon: const Icon(Icons.more_horiz),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      fixedSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        Navigator.pop(context);
                        onDelete(task);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          l10n.text('deleteTask'),
                          style: const TextStyle(color: AppColors.missed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (category != null) _Tag(text: category.name),
                      _Tag(
                        icon: task.schedule.delivery == ReminderDelivery.alarm
                            ? Icons.alarm
                            : Icons.notifications_none,
                        text: l10n.text(
                          task.schedule.delivery == ReminderDelivery.alarm
                              ? 'alarm'
                              : 'notification',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    task.title,
                    style: displayStyle(34).copyWith(
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatTaskSchedule(task.schedule, context),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (state == DashboardTaskState.overdue)
                    _MissedNotice(task: task)
                  else if (upcoming.isNotEmpty && !completed)
                    _CountdownTiles(remaining: upcoming.first.difference(now)),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SectionLabel(l10n.text('comingUp')),
                    const SizedBox(height: 4),
                    for (final (index, at) in upcoming.indexed)
                      _UpcomingRow(at: at, first: index == 0),
                  ],
                  if (task.subTasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SectionLabel(l10n.text('steps')),
                    const SizedBox(height: 8),
                    for (final subTask in task.subTasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            value: task.isSubTaskDoneAt(subTask, now),
                            onChanged: (value) =>
                                controller.setSubTaskCompleted(
                                  task,
                                  subTask,
                                  value ?? false,
                                ),
                            title: Text(
                              subTask.title,
                              style: TextStyle(
                                fontSize: 15,
                                color: task.isSubTaskDoneAt(subTask, now)
                                    ? AppColors.muted
                                    : AppColors.ink,
                                decoration: task.isSubTaskDoneAt(subTask, now)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(58, 58),
                      ),
                      onPressed: () => onEdit(task),
                      child: Icon(
                        Icons.edit_outlined,
                        semanticLabel: l10n.text('editTask'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: () => toggleTaskCompletion(
                        context,
                        controller,
                        task,
                        !completed,
                      ),
                      icon: Icon(completed ? Icons.undo : Icons.check),
                      label: Text(
                        completed
                            ? l10n.text('reopen')
                            : doneLabel(l10n, task.schedule),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 5)],
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CountdownTiles extends StatelessWidget {
  const _CountdownTiles({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = countdownParts(remaining);
    final tiles = [
      (parts.days, 'Day'),
      (parts.hours, 'Hour'),
      (parts.minutes, 'Minute'),
    ];
    return Semantics(
      label: formatTimeUntil(l10n, remaining),
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (index, (value, unit)) in tiles.indexed)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                decoration: BoxDecoration(
                  color: index == 0 ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value', style: displayStyle(34)),
                    const SizedBox(height: 2),
                    Text(
                      unitLabel(l10n, value, unit),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissedNotice extends StatelessWidget {
  const _MissedNotice({required this.task});

  final ReminderTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.missedFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.missed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.text('missedOn', {
                'date': formatCalendarDate(
                  context,
                  task.schedule.deadline!,
                  task.schedule.calendarSystem,
                ),
              }),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.missed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.at, required this.first});

  final DateTime at;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final ethiopian = gregorianToEthiopian(at);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surface)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: first ? AppColors.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: first
                  ? null
                  : Border.all(color: const Color(0xFFC9CBD2), width: 2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${ethiopianMonthName(l10n, ethiopian.month)} ${ethiopian.day}, '
              '${ethiopian.year}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: first ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${weekdayName(l10n, at.weekday)}, '
            '${material.formatShortMonthDay(at)} · '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
