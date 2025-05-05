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
      // Use debugPrint for warnings that don't need to crash the app
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
      return 'none'; // Use 'none' string, likely for backend compatibility
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
    this.completed = false, // Default completed to false
    required this.createdAt,
    this.parentId,
    this.category = 'default', // Default category
    List<Task>? subtasks, // Allow providing initial subtasks
    this.recurrenceType = RecurrenceType.none, // Default recurrence
    this.startDate, // Start date is optional
  }) : subtasks = subtasks ??
            []; // Ensure subtasks is always initialized (empty list if null)

  // Factory constructor for creating Task from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    // Robust parsing with null checks and default values

    // Parse recurrence fields
    final RecurrenceType recType =
        recurrenceTypeFromString(json['recurrence_type'] as String?);
    DateTime? startDt;
    final startDateString = json['start_date'] as String?;
    if (startDateString != null && startDateString.isNotEmpty) {
      try {
        startDt = DateTime.parse(startDateString); // More standard parsing
      } catch (e) {
        debugPrint("Error parsing 'start_date' string '$startDateString': $e");
        startDt = null; // Default to null if parsing fails
      }
    } else {
      startDt = null;
    }

    // Optional: Debug print to trace parsing (useful during development)
    // debugPrint(
    //     "Parsing Task ID ${json['id']}: Raw recType='${json['recurrence_type']}', Parsed Enum=${recType}");

    return Task(
      // Use null-aware operators and provide sensible defaults
      id: json['id'] as int? ??
          0, // Use 0 or throw error if ID is critical and missing
      content: json['content'] as String? ?? '', // Default to empty string
      completed: (json['completed'] as bool?) ?? false, // Default to false
      // Attempt to parse createdAt, default to current time if missing/invalid
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      parentId: json['parent_id'] as int?, // parentId can naturally be null
      category: json['category'] as String? ?? 'default', // Default category

      // Assign parsed recurrence values
      recurrenceType: recType,
      startDate: startDt,

      // Parse subtasks recursively and safely
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((item) {
                try {
                  // Ensure the item is a map before attempting Task.fromJson
                  if (item is Map<String, dynamic>) {
                    return Task.fromJson(item);
                  } else {
                    debugPrint("Skipping non-map item in subtasks list: $item");
                    return null; // Skip items that aren't maps
                  }
                } catch (e) {
                  // Catch errors during individual subtask parsing
                  debugPrint("Error parsing subtask item: $item, error: $e");
                  return null; // Return null for subtasks that fail to parse
                }
              })
              .whereType<
                  Task>() // Filter out any nulls resulting from errors or skips
              .toList() ?? // Convert iterable to list
          [], // Default to empty list if 'subtasks' field is null or absent
    );
  }

  // Method to convert Task object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'completed': completed,
      'created_at': createdAt.toIso8601String(), // Standard ISO 8601 format
      'parent_id': parentId, // Will include null if parentId is null
      'category': category,
      'subtasks': subtasks
          .map((task) => task.toJson())
          .toList(), // Convert subtasks recursively

      // Convert recurrence fields for JSON output
      'recurrence_type':
          recurrenceTypeToString(recurrenceType), // Use helper function
      // Include start_date only if it's not null, using ISO format
      'start_date': startDate?.toIso8601String(),
    };
  }

  // Getter to check if the task has any subtasks
  bool get hasSubtasks => subtasks.isNotEmpty;

  // Recursive calculation for the total number of subtasks (including nested ones)
  int get totalSubtasks {
    // Fold aggregates values: start with direct subtask count, then add nested counts
    return subtasks.fold<int>(
        subtasks.length, // Initial value: count of direct subtasks
        (sum, subtask) =>
            sum +
            subtask.totalSubtasks // Add count from each subtask recursively
        );
  }

  // Recursive calculation for the number of completed subtasks (including nested ones)
  int get completedSubtasks {
    // Count direct completed subtasks first
    int directCompleted = subtasks.where((task) => task.completed).length;
    // Fold: start with direct completed count, then add nested completed counts
    return subtasks.fold<int>(
        directCompleted, // Initial value: count of direct completed subtasks
        (sum, subtask) =>
            sum +
            subtask
                .completedSubtasks // Add completed count from each subtask recursively
        );
  }

  // Getter to easily check if the task is set to recur
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  // *** THIS IS THE CORRECTED STATIC copyWith METHOD ***
  // Creates a deep copy of a Task instance.
  static Task copyWith(Task original) {
    return Task(
      // Copy all primitive/immutable fields directly
      id: original.id,
      content: original.content, // **** Crucially copies content ****
      completed: original.completed,
      createdAt: original.createdAt, // DateTime is immutable
      parentId: original.parentId,
      category: original.category, // **** Crucially copies category ****
      recurrenceType: original.recurrenceType, // Enum value is copied
      startDate: original.startDate, // DateTime is immutable

      // Perform a deep copy of the mutable list of subtasks
      subtasks: original.subtasks.map((sub) => Task.copyWith(sub)).toList(),
    );
  }

  // Override equality operator (==) for comparing Task instances
  @override
  bool operator ==(Object other) {
    // Check for identity (same object instance) first for performance
    if (identical(this, other)) return true;

    // Check runtime type and ensure other is a Task
    return other is Task &&
        runtimeType == other.runtimeType &&
        // Compare all relevant fields for equality
        id == other.id &&
        content == other.content &&
        completed == other.completed &&
        parentId == other.parentId && // Handles null comparison correctly
        category == other.category &&
        recurrenceType == other.recurrenceType &&
        startDate ==
            other.startDate && // Direct comparison for DateTime? (usually fine)
        // Use listEquals from foundation.dart for deep comparison of subtask lists
        listEquals(subtasks, other.subtasks);
  }

  // Override hashCode to be consistent with the equality operator
  @override
  int get hashCode {
    // Combine hash codes of all fields included in the equality check
    // Using XOR (^) is a common pattern
    return id.hashCode ^
        content.hashCode ^
        completed.hashCode ^
        parentId.hashCode ^ // Handles null correctly
        category.hashCode ^
        recurrenceType.hashCode ^
        startDate.hashCode ^ // Handles null correctly
        // Use a consistent way to hash the list (hashCode getter for List is sufficient here
        // as listEquals uses element-wise comparison)
        subtasks.hashCode;
  }
} // End of Task class
