import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';

/// Small uppercase heading above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.muted,
      ),
    );
  }
}

/// A 44×44 icon button on a quiet square.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.outlined = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color ?? AppColors.ink),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: outlined ? AppColors.background : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: outlined
              ? const BorderSide(color: AppColors.line, width: 1.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}

/// One option in a [PillGroup].
class PillOption<T> {
  const PillOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Single-choice buttons: the selected one is solid ink. With [expand] the
/// options share the width equally, otherwise they wrap.
class PillGroup<T> extends StatelessWidget {
  const PillGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.expand = false,
    this.selectedColor = AppColors.ink,
    this.selectedTextColor = Colors.white,
    this.background = AppColors.background,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool expand;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget pill(PillOption<T> option) {
      final isSelected = option.value == selected;
      return Semantics(
        selected: isSelected,
        button: true,
        child: Material(
          color: isSelected ? selectedColor : background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected || background != AppColors.background
                ? BorderSide.none
                : const BorderSide(color: AppColors.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelected(option.value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 18,
                        color: isSelected ? selectedTextColor : AppColors.ink,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected ? selectedTextColor : AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (expand) {
      return Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: pill(options[i])),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final option in options) pill(option)],
    );
  }
}

/// "in 2d 3h" style chip.
class CountdownChip extends StatelessWidget {
  const CountdownChip({super.key, required this.at, this.highlight = false});

  final DateTime at;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.text('inCompact', {
      'time': formatCompactTimeUntil(l10n, at.difference(DateTime.now())),
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Segmented progress for a task's steps.
class StepsBar extends StatelessWidget {
  const StepsBar({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.text('stepsDone', {'done': done, 'total': total}),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < done ? AppColors.ink : AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A task in the Lists tab: checkbox, title, schedule, countdown, steps.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.controller,
    required this.task,
    required this.onOpen,
  });

  final AppController controller;
  final ReminderTask task;
  final ValueChanged<ReminderTask> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final state = task.stateAt(now);
    final completed = state == DashboardTaskState.completed;
    final overdue = state == DashboardTaskState.overdue;
    final next = completed ? null : task.dueAt(now);
    final category = controller.categoryById(task.categoryId);
    final doneSteps = task.subTasks
        .where((item) => task.isSubTaskDoneAt(item, now))
        .length;

    return Material(
      color: overdue ? AppColors.missedFill : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: overdue
            ? BorderSide.none
            : const BorderSide(color: AppColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
          child: Row(
            children: [
              Checkbox(
                value: completed,
                semanticLabel: l10n.text(
                  completed ? 'markTaskNotDone' : 'markTaskDone',
                  {'title': task.title},
                ),
                onChanged: (value) => toggleTaskCompletion(
                  context,
                  controller,
                  task,
                  value ?? false,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: completed ? AppColors.muted : AppColors.ink,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (category != null) category.name,
                        formatTaskSchedule(task.schedule, context),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: overdue ? AppColors.missed : AppColors.muted,
                        fontWeight: overdue ? FontWeight.w600 : null,
                      ),
                    ),
                    if (task.subTasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      StepsBar(done: doneSteps, total: task.subTasks.length),
                    ],
                  ],
                ),
              ),
              if (next != null && !overdue) ...[
                const SizedBox(width: 8),
                CountdownChip(at: next),
              ],
              if (task.schedule.delivery == ReminderDelivery.alarm) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.alarm,
                  size: 18,
                  color: AppColors.ink,
                  semanticLabel: l10n.text('alarm'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered icon, title and hint for an empty list.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 30, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: displayStyle(20)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// The floating dark tab bar with the big + in the middle.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.index,
    required this.onSelected,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget tab(int tabIndex, IconData icon, String label) {
      final selected = tabIndex == index;
      return Expanded(
        child: Semantics(
          selected: selected,
          child: IconButton(
            tooltip: label,
            onPressed: () => onSelected(tabIndex),
            icon: Icon(icon),
            color: selected ? Colors.white : AppColors.navIdle,
            iconSize: 24,
            style: IconButton.styleFrom(minimumSize: const Size(48, 52)),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33111318),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            tab(0, Icons.schedule, l10n.text('tabToday')),
            tab(1, Icons.calendar_month_outlined, l10n.text('tabCalendar')),
            Expanded(
              child: Center(
                child: IconButton(
                  tooltip: l10n.text('newTask'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 26),
                  color: AppColors.ink,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    fixedSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            tab(2, Icons.grid_view_rounded, l10n.text('tabLists')),
            tab(3, Icons.tune, l10n.text('tabSettings')),
          ],
        ),
      ),
    );
  }
}

/// Marks a task done or not done and offers an Undo snackbar.
void toggleTaskCompletion(
  BuildContext context,
  AppController controller,
  ReminderTask task,
  bool completed,
) {
  final before = controller.taskById(task.id) ?? task;
  controller.setTaskCompleted(task, completed);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      // Auto-dismiss, except for screen-reader users who need time to
      // reach the Undo button.
      persist: MediaQuery.accessibleNavigationOf(context),
      duration: const Duration(seconds: 5),
      content: Text(
        completed
            ? context.l10n.text('markedDone')
            : context.l10n.text('taskReopened'),
      ),
      action: SnackBarAction(
        label: context.l10n.text('undo'),
        // Restore the exact previous state, including subtask ticks.
        onPressed: () => controller.updateTask(before),
      ),
    ),
  );
}

/// The text of the "done" button for [task], which says that repeating
/// reminders come back ("Done for this month").
String doneLabel(AppLocalizations l10n, ReminderSchedule schedule) {
  return l10n.text(switch (schedule.type) {
    ReminderType.everyday => 'doneToday',
    ReminderType.custom => switch (schedule.recurrenceUnit) {
      RecurrenceUnit.weekly => 'doneThisWeek',
      RecurrenceUnit.monthly => 'doneThisMonth',
      RecurrenceUnit.yearly => 'doneThisYear',
      null => 'doneOnce',
    },
    _ => 'doneOnce',
  });
}
