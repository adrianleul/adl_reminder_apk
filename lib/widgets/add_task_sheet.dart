import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/calendar_utils.dart';
import 'category_name_dialog.dart';
import 'ethiopian_date_picker.dart';
import 'ui.dart';

/// How often a reminder repeats, as offered in the composer.
enum Frequency { once, range, daily, weekly, monthly, yearly }

Frequency frequencyOf(ReminderSchedule schedule) => switch (schedule.type) {
  ReminderType.specificDate => Frequency.once,
  ReminderType.dateRange => Frequency.range,
  ReminderType.everyday => Frequency.daily,
  ReminderType.custom => switch (schedule.recurrenceUnit) {
    RecurrenceUnit.weekly || null => Frequency.weekly,
    RecurrenceUnit.monthly => Frequency.monthly,
    RecurrenceUnit.yearly => Frequency.yearly,
  },
};

/// Creates a reminder, or edits [initialTask]. The top of the sheet reads as
/// a sentence ("Remind me to … every month on day 5 at 8:30 with an alarm")
/// whose underlined parts open the matching control. Pops with the resulting
/// task; the caller saves it (after asking for notification permission).
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, required this.controller, this.initialTask});

  final AppController controller;
  final ReminderTask? initialTask;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  final List<TextEditingController> _stepControllers = [];

  /// Existing steps, parallel to [_stepControllers] (null = new).
  final List<SubTask?> _existingSteps = [];

  String? _categoryId;
  bool _withSteps = false;
  Frequency _frequency = Frequency.once;
  CalendarSystem _calendar = CalendarSystem.ethiopian;
  DateTime _startDate = dateOnly(DateTime.now().add(const Duration(days: 1)));
  DateTime _endDate = dateOnly(DateTime.now().add(const Duration(days: 2)));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = <int>{DateTime.monday};
  ReminderDelivery _delivery = ReminderDelivery.notification;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    final controller = widget.controller;
    final task = widget.initialTask;
    if (task != null) {
      final schedule = task.schedule;
      _categoryId = task.categoryId;
      _titleController.text = task.title;
      _withSteps = task.subTasks.isNotEmpty;
      for (final step in task.subTasks) {
        _stepControllers.add(TextEditingController(text: step.title));
        _existingSteps.add(step);
      }
      _frequency = frequencyOf(schedule);
      _calendar = schedule.calendarSystem;
      if (schedule.date != null) _startDate = dateOnly(schedule.date!);
      _endDate = schedule.endDate != null
          ? dateOnly(schedule.endDate!)
          : _startDate;
      _time = schedule.time;
      if (schedule.weekdays.isNotEmpty) {
        _weekdays
          ..clear()
          ..addAll(schedule.weekdays);
      }
      _delivery = schedule.delivery;
      return;
    }

    final selectedId = controller.selectedCategoryId;
    _categoryId =
        selectedId != null && controller.categoryById(selectedId) != null
        ? selectedId
        : (controller.categories.isNotEmpty
              ? controller.categories.first.id
              : null);
    _calendar = controller.settings.defaultCalendar;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    for (final controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  ReminderSchedule _buildSchedule() {
    final (type, unit) = switch (_frequency) {
      Frequency.once => (ReminderType.specificDate, null),
      Frequency.range => (ReminderType.dateRange, null),
      Frequency.daily => (ReminderType.everyday, null),
      Frequency.weekly => (ReminderType.custom, RecurrenceUnit.weekly),
      Frequency.monthly => (ReminderType.custom, RecurrenceUnit.monthly),
      Frequency.yearly => (ReminderType.custom, RecurrenceUnit.yearly),
    };
    return ReminderSchedule(
      type: type,
      calendarSystem: _calendar,
      date: type == ReminderType.everyday ? null : _startDate,
      endDate: type == ReminderType.dateRange ? _endDate : null,
      time: _time,
      recurrenceUnit: unit,
      weekdays: unit == RecurrenceUnit.weekly
          ? Set<int>.unmodifiable(_weekdays)
          : const <int>{},
      delivery: _delivery,
    );
  }

  String _formatDate(DateTime date) =>
      formatCalendarDate(context, date, _calendar);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.94,
        minChildSize: 0.6,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return Material(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            clipBehavior: Clip.antiAlias,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4D6DC),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.text(_isEditing ? 'editTask' : 'newTask'),
                                style: displayStyle(22),
                              ),
                            ),
                            SquareIconButton(
                              icon: Icons.close,
                              tooltip: l10n.text('close'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSentence(context),
                        const SizedBox(height: 24),
                        ..._buildControls(context),
                      ],
                    ),
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // The sentence

  Widget _buildSentence(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final title = _titleController.text.trim();
    final slots = <String, (String, VoidCallback?)>{
      'title': (
        title.isEmpty ? l10n.text('titlePlaceholder') : title,
        _titleFocus.requestFocus,
      ),
      'date': (_formatDate(_startDate), () => _pickDate(isEnd: false)),
      'start': (_formatDate(_startDate), () => _pickDate(isEnd: false)),
      'end': (_formatDate(_endDate), () => _pickDate(isEnd: true)),
      'day': (
        '${_calendar == CalendarSystem.ethiopian ? gregorianToEthiopian(_startDate).day : _startDate.day}',
        () => _pickDate(isEnd: false),
      ),
      'days': (
        [
          for (final day in weekdayDisplayOrder)
            if (_weekdays.contains(day)) weekdayName(l10n, day),
        ].join(', '),
        null,
      ),
      'time': (material.formatTimeOfDay(_time), _pickTime),
      'delivery': (
        l10n.text(
          _delivery == ReminderDelivery.alarm
              ? 'deliveryAlarmPhrase'
              : 'deliveryNotificationPhrase',
        ),
        () => setState(
          () => _delivery = _delivery == ReminderDelivery.alarm
              ? ReminderDelivery.notification
              : ReminderDelivery.alarm,
        ),
      ),
    };
    if (_frequency == Frequency.yearly) {
      slots['date'] = (
        _calendar == CalendarSystem.ethiopian
            ? '${ethiopianMonthName(l10n, gregorianToEthiopian(_startDate).month)} '
                  '${gregorianToEthiopian(_startDate).day}'
            : material.formatShortMonthDay(_startDate),
        () => _pickDate(isEnd: false),
      );
    }

    final template = l10n.text(switch (_frequency) {
      Frequency.once => 'sentenceOnce',
      Frequency.range => 'sentenceRange',
      Frequency.daily => 'sentenceDaily',
      Frequency.weekly => 'sentenceWeekly',
      Frequency.monthly => 'sentenceMonthly',
      Frequency.yearly => 'sentenceYearly',
    });

    final plain = displayStyle(
      26,
      weight: FontWeight.w600,
      color: AppColors.muted,
    ).copyWith(height: 1.3);
    final children = <Widget>[];
    var last = 0;
    for (final match in RegExp(r'\{(\w+)\}').allMatches(template)) {
      for (final word in template.substring(last, match.start).split(' ')) {
        if (word.isNotEmpty) children.add(Text(word, style: plain));
      }
      final slot = slots[match.group(1)];
      if (slot != null) {
        children.add(_SentenceSlot(text: slot.$1, onTap: slot.$2));
      }
      last = match.end;
    }
    for (final word in template.substring(last).split(' ')) {
      if (word.isNotEmpty) children.add(Text(word, style: plain));
    }
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: children,
    );
  }

  // ---------------------------------------------------------------------------
  // Controls

  List<Widget> _buildControls(BuildContext context) {
    final l10n = context.l10n;
    return [
      TextFormField(
        controller: _titleController,
        focusNode: _titleFocus,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.text('taskTitle'),
          hintText: l10n.text('taskExample'),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? l10n.text('enterTask')
            : null,
      ),
      const SizedBox(height: 22),
      SectionLabel(l10n.text('howOften')),
      const SizedBox(height: 10),
      PillGroup<Frequency>(
        options: [
          PillOption(Frequency.once, l10n.text('oneTime')),
          PillOption(Frequency.range, l10n.text('dateRange')),
          PillOption(Frequency.daily, l10n.text('daily')),
          PillOption(Frequency.weekly, l10n.text('weekly')),
          PillOption(Frequency.monthly, l10n.text('monthly')),
          PillOption(Frequency.yearly, l10n.text('yearly')),
        ],
        selected: _frequency,
        onSelected: (value) => setState(() => _frequency = value),
      ),
      if (_frequency == Frequency.weekly) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final day in weekdayDisplayOrder)
              FilterChip(
                label: Text(weekdayName(l10n, day)),
                selected: _weekdays.contains(day),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _weekdays.add(day);
                  } else if (_weekdays.length > 1) {
                    _weekdays.remove(day);
                  }
                }),
              ),
          ],
        ),
      ],
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: SectionLabel(l10n.text('notificationDateTime'))),
          SizedBox(
            width: 180,
            child: PillGroup<CalendarSystem>(
              expand: true,
              options: [
                PillOption(CalendarSystem.ethiopian, l10n.text('ethiopian')),
                PillOption(CalendarSystem.gregorian, l10n.text('gregorian')),
              ],
              selected: _calendar,
              onSelected: (value) => setState(() => _calendar = value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_frequency == Frequency.range)
        Row(
          children: [
            Expanded(
              child: _dateTile(context, label: 'startDate', isEnd: false),
            ),
            const SizedBox(width: 8),
            Expanded(child: _dateTile(context, label: 'endDate', isEnd: true)),
          ],
        )
      else
        Row(
          children: [
            if (_frequency != Frequency.daily) ...[
              Expanded(
                child: _dateTile(
                  context,
                  label: _frequency == Frequency.once
                      ? 'dateLabel'
                      : 'startsOn',
                  isEnd: false,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _timeTile(context)),
          ],
        ),
      if (_frequency == Frequency.range) ...[
        const SizedBox(height: 8),
        _timeTile(context),
      ],
      const SizedBox(height: 22),
      SectionLabel(l10n.text('deliveryType')),
      const SizedBox(height: 10),
      PillGroup<ReminderDelivery>(
        expand: true,
        options: [
          PillOption(
            ReminderDelivery.notification,
            l10n.text('notification'),
            icon: Icons.notifications_none,
          ),
          PillOption(
            ReminderDelivery.alarm,
            l10n.text('alarm'),
            icon: Icons.alarm,
          ),
        ],
        selected: _delivery,
        onSelected: (value) => setState(() => _delivery = value),
      ),
      const SizedBox(height: 6),
      Text(
        l10n.text(
          _delivery == ReminderDelivery.alarm
              ? 'alarmDeliveryHelp'
              : 'notificationDeliveryHelp',
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 22),
      SectionLabel(l10n.text('category')),
      const SizedBox(height: 10),
      FormField<String>(
        initialValue: _categoryId,
        validator: (_) =>
            _categoryId == null ? l10n.text('selectCategory') : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PillGroup<String?>(
                  options: [
                    for (final category in widget.controller.categories)
                      PillOption(category.id, category.name),
                  ],
                  selected: _categoryId,
                  onSelected: (value) {
                    setState(() => _categoryId = value);
                    field.didChange(value);
                  },
                ),
                IconButton(
                  tooltip: l10n.text('addCategory'),
                  onPressed: () async {
                    await _addCategory();
                    field.didChange(_categoryId);
                  },
                  icon: const Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.line, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          l10n.text('multipleTasks'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(l10n.text('multipleTasksHelp')),
        value: _withSteps,
        onChanged: (value) => setState(() {
          _withSteps = value ?? false;
          while (_withSteps && _stepControllers.length < 2) {
            _stepControllers.add(TextEditingController());
            _existingSteps.add(null);
          }
        }),
      ),
      if (_withSteps) ...[
        for (var index = 0; index < _stepControllers.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: _stepControllers[index],
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.text('subtask', {'count': index + 1}),
                suffixIcon: _stepControllers.length > 2
                    ? IconButton(
                        tooltip: l10n.text('removeSubtask'),
                        onPressed: () => _removeStep(index),
                        icon: const Icon(Icons.remove_circle_outline),
                      )
                    : null,
              ),
              validator: (value) =>
                  _withSteps && (value == null || value.trim().isEmpty)
                  ? l10n.text('enterSubtask')
                  : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _stepControllers.add(TextEditingController());
              _existingSteps.add(null);
            }),
            icon: const Icon(Icons.add),
            label: Text(l10n.text('addSubtask')),
          ),
        ),
      ],
    ];
  }

  Widget _dateTile(
    BuildContext context, {
    required String label,
    required bool isEnd,
  }) {
    final date = isEnd ? _endDate : _startDate;
    final other = _calendar == CalendarSystem.ethiopian
        ? MaterialLocalizations.of(context).formatMediumDate(date)
        : formatEthiopianDate(context.l10n, gregorianToEthiopian(date));
    return _PickerTile(
      icon: Icons.calendar_today_outlined,
      label: context.l10n.text(label),
      value: _formatDate(date),
      detail: other,
      onTap: () => _pickDate(isEnd: isEnd),
    );
  }

  Widget _timeTile(BuildContext context) {
    return _PickerTile(
      icon: Icons.schedule,
      label: context.l10n.text('reminderTime'),
      value: MaterialLocalizations.of(context).formatTimeOfDay(_time),
      onTap: _pickTime,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final next = _buildSchedule().nextOccurrenceAfter(now);
    final String headline;
    final String detail;
    if (next == null) {
      headline = l10n.text('timeAlreadyPassed');
      detail = l10n.text('chooseAnotherTime');
    } else {
      headline = l10n.text('firstReminder', {
        'date':
            '${formatCalendarDate(context, next, _calendar)} · '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(next))}',
      });
      detail = l10n.text(
        _delivery == ReminderDelivery.alarm ? 'alarmIn' : 'reminderIn',
        {'time': formatTimeUntil(l10n, next.difference(now))},
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.surface)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: next == null ? AppColors.missedFill : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    _delivery == ReminderDelivery.alarm
                        ? Icons.alarm
                        : Icons.notifications_none,
                    color: next == null ? AppColors.missed : AppColors.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontFamily: bodyFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _saveTask,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.text(_isEditing ? 'saveChanges' : 'setReminder')),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pickers and saving

  void _setStart(DateTime value) {
    _startDate = dateOnly(value);
    if (_endDate.isBefore(_startDate)) _endDate = _startDate;
  }

  void _setEnd(DateTime value) {
    final end = dateOnly(value);
    _endDate = end.isBefore(_startDate) ? _startDate : end;
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final today = dateOnly(DateTime.now());
    if (_calendar == CalendarSystem.gregorian) {
      final initial = isEnd ? _endDate : _startDate;
      final first = isEnd
          ? _startDate
          : today.subtract(const Duration(days: 365));
      final selected = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(first) ? first : initial,
        firstDate: first,
        lastDate: today.add(const Duration(days: 3650)),
      );
      if (selected != null && mounted) {
        setState(() => isEnd ? _setEnd(selected) : _setStart(selected));
      }
      return;
    }

    final selected = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: gregorianToEthiopian(isEnd ? _endDate : _startDate),
    );
    if (selected != null && mounted) {
      final gregorian = ethiopianToGregorian(selected);
      setState(() => isEnd ? _setEnd(gregorian) : _setStart(gregorian));
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
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
            'date': _formatDate(scheduledAt),
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
        nameExists: widget.controller.categoryNameExists,
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      final category = widget.controller.addCategory(name);
      setState(() => _categoryId = category.id);
    }
  }

  void _removeStep(int index) {
    _stepControllers.removeAt(index).dispose();
    _existingSteps.removeAt(index);
    setState(() {});
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final schedule = _buildSchedule();
    if (_frequency == Frequency.once) {
      final scheduledAt = schedule.firstOccurrence!;
      // Renaming an overdue task should not force a new date.
      final unchanged =
          widget.initialTask?.schedule.type == ReminderType.specificDate &&
          widget.initialTask?.schedule.firstOccurrence == scheduledAt;
      if (!unchanged && !scheduledAt.isAfter(DateTime.now())) {
        await _showPastTimeDialog(scheduledAt);
        return;
      }
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final steps = <SubTask>[
      if (_withSteps)
        for (var index = 0; index < _stepControllers.length; index++)
          _existingSteps[index]?.copyWith(
                title: _stepControllers[index].text.trim(),
              ) ??
              SubTask(
                id: 'sub-$stamp-$index',
                title: _stepControllers[index].text.trim(),
              ),
    ];

    final original = widget.initialTask;
    final task = original == null
        ? ReminderTask(
            id: 'task-$stamp',
            categoryId: _categoryId!,
            title: _titleController.text.trim(),
            schedule: schedule,
            subTasks: steps,
          )
        : original.copyWith(
            categoryId: _categoryId,
            title: _titleController.text.trim(),
            schedule: schedule,
            subTasks: steps,
          );

    if (mounted) Navigator.pop(context, task);
  }
}

/// An underlined, tappable part of the composer sentence.
class _SentenceSlot extends StatelessWidget {
  const _SentenceSlot({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Container(
      padding: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Text(text, style: displayStyle(26).copyWith(height: 1.3)),
    );
    if (onTap == null) return label;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: label,
      ),
    );
  }
}

/// A date or time value with its label, opening a picker when tapped.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
