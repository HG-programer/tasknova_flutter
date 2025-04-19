// lib/task_detail_dialog.dart
import 'package:flutter/material.dart';
import 'task.dart';
import 'api_service.dart';
import 'subtask_list.dart';

class TaskDetailDialog extends StatefulWidget {
  final Task task;
  final ApiService apiService;
  final List<String> categories;
  final Function(Task updatedTask) onTaskPossiblyUpdated;

  const TaskDetailDialog({
    required this.task,
    required this.apiService,
    required this.categories,
    required this.onTaskPossiblyUpdated,
    super.key,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late TextEditingController _contentController;
  late String _selectedCategory;
  bool _isUpdatingContent = false;
  bool _isUpdatingCategory = false;
  late Task _localTask; // Use a local copy for state management

  @override
  void initState() {
    super.initState();
    _localTask = Task.copyWith(widget.task); // Create a deep copy
    _contentController = TextEditingController(text: _localTask.content);
    _selectedCategory = _localTask.category;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateTaskContent() async {
    FocusScope.of(context).unfocus();
    final newContent = _contentController.text.trim();
    if (newContent.isEmpty ||
        newContent == _localTask.content ||
        _isUpdatingContent) {
      return;
    }

    setState(() => _isUpdatingContent = true);
    try {
      await widget.apiService.updateTaskContent(_localTask.id, newContent);
      if (mounted) {
        setState(() {
          _localTask.content = newContent;
        });
        widget.onTaskPossiblyUpdated(_localTask);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update task content: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingContent = false);
    }
  }

  Future<void> _updateTaskCategory(String newCategory) async {
    if (newCategory == _selectedCategory || _isUpdatingCategory) return;
    setState(() => _isUpdatingCategory = true);
    final previousCategory = _selectedCategory;
    setState(() {
      _selectedCategory = newCategory;
      _localTask.category = newCategory;
    }); // Optimistic UI update

    try {
      await widget.apiService.updateTaskCategory(_localTask.id, newCategory);
      widget.onTaskPossiblyUpdated(_localTask);
    } catch (e) {
      _showErrorSnackBar('Failed to update category: $e');
      if (mounted) {
        // Revert on failure
        setState(() {
          _selectedCategory = previousCategory;
          _localTask.category = previousCategory;
        });
      }
    } finally {
      if (mounted) setState(() => _isUpdatingCategory = false);
    }
  }

  // Handler for updates coming from SubtaskList
  void _handleSubtaskUpdate(Task updatedParentTaskFromSubtaskList) {
    if (mounted) {
      setState(() {
        _localTask = Task.copyWith(updatedParentTaskFromSubtaskList);
      });
      widget.onTaskPossiblyUpdated(_localTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "Build Detail Dialog for Task ${_localTask.id}: Recurrence Type = ${_localTask.recurrenceType}");
    final theme = Theme.of(context);
    final int totalSubs = _localTask.totalSubtasks;
    final int completedSubs = _localTask.completedSubtasks;
    // Compute progress only if there is at least one subtask.
    final double? progress =
        (totalSubs > 0) ? (completedSubs / totalSubs) : null;
    bool isUpdating = _isUpdatingContent || _isUpdatingCategory;

    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
      contentPadding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
      actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
              child: Text('Task Details', overflow: TextOverflow.ellipsis)),
          if (isUpdating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task content editor
          TextField(
            controller: _contentController,
            enabled: !_isUpdatingContent,
            decoration: InputDecoration(
              labelText: 'Task Description',
              suffixIcon: _isUpdatingContent
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            maxLines: null,
            minLines: 1,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.done,
            onEditingComplete: _updateTaskContent,
          ),
          const SizedBox(height: 16),
          // Category selector
          Text('Category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AbsorbPointer(
            absorbing: isUpdating,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.categories.map((category) {
                final isSelected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => _updateTaskCategory(category),
                  tooltip: 'Set category to $category',
                );
              }).toList(),
            ),
          ),
          // Progress indicator: Only show if there are subtasks
          if (totalSubs > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Subtask Progress: ${(progress! * 100).toInt()}% ($completedSubs/$totalSubs)',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
          // Subtasks Section
          const Divider(height: 32),
          Text('Subtasks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          SubtaskList(
            parentTask: _localTask,
            apiService: widget.apiService,
            onTaskUpdated: _handleSubtaskUpdate,
          ),
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
