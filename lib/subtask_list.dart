// lib/subtask_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'task.dart';
import 'api_service.dart';
import 'task_detail_dialog.dart'; // Import the dialog to open it recursively

class SubtaskList extends StatefulWidget {
  final Task parentTask;
  final ApiService apiService;
  final Function(Task) onTaskUpdated;

  const SubtaskList({
    required this.parentTask,
    required this.apiService,
    required this.onTaskUpdated,
    super.key,
  });

  @override
  State<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends State<SubtaskList> {
  final TextEditingController _subtaskController = TextEditingController();
  bool _isLoadingAdd = false; // Renamed for clarity

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  // Helper to show snackbar errors within this context
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating, // Consistent floating behavior
      ),
    );
  }

  Future<void> _addSubtask() async {
    final content = _subtaskController.text.trim();
    if (content.isEmpty || _isLoadingAdd) {
      return; // Prevent adding empty or during load
    }

    setState(() => _isLoadingAdd = true);
    try {
      final newSubtask = await widget.apiService.addSubtask(
        widget.parentTask.id,
        content,
        // Optionally: inherit category if desired.
      );
      if (mounted) {
        setState(() {
          widget.parentTask.subtasks.add(newSubtask); // Add to parent's list
          _subtaskController.clear();
        });
        widget.onTaskUpdated(
            widget.parentTask); // Notify parent (e.g. TaskDetailDialog)
      }
    } catch (e) {
      if (mounted) _showError('Failed to add subtask: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAdd = false);
    }
  }

  Future<void> _toggleSubtaskCompletion(Task subtask) async {
    if (!mounted) return;
    final originalState = subtask.completed;

    // Recalculate the current index.
    int currentIndex =
        widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
    if (currentIndex == -1) return; // Safety check

    // Optimistic update: recalc index just before modifying.
    setState(() {
      int index =
          widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
      if (index != -1) {
        widget.parentTask.subtasks[index].completed = !originalState;
      }
    });
    HapticFeedback.lightImpact();
    widget.onTaskUpdated(widget.parentTask); // Notify parent immediately

    try {
      final confirmedState = await widget.apiService.updateTaskCompletion(
        subtask.id,
        !originalState,
      );
      if (mounted) {
        // Recalculate the index again.
        int index =
            widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
        if (index != -1 &&
            confirmedState != widget.parentTask.subtasks[index].completed) {
          setState(() {
            widget.parentTask.subtasks[index].completed = confirmedState;
          });
          widget.onTaskUpdated(widget.parentTask);
        }
      }
    } catch (e) {
      if (mounted) {
        // Recalculate the index before reverting the change.
        int index =
            widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
        if (index != -1) {
          setState(() {
            widget.parentTask.subtasks[index].completed = originalState;
          });
          widget.onTaskUpdated(widget.parentTask);
        }
        _showError('Failed to update subtask: $e');
      }
    }
  }

  Future<void> _deleteSubtask(Task subtask) async {
    if (!mounted) return;
    final index =
        widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
    if (index == -1) return;

    // Store a copy in case deletion fails
    final subtaskToDeleteCopy = Task.copyWith(subtask);

    // Optimistic removal
    setState(() {
      widget.parentTask.subtasks.removeAt(index);
    });
    HapticFeedback.lightImpact();
    widget.onTaskUpdated(widget.parentTask); // Notify parent

    try {
      await widget.apiService.deleteTask(subtask.id);
      // Deletion successful. You might add further feedback if needed.
    } catch (e) {
      if (mounted) {
        // Restore the subtask if deletion failed
        setState(() {
          widget.parentTask.subtasks.insert(index, subtaskToDeleteCopy);
        });
        widget.onTaskUpdated(widget.parentTask); // Notify parent of revert
        _showError('Failed to delete subtask: $e');
      }
    }
  }

  // --- Open Detail Dialog for a SUBTASK (Recursive!) ---
  void _openSubtaskDetailDialog(Task subtask) {
    final int subtaskIndex =
        widget.parentTask.subtasks.indexWhere((t) => t.id == subtask.id);
    if (subtaskIndex == -1) return;

    try {
      // Log the call for debugging:
      print("Opening detail dialog for subtask with id: ${subtask.id}");
      final ancestorDialog =
          context.findAncestorWidgetOfExactType<TaskDetailDialog>();
      print("Ancestor dialog: $ancestorDialog");
      // Inherit categories if available; otherwise use fallback.
      final categoriesForSubtask = ancestorDialog?.categories ?? ['default'];

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          print("Building task detail dialog for subtask...");
          return TaskDetailDialog(
            task: widget.parentTask.subtasks[subtaskIndex],
            apiService: widget.apiService,
            categories: categoriesForSubtask,
            onTaskPossiblyUpdated: (updatedSubtask) {
              print("Subtask updated: ${updatedSubtask.content}");
              if (mounted) {
                setState(() {
                  final currentSubtaskIndex = widget.parentTask.subtasks
                      .indexWhere((t) => t.id == updatedSubtask.id);
                  if (currentSubtaskIndex != -1) {
                    widget.parentTask.subtasks[currentSubtaskIndex] =
                        Task.copyWith(updatedSubtask);
                  }
                });
                // Bubble the update to the parent TaskDetailDialog:
                widget.onTaskUpdated(widget.parentTask);
              }
            },
          );
        },
      );
    } catch (e) {
      print("Error opening subtask detail dialog: $e");
      _showError("Error opening subtask details.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Task> currentSubtasks =
        widget.parentTask.subtasks; // Use parent's list

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min, // Important for Column inside scrollable areas
      children: [
        // Subtask input
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Add a subtask...',
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isLoadingAdd
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_circle_outline),
                iconSize: 24,
                onPressed: _isLoadingAdd ? null : _addSubtask,
                color: theme.colorScheme.primary,
                tooltip: 'Add Subtask',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Subtasks list (or empty message)
        if (currentSubtasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
                child: Text('No subtasks yet.',
                    style: TextStyle(color: theme.hintColor, fontSize: 13))),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: currentSubtasks.map((subtask) {
              final textStyleCompleted = TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.disabledColor,
                  fontSize: 14);
              final textStyleNormal = const TextStyle(fontSize: 14);
              final int nestedTotal = subtask.totalSubtasks;
              final int nestedCompleted = subtask.completedSubtasks;

              return ListTile(
                dense: true,
                // Removed negative vertical padding to avoid layout issues
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                visualDensity: VisualDensity.compact,
                leading: Checkbox(
                  value: subtask.completed,
                  onChanged: (_) => _toggleSubtaskCompletion(subtask),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                title: Text(
                  subtask.content,
                  style:
                      subtask.completed ? textStyleCompleted : textStyleNormal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: subtask.hasSubtasks
                    ? Text(
                        '$nestedCompleted/$nestedTotal nested',
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      )
                    : null,
                onTap: () {
                  // Open nested dialog for subtask details
                  _openSubtaskDetailDialog(subtask);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteSubtask(subtask),
                  color: theme.colorScheme.error.withAlpha((255 * 0.8).round()),
                  tooltip: 'Delete Subtask',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
