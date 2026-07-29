import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/app_drawer.dart';
import '../widgets/category_name_dialog.dart';
import '../widgets/task_list.dart';
import '../widgets/task_summary.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final l10n = context.l10n;
        TaskCategory? selectedCategory;
        for (final category in widget.controller.categories) {
          if (category.id == widget.controller.selectedCategoryId) {
            selectedCategory = category;
            break;
          }
        }
        final selectedTitle =
            widget.controller.selectedCategoryId ==
                AppController.todayCategoryId
            ? l10n.text('todaysTasks')
            : selectedCategory?.name;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: _searchVisible
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.text('searchHint'),
                        border: InputBorder.none,
                      ),
                      onChanged: widget.controller.setSearchQuery,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.text('myReminders')),
                        if (selectedTitle != null)
                          Text(
                            selectedTitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
              actions: [
                IconButton(
                  tooltip: _searchVisible
                      ? l10n.text('closeSearch')
                      : l10n.text('searchTasks'),
                  onPressed: () {
                    setState(() {
                      _searchVisible = !_searchVisible;
                      if (!_searchVisible) {
                        _searchController.clear();
                        widget.controller.setSearchQuery('');
                      }
                    });
                  },
                  icon: Icon(_searchVisible ? Icons.close : Icons.search),
                ),
                const SizedBox(width: 4),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.text('active')),
                  Tab(text: l10n.text('overdue')),
                  Tab(text: l10n.text('completed')),
                ],
              ),
            ),
            drawer: ReminderAppDrawer(
              controller: widget.controller,
              onOpenSettings: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SettingsScreen(controller: widget.controller),
                  ),
                );
              },
              onAddCategory: () => _showAddCategoryDialog(closeDrawer: true),
              onEditCategory: _showEditCategoryDialog,
              onDeleteCategory: _showDeleteCategoryDialog,
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: TaskSummaryCard(controller: widget.controller),
                ),
              ],
              body: TabBarView(
                children: [
                  CategorizedTaskList(
                    controller: widget.controller,
                    state: DashboardTaskState.active,
                  ),
                  CategorizedTaskList(
                    controller: widget.controller,
                    state: DashboardTaskState.overdue,
                  ),
                  CategorizedTaskList(
                    controller: widget.controller,
                    state: DashboardTaskState.completed,
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openAddTask,
              icon: const Icon(Icons.add),
              label: Text(l10n.text('newTask')),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddTask() async {
    final task = await showModalBottomSheet<ReminderTask>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(controller: widget.controller),
    );

    if (task != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text('created', {'title': task.title})),
        ),
      );
    }
  }

  Future<void> _showAddCategoryDialog({bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => CategoryNameDialog(
        title: context.l10n.text('addCategory'),
        actionLabel: context.l10n.text('add'),
        hintText: context.l10n.text('categoryExample'),
      ),
    );

    if (name != null && name.trim().isNotEmpty && mounted) {
      final category = widget.controller.addCategory(name);
      widget.controller.selectCategory(category.id);
    }
  }

  Future<void> _showEditCategoryDialog(TaskCategory category) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => CategoryNameDialog(
        title: context.l10n.text('editCategory'),
        actionLabel: context.l10n.text('save'),
        initialValue: category.name,
      ),
    );
    if (name != null && mounted) {
      widget.controller.renameCategory(category, name);
    }
  }

  Future<void> _showDeleteCategoryDialog(TaskCategory category) async {
    final taskCount = widget.controller.categoryTaskCount(category.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(context.l10n.text('deleteCategory')),
        content: Text(
          context.l10n.text('deleteCategoryMessage', {
            'name': category.name,
            'count': taskCount,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.controller.deleteCategory(category);
    }
  }
}
