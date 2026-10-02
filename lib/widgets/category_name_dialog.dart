import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class CategoryNameDialog extends StatefulWidget {
  const CategoryNameDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    this.initialValue = '',
    this.hintText,
    this.nameExists,
  });

  final String title;
  final String actionLabel;
  final String initialValue;
  final String? hintText;

  /// Returns true when another category already uses the name.
  final bool Function(String name)? nameExists;

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.l10n.text('categoryName'),
            hintText: widget.hintText,
          ),
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.isEmpty) return context.l10n.text('categoryRequired');
            if (widget.nameExists?.call(name) ?? false) {
              return context.l10n.text('categoryExists');
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.text('cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }
}
