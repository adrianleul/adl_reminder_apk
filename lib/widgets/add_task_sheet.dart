import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';
import '../utils/calendar_utils.dart';
import 'ethiopian_date_picker.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({
    super.key,
    required this.controller,
  });

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
  EthiopianDateValue _ethiopianDate = gregorianToEthiopian(
    DateTime.now().add(const Duration(days: 1)),
  );
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = <int>{DateTime.monday};
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.controller.selectedCategoryId ??
        (widget.controller.categories.isNotEmpty
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
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
                            'Create reminder',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(number: 1, title: 'Task category'),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoryId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              for (final category in widget.controller.categories)
                                DropdownMenuItem(
                                  value: category.id,
                                  child: Row(
                                    children: [
                                      Icon(category.icon, size: 18, color: category.color),
                                      const SizedBox(width: 8),
                                      Text(category.name),
                                    ],
                                  ),
                                ),
                            ],
                            validator: (value) => value == null
                                ? 'Select or create a category.'
                                : null,
                            onChanged: (value) => setState(() => _categoryId = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Add category',
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(number: 2, title: 'What needs to be done?'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        hintText: 'Example: Submit the monthly report',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a task title.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Multiple tasks?'),
                      subtitle: const Text('Break this reminder into subtasks.'),
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
                      for (int index = 0; index < _subTaskControllers.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: _subTaskControllers[index],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Subtask ${index + 1}',
                              prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                              suffixIcon: _subTaskControllers.length > 2
                                  ? IconButton(
                                      tooltip: 'Remove subtask',
                                      onPressed: () => _removeSubTask(index),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    )
                                  : null,
                            ),
                            validator: (value) {
                              if (_multipleTasks &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Enter a subtask.';
                              }
                              return null;
                            },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _subTaskControllers.add(TextEditingController()),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add another subtask'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SectionTitle(number: 3, title: 'Reminder type'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ReminderType>(
                      value: _reminderType,
                      decoration: const InputDecoration(
                        labelText: 'Repeat schedule',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ReminderType.specificDate,
                          child: Text('On a specific date'),
                        ),
                        DropdownMenuItem(
                          value: ReminderType.everyday,
                          child: Text('Every day'),
                        ),
                        DropdownMenuItem(
                          value: ReminderType.custom,
                          child: Text('Specific days / weekly / monthly / yearly'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _reminderType = value ?? _reminderType,
                      ),
                    ),
                    if (_reminderType == ReminderType.custom) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<RecurrenceUnit>(
                        segments: const [
                          ButtonSegment(
                            value: RecurrenceUnit.weekly,
                            label: Text('Weekly'),
                          ),
                          ButtonSegment(
                            value: RecurrenceUnit.monthly,
                            label: Text('Monthly'),
                          ),
                          ButtonSegment(
                            value: RecurrenceUnit.yearly,
                            label: Text('Yearly'),
                          ),
                        ],
                        selected: <RecurrenceUnit>{_recurrenceUnit},
                        onSelectionChanged: (value) => setState(
                          () => _recurrenceUnit = value.first,
                        ),
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
                    _SectionTitle(number: 4, title: 'Notification date and time'),
                    const SizedBox(height: 10),
                    SegmentedButton<CalendarSystem>(
                      segments: const [
                        ButtonSegment(
                          value: CalendarSystem.ethiopian,
                          icon: Icon(Icons.calendar_month_outlined),
                          label: Text('Ethiopian'),
                        ),
                        ButtonSegment(
                          value: CalendarSystem.gregorian,
                          icon: Icon(Icons.event_outlined),
                          label: Text('Gregorian'),
                        ),
                      ],
                      selected: <CalendarSystem>{_calendarSystem},
                      onSelectionChanged: (value) {
                        setState(() => _calendarSystem = value.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_reminderType != ReminderType.everyday)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(
                          _calendarSystem == CalendarSystem.ethiopian
                              ? '${ethiopianMonthNames[_ethiopianDate.month - 1]} '
                                  '${_ethiopianDate.day}, ${_ethiopianDate.year} EC'
                              : MaterialLocalizations.of(context)
                                  .formatMediumDate(_gregorianDate),
                        ),
                        subtitle: Text(
                          _calendarSystem == CalendarSystem.ethiopian
                              ? 'Gregorian: ${MaterialLocalizations.of(context).formatMediumDate(ethiopianToGregorian(_ethiopianDate))}'
                              : 'Gregorian calendar',
                        ),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _pickDate,
                      ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      leading: const Icon(Icons.schedule),
                      title: Text(MaterialLocalizations.of(context).formatTimeOfDay(_time)),
                      subtitle: const Text('Reminder time'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Send notification'),
                      subtitle: const Text('Use sound and vibration preferences from Settings.'),
                      value: _notificationsEnabled,
                      onChanged: (value) => setState(
                        () => _notificationsEnabled = value,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.add_task),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Create reminder'),
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

  Future<void> _pickDate() async {
    if (_calendarSystem == CalendarSystem.gregorian) {
      final selected = await showDatePicker(
        context: context,
        initialDate: _gregorianDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (selected != null && mounted) {
        setState(() {
          _gregorianDate = selected;
          _ethiopianDate = gregorianToEthiopian(selected);
        });
      }
      return;
    }

    final selected = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: _ethiopianDate,
    );
    if (selected != null && mounted) {
      setState(() {
        _ethiopianDate = selected;
        _gregorianDate = ethiopianToGregorian(selected);
      });
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Future<void> _addCategory() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'Example: Finance',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    textController.dispose();

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

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final date = _reminderType == ReminderType.everyday
        ? null
        : _calendarSystem == CalendarSystem.ethiopian
            ? ethiopianToGregorian(_ethiopianDate)
            : _gregorianDate;

    final task = ReminderTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      categoryId: _categoryId!,
      title: _titleController.text.trim(),
      schedule: ReminderSchedule(
        type: _reminderType,
        calendarSystem: _calendarSystem,
        date: date,
        ethiopianDate:
            _calendarSystem == CalendarSystem.ethiopian ? _ethiopianDate : null,
        time: _time,
        recurrenceUnit:
            _reminderType == ReminderType.custom ? _recurrenceUnit : null,
        weekdays: _reminderType == ReminderType.custom &&
                _recurrenceUnit == RecurrenceUnit.weekly
            ? Set<int>.unmodifiable(_weekdays)
            : const <int>{},
        notificationsEnabled: _notificationsEnabled,
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
