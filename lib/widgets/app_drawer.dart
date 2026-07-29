import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

class ReminderAppDrawer extends StatelessWidget {
  const ReminderAppDrawer({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
  });

  final AppController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddCategory;
  final ValueChanged<TaskCategory> onEditCategory;
  final ValueChanged<TaskCategory> onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADL Reminder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(context.l10n.text('tagline')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: Text(context.l10n.text('allTasks')),
              selected: controller.selectedCategoryId == null,
              onTap: () {
                controller.selectCategory(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.today_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.l10n.text('todaysTasks')),
              trailing: _CountBadge(
                count: controller.categoryTaskCount(
                  AppController.todayCategoryId,
                ),
              ),
              selected:
                  controller.selectedCategoryId ==
                  AppController.todayCategoryId,
              onTap: () {
                controller.selectCategory(AppController.todayCategoryId);
                Navigator.pop(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 6),
              child: Row(
                children: [
                  Text(
                    context.l10n.text('categories'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.l10n.text('addCategory'),
                    onPressed: onAddCategory,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: controller.categories.length,
                itemBuilder: (context, index) {
                  final category = controller.categories[index];
                  return ListTile(
                    leading: Icon(category.icon, color: category.color),
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountBadge(
                          count: controller.categoryTaskCount(category.id),
                        ),
                        IconButton(
                          tooltip: context.l10n.text('editCategory'),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => onEditCategory(category),
                        ),
                        IconButton(
                          tooltip: context.l10n.text('deleteCategory'),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => onDeleteCategory(category),
                        ),
                      ],
                    ),
                    selected: controller.selectedCategoryId == category.id,
                    onTap: () {
                      controller.selectCategory(category.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
              child: Row(
                children: [
                  const Icon(Icons.language_outlined),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      context.l10n.text('language'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SegmentedButton<AppLanguage>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppLanguage.english,
                        label: Text('EN'),
                      ),
                      ButtonSegment(
                        value: AppLanguage.amharic,
                        label: Text('አማ'),
                      ),
                    ],
                    selected: {controller.language},
                    onSelectionChanged: (selection) {
                      controller.setLanguage(selection.first);
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.l10n.text('settings')),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
