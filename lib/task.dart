// task.dart
class Task {
  final int id;
  String content;
  bool completed;
  final DateTime createdAt;
  final int? parentId; // New field for parent task ID (null for root tasks)
  String category; // New field for task category
  List<Task> subtasks; // New field for subtasks

  Task({
    required this.id,
    required this.content,
    required this.completed,
    required this.createdAt,
    this.parentId,
    this.category = 'default', // Default category
    List<Task>? subtasks,
  }) : subtasks = subtasks ?? [];

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      content: json['content'] as String,
      completed: json['completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentId: json['parent_id'] as int?,
      category: json['category'] as String? ?? 'default',
      subtasks: json['subtasks'] != null
          ? (json['subtasks'] as List)
              .map((item) => Task.fromJson(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
      'parent_id': parentId,
      'category': category,
      'subtasks': subtasks.map((task) => task.toJson()).toList(),
    };
  }

  // Helper to check if this task has subtasks
  bool get hasSubtasks => subtasks.isNotEmpty;

  // Helper to check if all subtasks are completed
  bool get areAllSubtasksCompleted =>
      subtasks.isNotEmpty && subtasks.every((task) => task.completed);

  // Helper to count total subtasks (including nested)
  int get totalSubtasks {
    int count = subtasks.length;
    for (var subtask in subtasks) {
      count += subtask.totalSubtasks;
    }
    return count;
  }

  // Helper to count completed subtasks (including nested)
  int get completedSubtasks {
    int count = subtasks.where((task) => task.completed).length;
    for (var subtask in subtasks) {
      count += subtask.completedSubtasks;
    }
    return count;
  }
}
