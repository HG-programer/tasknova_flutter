// subtask_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'task.dart';
import 'api_service.dart';

class SubtaskList extends StatefulWidget {
  final Task parentTask;
  final ApiService apiService;
  final Function(Task) onTaskUpdated;

  const SubtaskList({
    required this.parentTask,
    required this.apiService,
    required this.onTaskUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends State<SubtaskList> {
  final TextEditingController _subtaskController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final content = _subtaskController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final newSubtask =
          await widget.apiService.addSubtask(widget.parentTask.id, content);
      setState(() {
        widget.parentTask.subtasks.add(newSubtask);
        _subtaskController.clear();
      });
      widget.onTaskUpdated(widget.parentTask);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add subtask: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSubtaskCompletion(Task subtask) async {
    final originalState = subtask.completed;

    // Optimistic update
    setState(() {
      subtask.completed = !originalState;
      HapticFeedback.lightImpact();
    });

    try {
      final confirmedState = await widget.apiService.updateTaskCompletion(
        subtask.id,
        !originalState,
      );

      if (mounted && confirmedState != subtask.completed) {
        setState(() {
          subtask.completed = confirmedState;
        });
      }

      widget.onTaskUpdated(widget.parentTask);
    } catch (e) {
      if (mounted) {
        setState(() {
          subtask.completed = originalState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subtask: $e')),
        );
      }
    }
  }

  Future<void> _deleteSubtask(Task subtask) async {
    // Store index before removal for potential restoration
    final index = widget.parentTask.subtasks.indexOf(subtask);

    // Optimistic removal
    setState(() {
      widget.parentTask.subtasks.remove(subtask);
      HapticFeedback.lightImpact();
    });

    try {
      await widget.apiService.deleteTask(subtask.id);
      widget.onTaskUpdated(widget.parentTask);
    } catch (e) {
      if (mounted) {
        // Restore the subtask if deletion failed
        setState(() {
          if (index >= 0 && index <= widget.parentTask.subtasks.length) {
            widget.parentTask.subtasks.insert(index, subtask);
          } else {
            widget.parentTask.subtasks.add(subtask);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete subtask: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtask input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  decoration: InputDecoration(
                    hintText: 'Add a subtask...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                onPressed: _isLoading ? null : _addSubtask,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),

        // Subtasks list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.parentTask.subtasks.length,
          itemBuilder: (context, index) {
            final subtask = widget.parentTask.subtasks[index];
            return ListTile(
              dense: true,
              leading: Checkbox(
                value: subtask.completed,
                onChanged: (_) => _toggleSubtaskCompletion(subtask),
              ),
              title: Text(
                subtask.content,
                style: subtask.completed
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      )
                    : null,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteSubtask(subtask),
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
            );
          },
        ),
      ],
    );
  }
}
