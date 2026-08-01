import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../utils/calendar_utils.dart';
import 'category_name_dialog.dart';
import 'ethiopian_date_picker.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _subTaskControllers = [];

  String? _categoryId;
  bool _multipleTasks = false;
  ReminderType _reminderType = ReminderType.specificDate;
  RecurrenceUnit _recurrenceUnit = RecurrenceUnit.weekly;
  CalendarSystem _calendarSystem = CalendarSystem.ethiopian;
  DateTime _gregorianDate = DateTime.now().add(const Duration(days: 1));
  DateTime _gregorianEndDate = DateTime.now().add(const Duration(days: 2));
  EthiopianDateValue _ethiopianDate = gregorianToEthiopian(
    DateTime.now().add(const Duration(days: 1)),
  );
  EthiopianDateValue _ethiopianEndDate = gregorianToEthiopian(
    DateTime.now().add(const Duration(days: 2)),
  );
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = <int>{DateTime.monday};
  ReminderDelivery _delivery = ReminderDelivery.notification;

  @override
  void initState() {
    super.initState();
    final selectedId = widget.controller.selectedCategoryId;
    _categoryId =
        selectedId != null &&
            selectedId != AppController.todayCategoryId &&
            widget.controller.categories.any(
              (category) => category.id == selectedId,
            )
        ? selectedId
        : (widget.controller.categories.isNotEmpty
              ? widget.controller.categories.first.id
              : null);
    _calendarSystem = widget.controller.settings.defaultCalendar;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _subTaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.65,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.text('createReminder'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.text('close'),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      number: 1,
                      title: context.l10n.text('taskCategory'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoryId,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('category'),
                              prefixIcon: const Icon(Icons.category_outlined),
                            ),
                            items: [
                              for (final category
                                  in widget.controller.categories)
                                DropdownMenuItem(
                                  value: category.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        category.icon,
                                        size: 18,
                                        color: category.color,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(category.name),
                                    ],
                                  ),
                                ),
                            ],
                            validator: (value) => value == null
                                ? context.l10n.text('selectCategory')
                                : null,
                            onChanged: (value) =>
                                setState(() => _categoryId = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: context.l10n.text('addCategory'),
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      number: 2,
                      title: context.l10n.text('whatToDo'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('taskTitle'),
                        hintText: context.l10n.text('taskExample'),
                        prefixIcon: const Icon(Icons.edit_note_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.text('enterTask');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.l10n.text('multipleTasks')),
                      subtitle: Text(context.l10n.text('multipleTasksHelp')),
                      value: _multipleTasks,
                      onChanged: (value) {
                        setState(() {
                          _multipleTasks = value ?? false;
                          if (_multipleTasks && _subTaskControllers.isEmpty) {
                            _subTaskControllers.addAll([
                              TextEditingController(),
                              TextEditingController(),
                            ]);
                          }
                        });
                      },
                    ),
                    if (_multipleTasks) ...[
                      const SizedBox(height: 4),
                      for (
                        int index = 0;
                        index < _subTaskControllers.length;
                        index++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: _subTaskControllers[index],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('subtask', {
                                'count': index + 1,
                              }),
                              prefixIcon: const Icon(
                                Icons.subdirectory_arrow_right,
                              ),
                              suffixIcon: _subTaskControllers.length > 2
                                  ? IconButton(
                                      tooltip: context.l10n.text(
                                        'removeSubtask',
                                      ),
                                      onPressed: () => _removeSubTask(index),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    )
                                  : null,
                            ),
                            validator: (value) {
                              if (_multipleTasks &&
                                  (value == null || value.trim().isEmpty)) {
                                return context.l10n.text('enterSubtask');
                              }
                              return null;
                            },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _subTaskControllers.add(
                              TextEditingController(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.text('addSubtask')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SectionTitle(
                      number: 3,
                      title: context.l10n.text('reminderType'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ReminderType>(
                      value: _reminderType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('repeatSchedule'),
                        prefixIcon: const Icon(Icons.repeat),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ReminderType.specificDate,
                          child: Text(context.l10n.text('specificDate')),
                        ),
                        DropdownMenuItem(
                          value: ReminderType.dateRange,
                          child: Text(
                            context.l10n.text('dateRange'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: ReminderType.everyday,
                          child: Text(context.l10n.text('everyDay')),
                        ),
                        DropdownMenuItem(
                          value: ReminderType.custom,
                          child: Text(context.l10n.text('customRepeat')),
                        ),
                      ],
                      selectedItemBuilder: (context) => [
                        Text(context.l10n.text('specificDate')),
                        Text(context.l10n.text('dateRange')),
                        Text(context.l10n.text('everyDay')),
                        Text(
                          context.l10n.text('customRecurrence'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _reminderType = value ?? _reminderType,
                      ),
                    ),
                    if (_reminderType == ReminderType.custom) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final unit in RecurrenceUnit.values)
                            ChoiceChip(
                              label: Text(switch (unit) {
                                RecurrenceUnit.weekly => context.l10n.text(
                                  'weekly',
                                ),
                                RecurrenceUnit.monthly => context.l10n.text(
                                  'monthly',
                                ),
                                RecurrenceUnit.yearly => context.l10n.text(
                                  'yearly',
                                ),
                              }),
                              selected: _recurrenceUnit == unit,
                              onSelected: (_) =>
                                  setState(() => _recurrenceUnit = unit),
                            ),
                        ],
                      ),
                      if (_recurrenceUnit == RecurrenceUnit.weekly) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final entry in const <int, String>{
                              DateTime.monday: 'M',
                              DateTime.tuesday: 'T',
                              DateTime.wednesday: 'W',
                              DateTime.thursday: 'T',
                              DateTime.friday: 'F',
                              DateTime.saturday: 'S',
                              DateTime.sunday: 'S',
                            }.entries)
                              FilterChip(
                                label: Text(entry.value),
                                selected: _weekdays.contains(entry.key),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _weekdays.add(entry.key);
                                    } else if (_weekdays.length > 1) {
                                      _weekdays.remove(entry.key);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _SectionTitle(
                      number: 4,
                      title: context.l10n.text('notificationDateTime'),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<CalendarSystem>(
                      segments: [
                        ButtonSegment(
                          value: CalendarSystem.ethiopian,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(context.l10n.text('ethiopian')),
                        ),
                        ButtonSegment(
                          value: CalendarSystem.gregorian,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(context.l10n.text('gregorian')),
                        ),
                      ],
                      selected: <CalendarSystem>{_calendarSystem},
                      onSelectionChanged: (value) {
                        setState(() => _calendarSystem = value.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_reminderType != ReminderType.everyday) ...[
                      if (_reminderType == ReminderType.dateRange)
                        _buildDateRangeSelection(context)
                      else
                        _buildDateTile(context, isEnd: false),
                    ],
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      leading: const Icon(Icons.schedule),
                      title: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(_time),
                      ),
                      subtitle: Text(context.l10n.text('reminderTime')),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.text('deliveryType'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<ReminderDelivery>(
                      segments: [
                        ButtonSegment(
                          value: ReminderDelivery.notification,
                          icon: const Icon(Icons.notifications_outlined),
                          label: Text(context.l10n.text('notification')),
                        ),
                        ButtonSegment(
                          value: ReminderDelivery.alarm,
                          icon: const Icon(Icons.alarm_outlined),
                          label: Text(context.l10n.text('alarm')),
                        ),
                      ],
                      selected: {_delivery},
                      onSelectionChanged: (value) =>
                          setState(() => _delivery = value.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.text(
                        _delivery == ReminderDelivery.alarm
                            ? 'alarmDeliveryHelp'
                            : 'notificationDeliveryHelp',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.add_task),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(context.l10n.text('createReminder')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateTile(BuildContext context, {required bool isEnd}) {
    final gregorian = isEnd ? _gregorianEndDate : _gregorianDate;
    final ethiopian = isEnd ? _ethiopianEndDate : _ethiopianDate;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: Icon(
        isEnd ? Icons.event_available_outlined : Icons.calendar_today_outlined,
      ),
      title: Text(
        _calendarSystem == CalendarSystem.ethiopian
            ? '${ethiopianMonthNames[ethiopian.month - 1]} '
                  '${ethiopian.day}, ${ethiopian.year} EC'
            : MaterialLocalizations.of(context).formatMediumDate(gregorian),
      ),
      subtitle: Text(
        _reminderType == ReminderType.dateRange
            ? context.l10n.text(isEnd ? 'endDate' : 'startDate')
            : (_calendarSystem == CalendarSystem.ethiopian
                  ? 'Gregorian: ${MaterialLocalizations.of(context).formatMediumDate(ethiopianToGregorian(ethiopian))}'
                  : context.l10n.text('gregorianCalendar')),
      ),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () => _pickDate(isEnd: isEnd),
    );
  }

  Widget _buildDateRangeSelection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.date_range_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.text('selectedDateRange'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _buildDateTile(context, isEnd: false),
            Padding(
              padding: const EdgeInsets.only(left: 31),
              child: Container(width: 2, height: 10, color: scheme.primary),
            ),
            _buildDateTile(context, isEnd: true),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isEnd}) async {
    if (_calendarSystem == CalendarSystem.gregorian) {
      if (_reminderType == ReminderType.dateRange) {
        final selected = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(
            start: _gregorianDate,
            end: _gregorianEndDate,
          ),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (selected != null && mounted) {
          setState(() {
            _gregorianDate = selected.start;
            _gregorianEndDate = selected.end;
            _ethiopianDate = gregorianToEthiopian(selected.start);
            _ethiopianEndDate = gregorianToEthiopian(selected.end);
          });
        }
        return;
      }
      final selected = await showDatePicker(
        context: context,
        initialDate: isEnd ? _gregorianEndDate : _gregorianDate,
        firstDate: _reminderType == ReminderType.specificDate
            ? DateUtils.dateOnly(DateTime.now())
            : DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (selected != null && mounted) {
        setState(() {
          if (isEnd) {
            _gregorianEndDate = selected.isBefore(_gregorianDate)
                ? _gregorianDate
                : selected;
            _ethiopianEndDate = gregorianToEthiopian(_gregorianEndDate);
          } else {
            _gregorianDate = selected;
            _ethiopianDate = gregorianToEthiopian(selected);
            if (_gregorianEndDate.isBefore(selected)) {
              _gregorianEndDate = selected;
              _ethiopianEndDate = gregorianToEthiopian(selected);
            }
          }
        });
      }
      return;
    }

    final selected = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: isEnd ? _ethiopianEndDate : _ethiopianDate,
    );
    if (selected != null && mounted) {
      final gregorian = ethiopianToGregorian(selected);
      if (_reminderType == ReminderType.specificDate &&
          gregorian.isBefore(DateUtils.dateOnly(DateTime.now()))) {
        await _showPastTimeDialog(
          DateTime(
            gregorian.year,
            gregorian.month,
            gregorian.day,
            _time.hour,
            _time.minute,
          ),
        );
        return;
      }
      setState(() {
        if (isEnd) {
          _gregorianEndDate = gregorian.isBefore(_gregorianDate)
              ? _gregorianDate
              : gregorian;
          _ethiopianEndDate = gregorianToEthiopian(_gregorianEndDate);
        } else {
          _ethiopianDate = selected;
          _gregorianDate = gregorian;
          if (_gregorianEndDate.isBefore(gregorian)) {
            _gregorianEndDate = gregorian;
            _ethiopianEndDate = selected;
          }
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      final scheduledAt = DateTime(
        _gregorianDate.year,
        _gregorianDate.month,
        _gregorianDate.day,
        selected.hour,
        selected.minute,
      );
      if (_reminderType == ReminderType.specificDate &&
          !scheduledAt.isAfter(DateTime.now())) {
        await _showPastTimeDialog(scheduledAt);
        return;
      }
      setState(() => _time = selected);
    }
  }

  Future<void> _showPastTimeDialog(DateTime scheduledAt) {
    final localizations = MaterialLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.schedule_outlined),
        title: Text(context.l10n.text('timeAlreadyPassed')),
        content: Text(
          context.l10n.text('chooseFutureDateTime', {
            'date': localizations.formatMediumDate(scheduledAt),
            'time': localizations.formatTimeOfDay(
              TimeOfDay.fromDateTime(scheduledAt),
            ),
          }),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.text('chooseAnotherTime')),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => CategoryNameDialog(
        title: context.l10n.text('newCategory'),
        actionLabel: context.l10n.text('add'),
        hintText: context.l10n.text('financeExample'),
      ),
    );

    if (name != null && name.trim().isNotEmpty && mounted) {
      final category = widget.controller.addCategory(name);
      setState(() => _categoryId = category.id);
    }
  }

  void _removeSubTask(int index) {
    final controller = _subTaskControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final date = _reminderType == ReminderType.everyday
        ? null
        : DateTime(
            _gregorianDate.year,
            _gregorianDate.month,
            _gregorianDate.day,
          );

    if (_reminderType == ReminderType.specificDate && date != null) {
      final scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        _time.hour,
        _time.minute,
      );
      if (!scheduledAt.isAfter(DateTime.now())) {
        await _showPastTimeDialog(scheduledAt);
        return;
      }
    }

    final task = ReminderTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      categoryId: _categoryId!,
      title: _titleController.text.trim(),
      schedule: ReminderSchedule(
        type: _reminderType,
        calendarSystem: _calendarSystem,
        date: date,
        endDate: _reminderType == ReminderType.dateRange
            ? _gregorianEndDate
            : null,
        ethiopianDate: _calendarSystem == CalendarSystem.ethiopian
            ? _ethiopianDate
            : null,
        ethiopianEndDate:
            _calendarSystem == CalendarSystem.ethiopian &&
                _reminderType == ReminderType.dateRange
            ? _ethiopianEndDate
            : null,
        time: _time,
        recurrenceUnit: _reminderType == ReminderType.custom
            ? _recurrenceUnit
            : null,
        weekdays:
            _reminderType == ReminderType.custom &&
                _recurrenceUnit == RecurrenceUnit.weekly
            ? Set<int>.unmodifiable(_weekdays)
            : const <int>{},
        delivery: _delivery,
      ),
      subTasks: _multipleTasks
          ? [
              for (final controller in _subTaskControllers)
                SubTask(
                  id: 'sub-${DateTime.now().microsecondsSinceEpoch}-${controller.hashCode}',
                  title: controller.text.trim(),
                ),
            ]
          : const <SubTask>[],
    );

    widget.controller.addTask(task);
    Navigator.pop(context, task);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '$number',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
