// lib/task.dart
import 'package:flutter/foundation.dart'; // For listEquals and debugPrint

// *** ADDED Enum for Recurrence Types ***
enum RecurrenceType { none, daily, weekly, monthly, yearly }

// *** ADDED Helper function to safely get RecurrenceType from string ***
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
      debugPrint("Unknown recurrence type string: $typeString");
      return RecurrenceType.none;
  }
}

// *** ADDED Helper function to convert RecurrenceType to string for JSON/API ***
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
      return 'none'; // Use 'none' string for backend compatibility
  }
}

class Task {
  final int id;
  String content;
  bool completed;
  final DateTime createdAt;
  final int? parentId;
  String category;
  List<Task> subtasks; // This is mutable, which is key for dialog interactions

  // --- NEW RECURRENCE FIELDS ---
  RecurrenceType recurrenceType; // Non-nullable, defaults to none
  DateTime? startDate; // Nullable start date for recurrence

  Task({
    required this.id,
    required this.content,
    required this.completed,
    required this.createdAt,
    this.parentId,
    this.category = 'default',
    List<Task>? subtasks,
    // --- ADDED: Recurrence params to constructor ---
    this.recurrenceType = RecurrenceType.none, // Default to none
    this.startDate, // Allow null
  }) : subtasks = subtasks ?? []; // Initialize subtasks

  factory Task.fromJson(Map<String, dynamic> json) {
    // Robust parsing with null checks and default values

    // --- ADDED: Parsing for recurrence fields ---
    final RecurrenceType recType =
        recurrenceTypeFromString(json['recurrence_type'] as String?);
    DateTime? startDt;
    final startDateString = json['start_date'] as String?;
    if (startDateString != null) {
      try {
        startDt = DateTime.parse(startDateString); // Use parse, more robust
      } catch (e) {
        debugPrint("Error parsing start_date '$startDateString': $e");
        startDt = null; // Default to null if parsing fails
      }
    } else {
      startDt = null;
    }
    // --- End of recurrence parsing ---

    debugPrint(
        "Parsing Task ${json['id']}: recType='${json['recurrence_type']}', recEnum=${recurrenceTypeFromString(json['recurrence_type'] as String?)}");

    return Task(
      id: json['id'] as int? ??
          0, // Provide default ID if null (though unlikely)
      content: json['content'] as String? ?? '',
      completed: (json['completed'] ?? false) as bool,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(), // Use current time as fallback
      parentId: json['parent_id'] as int?, // parentId can be null
      category: json['category'] as String? ?? 'default',

      // --- ADDED: Assign parsed recurrence values ---
      recurrenceType: recType,
      startDate: startDt,
      // --- End of assignment ---

      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((item) {
                try {
                  if (item is Map<String, dynamic>) {
                    return Task.fromJson(item);
                  }
                } catch (e) {
                  debugPrint("Error parsing subtask item: $item, error: $e");
                }
                return null;
              })
              .whereType<Task>()
              .toList() ??
          [], // Default to empty list if subtasks are null or empty
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'completed': completed,
      'created_at': createdAt.toIso8601String(), // Standard format
      'parent_id': parentId, // Will be null if not set
      'category': category,
      'subtasks': subtasks.map((task) => task.toJson()).toList(),

      // --- ADDED: Recurrence fields to JSON output ---
      'recurrence_type':
          recurrenceTypeToString(recurrenceType), // Convert enum to string
      'start_date': startDate?.toIso8601String(), // Send ISO string or null
      // --- End of JSON additions ---
    };
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  // Recursive calculation for total subtasks
  int get totalSubtasks {
    return subtasks.fold<int>(
        subtasks.length, // Start with direct children count
        (sum, subtask) => sum + subtask.totalSubtasks // Add nested counts
        );
  }

  // Recursive calculation for completed subtasks
  int get completedSubtasks {
    int directCompleted = subtasks.where((task) => task.completed).length;
    return subtasks.fold<int>(
        directCompleted, // Start with direct completed count
        (sum, subtask) =>
            sum + subtask.completedSubtasks // Add nested completed counts
        );
  }

  // --- ADDED: Getter to check if the task is recurring ---
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  // --- UPDATED: copyWith method to include recurrence fields ---
  static Task copyWith(Task original) {
    return Task(
      id: original.id,
      content: original.content,
      completed: original.completed,
      createdAt: original.createdAt, // DateTime is immutable
      parentId: original.parentId,
      category: original.category,
      subtasks: original.subtasks
          .map((sub) => Task.copyWith(sub))
          .toList(), // Deep copy subtasks

      // --- ADDED: Copy recurrence fields ---
      recurrenceType: original.recurrenceType,
      startDate: original.startDate, // DateTime is immutable, direct copy ok
      // --- End copy recurrence ---
    );
  }

  // --- UPDATED: Equality operator to include recurrence ---
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          content == other.content &&
          completed == other.completed &&
          parentId == other.parentId &&
          category == other.category &&
          // --- ADDED: Compare recurrence fields ---
          recurrenceType == other.recurrenceType &&
          startDate ==
              other
                  .startDate && // Direct comparison ok for DateTime? or use compareTo? Let's keep direct for now.
          // --- End compare recurrence ---
          listEquals(subtasks, other.subtasks); // Use listEquals for subtasks

  // --- UPDATED: hashCode to include recurrence ---
  @override
  int get hashCode =>
      id.hashCode ^
      content.hashCode ^
      completed.hashCode ^
      parentId.hashCode ^
      category.hashCode ^
      // --- ADDED: Hash recurrence fields ---
      recurrenceType.hashCode ^
      startDate.hashCode ^ // Hash nullable field
      // --- End hash recurrence ---
      subtasks.hashCode; // List hashCode might not be deep by default
} // End of Task class
