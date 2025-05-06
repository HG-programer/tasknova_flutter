// lib/task.dart
import 'package:flutter/foundation.dart'; // For listEquals and debugPrint

// Enum for Recurrence Types
enum RecurrenceType { none, daily, weekly, monthly, yearly }

// Helper function to safely get RecurrenceType from string
RecurrenceType recurrenceTypeFromString(String? typeString) {
  if (typeString == null) return RecurrenceType.none;
  switch (typeString.toLowerCase()) {
    case 'daily':
      return RecurrenceType.daily;
    case 'weekly':
      return RecurrenceType.weekly;
    case 'monthly':
      return RecurrenceType.monthly;
    case 'yearly':
      return RecurrenceType.yearly;
    default:
      debugPrint(
          "Unknown recurrence type string encountered: '$typeString'. Defaulting to none.");
      return RecurrenceType.none;
  }
}

// Helper function to convert RecurrenceType to string for JSON/API
String recurrenceTypeToString(RecurrenceType type) {
  switch (type) {
    case RecurrenceType.daily:
      return 'daily';
    case RecurrenceType.weekly:
      return 'weekly';
    case RecurrenceType.monthly:
      return 'monthly';
    case RecurrenceType.yearly:
      return 'yearly';
    case RecurrenceType.none:
    default:
      return 'none';
  }
}

class Task {
  final int id;
  String content; // Mutable to allow direct editing
  bool completed; // Mutable
  final DateTime createdAt; // Usually immutable after creation
  final int? parentId;
  String category; // Mutable
  List<Task> subtasks; // Mutable list, allows adding/removing/updating subtasks

  // Recurrence fields
  RecurrenceType recurrenceType; // Mutable
  DateTime? startDate; // Mutable start date for recurrence

  // Constructor with defaults
  Task({
    required this.id,
    required this.content,
    this.completed = false,
    required this.createdAt,
    this.parentId,
    this.category = 'default',
    List<Task>? subtasks,
    this.recurrenceType = RecurrenceType.none,
    this.startDate,
  }) : subtasks = subtasks ?? [];

  // Factory constructor for creating Task from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    final RecurrenceType recType =
        recurrenceTypeFromString(json['recurrence_type'] as String?);
    DateTime? startDt;
    final startDateString = json['start_date'] as String?;
    if (startDateString != null && startDateString.isNotEmpty) {
      try {
        startDt = DateTime.parse(startDateString);
      } catch (e) {
        debugPrint("Error parsing 'start_date' string '$startDateString': $e");
        startDt = null;
      }
    }

    return Task(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      parentId: json['parent_id'] as int?,
      category: json['category'] as String? ?? 'default',
      recurrenceType: recType,
      startDate: startDt,
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((item) {
                try {
                  if (item is Map<String, dynamic>) {
                    return Task.fromJson(item);
                  } else {
                    debugPrint("Skipping non-map item in subtasks list: $item");
                    return null;
                  }
                } catch (e) {
                  debugPrint("Error parsing subtask item: $item, error: $e");
                  return null;
                }
              })
              .whereType<Task>()
              .toList() ??
          [],
    );
  }

  // Method to convert Task object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
      'parent_id': parentId,
      'category': category,
      'subtasks': subtasks.map((task) => task.toJson()).toList(),
      'recurrence_type': recurrenceTypeToString(recurrenceType),
      'start_date': startDate?.toIso8601String(),
    };
  }

  // Getter to check if the task has any subtasks
  bool get hasSubtasks => subtasks.isNotEmpty;

  // Recursive calculation for the total number of subtasks (including nested ones)
  int get totalSubtasks => subtasks.fold(
      subtasks.length, (sum, subtask) => sum + subtask.totalSubtasks);

  // Recursive calculation for the number of completed subtasks (including nested ones)
  int get completedSubtasks => subtasks.fold(
      subtasks.where((task) => task.completed).length,
      (sum, subtask) => sum + subtask.completedSubtasks);

  // Getter to easily check if the task is set to recur
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  // Creates a deep copy of a Task instance
  static Task copyWith(
    Task original, {
    String? content,
    bool? completed,
    String? category,
    RecurrenceType? recurrenceType,
    DateTime? startDate,
    List<Task>? subtasks,
  }) {
    return Task(
      id: original.id,
      content: content ?? original.content,
      completed: completed ?? original.completed,
      createdAt: original.createdAt,
      parentId: original.parentId,
      category: category ?? original.category,
      recurrenceType: recurrenceType ?? original.recurrenceType,
      startDate: startDate ?? original.startDate,
      subtasks: subtasks ??
          original.subtasks.map((sub) => Task.copyWith(sub)).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task &&
        id == other.id &&
        content == other.content &&
        completed == other.completed &&
        parentId == other.parentId &&
        category == other.category &&
        recurrenceType == other.recurrenceType &&
        startDate == other.startDate &&
        listEquals(subtasks, other.subtasks);
  }

  @override
  int get hashCode => Object.hash(
        id,
        content,
        completed,
        parentId,
        category,
        recurrenceType,
        startDate,
        subtasks,
      );
}
