import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

/// All reminders: search, status filter (with totals) and categories.
class ListsScreen extends StatefulWidget {
  const ListsScreen({
    super.key,
    required this.controller,
    required this.actions,
    required this.searchFocus,
  });

  final AppController controller;
  final HomeActions actions;
  final FocusNode searchFocus;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  DashboardTaskState _status = DashboardTaskState.active;
  final TextEditingController _search = TextEditingController();

  AppController get _controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = _controller.tasksFor(_status);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text(l10n.text('tabLists'), style: displayStyle(28)),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            focusNode: widget.searchFocus,
            onChanged: _controller.setSearchQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.text('searchHint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.text('closeSearch'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _controller.setSearchQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (index, state) in DashboardTaskState.values.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: _StatusTile(
                      label: l10n.text(switch (state) {
                        DashboardTaskState.active => 'upcoming',
                        DashboardTaskState.overdue => 'overdue',
                        DashboardTaskState.completed => 'done',
                      }),
                      count: _controller.tasksFor(state).length,
                      selected: _status == state,
                      warning: state == DashboardTaskState.overdue,
                      onTap: () => setState(() => _status = state),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CategoryChip(
                label: l10n.text('all'),
                selected: _controller.selectedCategoryId == null,
                onTap: () => _controller.selectCategory(null),
              ),
              _CategoryChip(
                label: l10n.text('todaysTasks'),
                selected:
                    _controller.selectedCategoryId ==
                    AppController.todayCategoryId,
                onTap: () =>
                    _controller.selectCategory(AppController.todayCategoryId),
              ),
              for (final category in _controller.categories)
                _CategoryChip(
                  label: category.name,
                  dot: category.color,
                  count: _controller.categoryTaskCount(category.id),
                  selected: _controller.selectedCategoryId == category.id,
                  onTap: () => _controller.selectCategory(category.id),
                  onLongPress: () => widget.actions.manageCategory(category),
                ),
              IconButton(
                tooltip: l10n.text('addCategory'),
                onPressed: widget.actions.addCategory,
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
          const SizedBox(height: 6),
          Text(
            l10n.text('categoryActions'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            _emptyState(l10n)
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ReminderCard(
                  controller: _controller,
                  task: task,
                  onOpen: widget.actions.openTask,
                ),
              ),
        ],
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    if (_controller.searchQuery.isNotEmpty) {
      return EmptyMessage(
        icon: Icons.search_off_outlined,
        title: l10n.text('noMatches'),
        message: l10n.text('differentSearch'),
      );
    }
    final (icon, title, message) = switch (_status) {
      DashboardTaskState.active => (
        Icons.checklist_rounded,
        'noActive',
        'createNext',
      ),
      DashboardTaskState.overdue => (
        Icons.event_available_outlined,
        'nothingOverdue',
        'caughtUp',
      ),
      DashboardTaskState.completed => (
        Icons.task_alt,
        'noCompleted',
        'completedAppear',
      ),
    };
    return EmptyMessage(
      icon: icon,
      title: l10n.text(title),
      message: l10n.text(message),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.warning,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: displayStyle(
                    26,
                    color: warning && count > 0 && !selected
                        ? AppColors.missed
                        : foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.mutedOnInk : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.dot,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? dot;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      onLongPressHint: onLongPress == null
          ? null
          : context.l10n.text('editCategory'),
      child: Material(
        color: selected ? AppColors.ink : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? AppColors.mutedOnInk : AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
