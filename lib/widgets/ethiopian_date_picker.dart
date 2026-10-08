import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/calendar_utils.dart';

Future<EthiopianDateValue?> showEthiopianDatePickerDialog({
  required BuildContext context,
  EthiopianDateValue? initialDate,
}) {
  final initial = initialDate ?? gregorianToEthiopian(DateTime.now());
  return showDialog<EthiopianDateValue>(
    context: context,
    builder: (context) => _EthiopianDatePickerDialog(initialDate: initial),
  );
}

class _EthiopianDatePickerDialog extends StatefulWidget {
  const _EthiopianDatePickerDialog({required this.initialDate});

  final EthiopianDateValue initialDate;

  @override
  State<_EthiopianDatePickerDialog> createState() =>
      _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState
    extends State<_EthiopianDatePickerDialog> {
  late int year;
  late int month;
  late int day;
  late final int firstYear;
  late final int lastYear;

  @override
  void initState() {
    super.initState();
    year = widget.initialDate.year;
    month = widget.initialDate.month;
    day = widget.initialDate.day;
    // A window around the current year that always contains the initial date.
    final currentYear = gregorianToEthiopian(DateTime.now()).year;
    firstYear = math.min(currentYear - 5, year);
    lastYear = math.max(currentYear + 20, year);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxDay = ethiopianMonthLength(year, month);
    if (day > maxDay) day = maxDay;

    return AlertDialog(
      title: Text(l10n.text('selectEthiopianDate')),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: year,
              decoration: InputDecoration(
                labelText: l10n.text('yearEc'),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              items: [
                for (int value = firstYear; value <= lastYear; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: (value) => setState(() => year = value ?? year),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: month,
              decoration: InputDecoration(labelText: l10n.text('month')),
              items: [
                for (int value = 1; value <= 13; value++)
                  DropdownMenuItem(
                    value: value,
                    child: Text(ethiopianMonthName(l10n, value)),
                  ),
              ],
              onChanged: (value) => setState(() => month = value ?? month),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              // Re-keyed because the valid days change with month and year.
              key: ValueKey('$year-$month-$maxDay'),
              initialValue: day,
              decoration: InputDecoration(labelText: l10n.text('day')),
              items: [
                for (int value = 1; value <= maxDay; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: (value) => setState(() => day = value ?? day),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.text('gregorianEquivalent', {
                  'date': MaterialLocalizations.of(context).formatMediumDate(
                    ethiopianToGregorian(
                      EthiopianDateValue(year: year, month: month, day: day),
                    ),
                  ),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.text('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EthiopianDateValue(year: year, month: month, day: day),
          ),
          child: Text(l10n.text('select')),
        ),
      ],
    );
  }
}
