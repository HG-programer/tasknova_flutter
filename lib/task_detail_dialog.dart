// task_detail_dialog.dart
import 'package:flutter/material.dart';
import 'task.dart';
import 'api_service.dart';
import 'subtask_list.dart';

class TaskDetailDialog extends StatefulWidget {
  final Task task;
  final ApiService apiService;
  final List<String> categories;
  final Function(Task) onTaskUpdated;

  const TaskDetailDialog({
    required this.task,
    required this.apiService,
    required this.categories,
    required this.onTaskUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late TextEditingController _contentController;
  late String _selectedCategory;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.task.content);
    _selectedCategory = widget.task.category;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updateTaskContent() async {
    final newContent = _contentController.text.trim();
    if (newContent.isEmpty || newContent == widget.task.content) return;

    setState(() => _isUpdating = true);
    try {
      // Assume you have an API method to update task content
      await widget.apiService.updateTaskContent(widget.task.id, newContent);

      setState(() {
        widget.task.content = newContent;
        _isUpdating = false;
      });
      widget.onTaskUpdated(widget.task);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateTaskCategory(String newCategory) async {
    if (newCategory == widget.task.category) return;

    setState(() => _isUpdating = true);
    try {
      await widget.apiService.updateTaskCategory(widget.task.id, newCategory);

      setState(() {
        widget.task.category = newCategory;
        _selectedCategory = newCategory;
        _isUpdating = false;
      });
      widget.onTaskUpdated(widget.task);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update category: $e')),
      );
      setState(() {
        _selectedCategory = widget.task.category;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.task.hasSubtasks
        ? (widget.task.completedSubtasks / widget.task.totalSubtasks)
        : null;

    return AlertDialog(
      title: const Text('Task Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task content editor
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Task Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onEditingComplete: _updateTaskContent,
            ),
            const SizedBox(height: 16),

            // Category selector
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: category == _selectedCategory,
                  onSelected: (_) => _updateTaskCategory(category),
                );
              }).toList(),
            ),

            // Progress indicator (if has subtasks)
            if (progress != null) ...[
              const SizedBox(height: 16),
              Text(
                'Progress: ${(progress * 100).toInt()}% (${widget.task.completedSubtasks}/${widget.task.totalSubtasks})',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ],

            // Divider before subtasks
            const Divider(height: 32),

            // Subtasks section
            Text('Subtasks', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SubtaskList(
              parentTask: widget.task,
              apiService: widget.apiService,
              onTaskUpdated: widget.onTaskUpdated,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
