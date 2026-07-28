import 'package:flutter/material.dart';

import '../models.dart';
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

  @override
  void initState() {
    super.initState();
    year = widget.initialDate.year;
    month = widget.initialDate.month;
    day = widget.initialDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = ethiopianMonthLength(year, month);
    if (day > maxDay) day = maxDay;

    return AlertDialog(
      title: const Text('Select Ethiopian date'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(
                labelText: 'Year (EC)',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items: [
                for (int value = 2010; value <= 2040; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: (value) => setState(() => year = value ?? year),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: [
                for (int index = 0; index < ethiopianMonthNames.length; index++)
                  DropdownMenuItem(
                    value: index + 1,
                    child: Text(ethiopianMonthNames[index]),
                  ),
              ],
              onChanged: (value) => setState(() => month = value ?? month),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: day,
              decoration: const InputDecoration(labelText: 'Day'),
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
                'Gregorian equivalent: '
                '${MaterialLocalizations.of(context).formatMediumDate(
                  ethiopianToGregorian(
                    EthiopianDateValue(year: year, month: month, day: day),
                  ),
                )}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EthiopianDateValue(year: year, month: month, day: day),
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
