import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';
import '../utils/calendar_utils.dart';

class CategorizedTaskList extends StatelessWidget {
  const CategorizedTaskList({
    super.key,
    required this.controller,
    required this.state,
  });

  final AppController controller;
  final DashboardTaskState state;

  @override
  Widget build(BuildContext context) {
    final grouped = controller.groupedTasks(state);
    if (grouped.isEmpty) {
      return _EmptyState(state: state, hasSearch: controller.searchQuery.isNotEmpty);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        for (final entry in grouped.entries) ...[
          _CategoryHeader(category: entry.key, count: entry.value.length),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int index = 0; index < entry.value.length; index++) ...[
                  _TaskTile(
                    controller: controller,
                    task: entry.value[index],
                    state: state,
                  ),
                  if (index != entry.value.length - 1)
                    const Divider(height: 1, indent: 62),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});

  final TaskCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(category.icon, size: 19, color: category.color),
        ),
        const SizedBox(width: 10),
        Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        Text(
          '$count task${count == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.controller,
    required this.task,
    required this.state,
  });

  final AppController controller;
  final ReminderTask task;
  final DashboardTaskState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOverdue = state == DashboardTaskState.overdue;

    return ExpansionTile(
      tilePadding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      childrenPadding: const EdgeInsets.fromLTRB(62, 0, 16, 12),
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (value) => _handleTaskCompletion(context, value ?? false),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted ? scheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
              size: 15,
              color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                formatTaskSchedule(task.schedule, context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: task.subTasks.isEmpty
          ? const Icon(Icons.chevron_right)
          : SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: task.progress,
                    strokeWidth: 3,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  Text(
                    '${(task.progress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
      children: task.subTasks.isEmpty
          ? [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  task.schedule.notificationsEnabled
                      ? 'Notification enabled'
                      : 'Notification disabled',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]
          : [
              for (final subTask in task.subTasks)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    subTask.title,
                    style: TextStyle(
                      decoration: subTask.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: subTask.isDone,
                  onChanged: (value) => controller.setSubTaskCompleted(
                    task,
                    subTask,
                    value ?? false,
                  ),
                ),
            ],
    );
  }

  void _handleTaskCompletion(BuildContext context, bool completed) {
    final previous = task.isCompleted;
    controller.setTaskCompleted(task, completed);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(completed ? 'Task marked as done' : 'Task reopened'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.setTaskCompleted(task, previous),
          ),
        ),
      );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state, required this.hasSearch});

  final DashboardTaskState state;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = hasSearch
        ? (
            Icons.search_off_outlined,
            'No matching tasks',
            'Try a different search phrase or category.',
          )
        : switch (state) {
            DashboardTaskState.active => (
                Icons.checklist_rounded,
                'No active tasks',
                'Tap the + button to create your next reminder.',
              ),
            DashboardTaskState.overdue => (
                Icons.event_available_outlined,
                'Nothing overdue',
                'You are all caught up.',
              ),
            DashboardTaskState.completed => (
                Icons.task_alt,
                'No completed tasks yet',
                'Completed reminders will appear here.',
              ),
          };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
