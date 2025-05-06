import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'task.dart'; // Import Task model (ensure it includes RecurrenceType enum and fields)

class ApiService {
  static const String _baseUrl = 'https://todo-app-ai.onrender.com';
  static const Duration _timeoutDuration = Duration(seconds: 20);

  // Handles API responses and errors
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;

      try {
        return jsonDecode(response.body);
      } catch (e) {
        debugPrint("JSON Decode Error: ${e.toString()}");
        debugPrint("Response Body: ${response.body}");
        throw Exception('Failed to decode server response.');
      }
    } else {
      String errorMessage = 'API Request Failed (Status $statusCode)';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody.containsKey('error')) {
            errorMessage = errorBody['error'].toString();
          } else if (errorBody.containsKey('message')) {
            errorMessage = errorBody['message'].toString();
          } else if (response.body.isNotEmpty) {
            errorMessage += ': ${response.body}';
          }
        } else if (response.body.isNotEmpty) {
          errorMessage += ': ${response.body}';
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          errorMessage += ': ${response.body}';
        }
      }
      debugPrint(errorMessage);
      throw Exception(errorMessage);
    }
  }

  // Fetches all tasks, optionally filtered by category
  Future<List<Task>> fetchTasks({String? category}) async {
    String url = '$_baseUrl/tasks';
    if (category != null && category != 'default') {
      url += '?category=${Uri.encodeComponent(category)}';
    }
    debugPrint("Fetching tasks from: $url");
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      return body
          .map((dynamic item) => Task.fromJson(item as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      debugPrint("Fetch tasks timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch tasks error: $e");
      rethrow;
    }
  }

  // Fetches all available categories
  Future<List<String>> fetchCategories() async {
    String url = '$_baseUrl/categories';
    debugPrint("Fetching categories from: $url");
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      return body.map((dynamic item) => item.toString()).toSet().toList();
    } on TimeoutException {
      debugPrint("Fetch categories timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch categories error: $e");
      rethrow;
    }
  }

  // Adds a new task with optional recurrence and category
  Future<Task> addTask(String taskContent,
      {String category = 'default',
      int? parentId,
      RecurrenceType recurrenceType = RecurrenceType.none,
      DateTime? startDate}) async {
    String url = '$_baseUrl/add';
    debugPrint(
        "Adding task: '$taskContent', category: $category, parent: $parentId, recurrence: ${recurrenceTypeToString(recurrenceType)}, start: $startDate");
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'content': taskContent,
              'category': category,
              'parent_id': parentId,
              'recurrence_type': recurrenceTypeToString(recurrenceType),
              'start_date': startDate?.toIso8601String(),
            }),
          )
          .timeout(_timeoutDuration);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = _handleResponse(response);
        final taskData =
            (responseData is Map && responseData.containsKey('task'))
                ? responseData['task']
                : responseData;
        return Task.fromJson(taskData as Map<String, dynamic>);
      } else {
        _handleResponse(response);
        throw Exception('Failed to add task (Status ${response.statusCode})');
      }
    } on TimeoutException {
      debugPrint("Add task timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Add task error: $e");
      rethrow;
    }
  }

  // Adds a subtask to an existing parent task
  Future<Task> addSubtask(int parentId, String content,
      {RecurrenceType recurrenceType = RecurrenceType.none,
      DateTime? startDate}) async {
    debugPrint("Adding subtask under parent $parentId");
    return addTask(content,
        parentId: parentId,
        recurrenceType: recurrenceType,
        startDate: startDate);
  }

  // Updates the completion status of a task
  Future<bool> updateTaskCompletion(int taskId, bool newCompletedStatus) async {
    String url = '$_baseUrl/complete/$taskId';
    debugPrint("Updating completion for task $taskId to $newCompletedStatus");
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(_timeoutDuration);
      final data = _handleResponse(response);
      if (data is Map && data.containsKey('completed_status')) {
        return data['completed_status'] as bool;
      } else {
        throw Exception('Invalid response format for completion update.');
      }
    } on TimeoutException {
      debugPrint("Update completion timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Update completion error: $e");
      rethrow;
    }
  }

  // Updates the category of a task
  // Updates the content of a task
  // Updates the category of a task
// Updates the category of a task
  Future<bool> updateTaskContent(int taskId, String newContent) async {
    String url = '$_baseUrl/update-content/$taskId';
    debugPrint("Updating content for task $taskId to '$newContent'");
    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({'content': newContent}))
          .timeout(_timeoutDuration);
      _handleResponse(response); // Throws on non-2xx status
      debugPrint("Task $taskId content updated successfully.");
      return true; // Assume success if no exception
    } on TimeoutException {
      debugPrint("Update content timed out for task $taskId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Update content error for task $taskId: $e");
      rethrow;
    }
  }

  // Updates the category of a task
  Future<bool> updateTaskCategory(int taskId, String newCategory) async {
    String url = '$_baseUrl/update-category/$taskId';
    debugPrint("Updating category for task $taskId to '$newCategory'");
    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({'category': newCategory}))
          .timeout(_timeoutDuration);
      _handleResponse(response); // Throws on non-2xx status
      debugPrint("Task $taskId category updated successfully.");
      return true; // Assume success if no exception
    } on TimeoutException {
      debugPrint("Update category timed out for task $taskId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Update category error for task $taskId: $e");
      rethrow;
    }
  }

  // Interacts with AI to get task-related suggestions
  Future<String> askAI(String taskText) async {
    String url = '$_baseUrl/ask-ai';
    debugPrint("Asking AI about task: '$taskText'");
    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({'task_text': taskText}))
          .timeout(_timeoutDuration);
      final data = _handleResponse(response);
      if (data is Map && data.containsKey('details')) {
        return data['details'] as String? ?? "No details provided.";
      } else {
        throw Exception('Invalid response format from AI.');
      }
    } on TimeoutException {
      debugPrint("Ask AI timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Ask AI error: $e");
      rethrow;
    }
  }

  // Fetches motivational quotes
  Future<String> getMotivation() async {
    String url = '$_baseUrl/motivate-me';
    debugPrint("Requesting motivation.");
    try {
      final response = await http.post(Uri.parse(url), headers: {
        'Content-Type': 'application/json; charset=UTF-8'
      }).timeout(_timeoutDuration);
      final data = _handleResponse(response);
      if (data is Map && data.containsKey('motivation')) {
        return data['motivation'] as String? ?? "Keep up the great work!";
      } else {
        throw Exception('Invalid response format for motivation.');
      }
    } on TimeoutException {
      debugPrint("Get motivation timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Get motivation error: $e");
      rethrow;
    }
  }

  // Deletes a task
  Future<void> deleteTask(int taskId) async {
    String url = '$_baseUrl/delete/$taskId';
    debugPrint("Deleting task $taskId");
    try {
      final response =
          await http.post(Uri.parse(url)).timeout(_timeoutDuration);
      _handleResponse(response);
    } on TimeoutException {
      debugPrint("Delete task timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Delete task error: $e");
      rethrow;
    }
  }

  // Fetches subtasks for a parent task
  Future<List<Task>> fetchSubtasks(int parentId) async {
    String url = '$_baseUrl/subtasks/$parentId';
    debugPrint("Fetching subtasks for parent $parentId");
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      return body
          .map((dynamic item) => Task.fromJson(item as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      debugPrint("Fetch subtasks timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch subtasks error: $e");
      rethrow;
    }
  }
}
