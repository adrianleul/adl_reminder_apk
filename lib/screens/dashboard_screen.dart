import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/app_drawer.dart';
import '../widgets/task_list.dart';
import '../widgets/task_summary.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
  });

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
        TaskCategory? selectedCategory;
        for (final category in widget.controller.categories) {
          if (category.id == widget.controller.selectedCategoryId) {
            selectedCategory = category;
            break;
          }
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: _searchVisible
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search tasks and subtasks',
                        border: InputBorder.none,
                      ),
                      onChanged: widget.controller.setSearchQuery,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My reminders'),
                        if (selectedCategory != null)
                          Text(
                            selectedCategory.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
              actions: [
                IconButton(
                  tooltip: _searchVisible ? 'Close search' : 'Search tasks',
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
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Active'),
                  Tab(text: 'Overdue'),
                  Tab(text: 'Completed'),
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
                    builder: (_) => SettingsScreen(controller: widget.controller),
                  ),
                );
              },
              onAddCategory: () => _showAddCategoryDialog(closeDrawer: true),
            ),
            body: Column(
              children: [
                TaskSummaryCard(controller: widget.controller),
                Expanded(
                  child: TabBarView(
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
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openAddTask,
              icon: const Icon(Icons.add),
              label: const Text('New task'),
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
        SnackBar(content: Text('“${task.title}” was created.')),
      );
    }
  }

  Future<void> _showAddCategoryDialog({bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'Example: Bills',
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
      widget.controller.selectCategory(category.id);
    }
  }
}
