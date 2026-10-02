import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.controller,
    required this.actions,
  });

  final AppController controller;
  final HomeActions actions;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selectedDay = dateOnly(DateTime.now());

  AppController get _controller => widget.controller;

  /// Weeks start on Sunday, as on Ethiopian calendars.
  DateTime get _weekStart => DateTime(
    _selectedDay.year,
    _selectedDay.month,
    _selectedDay.day - _selectedDay.weekday % 7,
  );

  void _moveWeek(int weeks) {
    setState(() {
      _selectedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + 7 * weeks,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = dateOnly(now);
    final issue = widget.actions.permissionIssue;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.text('tabToday'), style: displayStyle(28)),
              ),
              SquareIconButton(
                icon: Icons.search,
                tooltip: l10n.text('searchTasks'),
                outlined: true,
                onPressed: widget.actions.openSearch,
              ),
            ],
          ),
          if (issue != null && _controller.settings.notificationsEnabled) ...[
            const SizedBox(height: 14),
            _PermissionBanner(
              issue: issue,
              onAllow: widget.actions.allowPermission,
            ),
          ],
          const SizedBox(height: 16),
          _NextUpCard(
            controller: _controller,
            actions: widget.actions,
            now: now,
          ),
          const SizedBox(height: 20),
          _WeekHeader(
            selectedDay: _selectedDay,
            onPrevious: () => _moveWeek(-1),
            onNext: () => _moveWeek(1),
          ),
          const SizedBox(height: 8),
          _WeekStrip(
            weekStart: _weekStart,
            selectedDay: _selectedDay,
            today: today,
            primary: _controller.settings.defaultCalendar,
            onSelected: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 18),
          ..._timeline(context, now, today),
        ],
      ),
    );
  }

  List<Widget> _timeline(BuildContext context, DateTime now, DateTime today) {
    final l10n = context.l10n;
    final isToday = _selectedDay == today;
    final missed = isToday ? _controller.missedTasks(now) : <ReminderTask>[];
    final dayTasks = _controller
        .tasksOnDay(_selectedDay)
        .where((task) => !missed.contains(task))
        .toList();
    if (missed.isEmpty && dayTasks.isEmpty) {
      return [
        EmptyMessage(
          icon: Icons.event_available_outlined,
          title: l10n.text('nothingThisDay'),
          message: l10n.text('nothingNextHelp'),
        ),
      ];
    }

    final next = _controller.nextUp(now);
    final material = MaterialLocalizations.of(context);
    return [
      for (final task in missed)
        _TimelineRow(
          time: material.formatTimeOfDay(task.schedule.time),
          timeColor: AppColors.missed,
          child: _MissedCard(
            controller: _controller,
            task: task,
            now: now,
            onOpen: widget.actions.openTask,
          ),
        ),
      for (final task in dayTasks)
        _TimelineRow(
          time: material.formatTimeOfDay(task.schedule.time),
          highlight: next?.task.id == task.id,
          faded: task.isCompletedAt(now),
          child: _DayCard(
            controller: _controller,
            task: task,
            now: now,
            onOpen: widget.actions.openTask,
          ),
        ),
    ];
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.issue, required this.onAllow});

  final ReminderPermissionIssue issue;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.missedFill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: AppColors.missed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.text('permissionRequired'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  l10n.text(
                    issue == ReminderPermissionIssue.exactAlarms
                        ? 'exactAlarmPermissionHelp'
                        : 'notificationPermissionHelp',
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAllow, child: Text(l10n.text('allow'))),
        ],
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({
    required this.controller,
    required this.actions,
    required this.now,
  });

  final AppController controller;
  final HomeActions actions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = controller.nextUp(now);
    final material = MaterialLocalizations.of(context);

    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text('nextUp').toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.mutedOnInk,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.text('nothingNext'),
              style: displayStyle(26, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.text('nothingNextHelp'),
              style: const TextStyle(color: AppColors.mutedOnInk),
            ),
          ],
        ),
      );
    }

    final task = next.task;
    final category = controller.categoryById(task.categoryId);
    final isToday = dateOnly(next.at) == dateOnly(now);
    final timeLabel = [
      if (!isToday) weekdayName(l10n, next.at.weekday),
      material.formatTimeOfDay(TimeOfDay.fromDateTime(next.at)),
    ].join(' · ');

    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => actions.openTask(task),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.text('nextUp').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.mutedOnInk,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                formatCompactTimeUntil(l10n, next.at.difference(now)),
                style: displayStyle(52, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          [
                            if (category != null) category.name,
                            formatTaskSchedule(task.schedule, context),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedOnInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: l10n.text('markTaskDone', {'title': task.title}),
                    onPressed: () =>
                        toggleTaskCompletion(context, controller, task, true),
                    icon: const Icon(Icons.check, color: AppColors.ink),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      fixedSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ethiopian = gregorianToEthiopian(selectedDay);
    final label =
        '${ethiopianMonthName(l10n, ethiopian.month)} ${ethiopian.year} '
        '${l10n.text('ecSuffix')} · '
        '${MaterialLocalizations.of(context).formatMonthYear(selectedDay)}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.text('previousWeek'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: l10n.text('nextWeek'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.primary,
    required this.onSelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final CalendarSystem primary;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final day = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + i,
              );
              final selected = day == selectedDay;
              final isToday = day == today;
              final ethiopian = gregorianToEthiopian(day);
              final big = primary == CalendarSystem.ethiopian
                  ? '${ethiopian.day}'
                  : '${day.day}';
              final small = primary == CalendarSystem.ethiopian
                  ? material.formatShortMonthDay(day)
                  : '${ethiopian.day}';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: Material(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(day),
                      child: Semantics(
                        selected: selected,
                        label: material.formatFullDate(day),
                        excludeSemantics: true,
                        child: SizedBox(
                          height: 68,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                child: Text(
                                  weekdayName(l10n, day.weekday),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.muted,
                                  ),
                                ),
                              ),
                              Text(big, style: displayStyle(18)),
                              FittedBox(
                                child: Text(
                                  small,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isToday && !selected
                                      ? AppColors.accent
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Time on the left, a line, and the card.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.time,
    required this.child,
    this.timeColor,
    this.highlight = false,
    this.faded = false,
  });

  final String time;
  final Widget child;
  final Color? timeColor;
  final bool highlight;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                time,
                style: displayStyle(
                  14,
                  weight: FontWeight.w600,
                  color: timeColor ?? (faded ? AppColors.muted : AppColors.ink),
                ),
              ),
            ),
          ),
          Container(
            width: 2,
            color: highlight ? AppColors.accent : AppColors.line,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 0, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({
    required this.controller,
    required this.task,
    required this.now,
    required this.onOpen,
  });

  final AppController controller;
  final ReminderTask task;
  final DateTime now;
  final ValueChanged<ReminderTask> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = task.schedule.deadline!;
    final subtitle = dateOnly(due) == dateOnly(now)
        ? l10n.text('missedAgo', {
            'time': formatCompactTimeUntil(l10n, now.difference(due)),
          })
        : l10n.text('missedOn', {
            'date': formatCalendarDate(
              context,
              due,
              task.schedule.calendarSystem,
            ),
          });
    return Material(
      color: AppColors.missedFill,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.missed,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () =>
                    toggleTaskCompletion(context, controller, task, true),
                child: Text(l10n.text('markDone')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.controller,
    required this.task,
    required this.now,
    required this.onOpen,
  });

  final AppController controller;
  final ReminderTask task;
  final DateTime now;
  final ValueChanged<ReminderTask> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = controller.categoryById(task.categoryId);
    final completed = task.isCompletedAt(now);
    final doneSteps = task.subTasks
        .where((item) => task.isSubTaskDoneAt(item, now))
        .length;

    if (completed) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(task),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.check, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final details = [
      if (category != null) category.name,
      if (task.subTasks.isNotEmpty)
        l10n.text('stepsDone', {
          'done': doneSteps,
          'total': task.subTasks.length,
        })
      else
        formatTaskSchedule(task.schedule, context),
    ].join(' · ');

    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (task.schedule.delivery == ReminderDelivery.alarm)
                    Icon(
                      Icons.alarm,
                      size: 16,
                      semanticLabel: l10n.text('alarm'),
                    ),
                ],
              ),
              if (task.subTasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                StepsBar(done: doneSteps, total: task.subTasks.length),
              ],
              const SizedBox(height: 6),
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
