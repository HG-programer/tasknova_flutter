// lib/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'task.dart'; // Import Task model (ensure it includes RecurrenceType enum and fields)

class ApiService {
  // Use the base URL you provided
  static const String _baseUrl = 'https://todo-app-ai.onrender.com';
  // static const String _baseUrl = 'http://10.0.2.2:5000'; // Keep your preferred one active
  static const Duration _timeoutDuration = Duration(seconds: 20);

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return null; // Handle empty successful responses
      }
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
        // Try to parse backend's specific error message
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody.containsKey('error')) {
            errorMessage = errorBody['error'].toString();
          } else if (errorBody.containsKey('message')) {
            errorMessage = errorBody['message'].toString();
          } else if (response.body.isNotEmpty) {
            errorMessage += ': ${response.body}'; // Fallback to raw body
          }
        } else if (response.body.isNotEmpty) {
          errorMessage += ': ${response.body}';
        }
      } catch (e) {
        // JSON decoding of error response failed, use raw body if available
        if (response.body.isNotEmpty) {
          errorMessage += ': ${response.body}';
        }
      }
      debugPrint(errorMessage); // Log the error before throwing
      throw Exception(errorMessage);
    }
  }

  Future<List<Task>> fetchTasks({String? category}) async {
    String url = '$_baseUrl/tasks';
    if (category != null && category != 'default') {
      url += '?category=${Uri.encodeComponent(category)}';
    }
    debugPrint("Fetching tasks from: $url"); // Log request
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      // Use Task.fromJson which should now handle recurrence fields
      List<Task> tasks = body
          .map((dynamic item) => Task.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint("Fetched ${tasks.length} tasks successfully.");
      return tasks;
    } on TimeoutException {
      debugPrint("Fetch tasks timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch tasks error: $e");
      rethrow; // Let UI handle the specific error
    }
  }

  Future<List<String>> fetchCategories() async {
    String url = '$_baseUrl/categories';
    debugPrint("Fetching categories from: $url");
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      // Ensure items are strings and get unique values
      List<String> categories =
          body.map((dynamic item) => item.toString()).toSet().toList();
      debugPrint("Fetched categories: $categories");
      return categories;
    } on TimeoutException {
      debugPrint("Fetch categories timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch categories error: $e");
      rethrow;
    }
  }

  // **** MODIFIED: addTask to include recurrence ****
  Future<Task> addTask(String taskContent,
      {String category = 'default',
      int? parentId,
      // <<< NEW optional recurrence parameters >>>
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
            // <<< SEND NEW FIELDS IN BODY >>>
            body: jsonEncode({
              'content': taskContent,
              'category': category,
              'parent_id': parentId,
              // Ensure strings match what backend expects (e.g., 'daily', 'weekly')
              'recurrence_type': recurrenceTypeToString(recurrenceType),
              // Send date as ISO 8601 string or null
              'start_date': startDate?.toIso8601String(),
            }),
          )
          .timeout(_timeoutDuration);

      // Expect the backend to return the created task data (including new fields)
      if (response.statusCode == 201 || response.statusCode == 200) {
        // 201 Created is typical REST
        final responseData = _handleResponse(response);
        // Backend might wrap the task in a 'task' key or return it directly
        final taskData =
            (responseData is Map && responseData.containsKey('task'))
                ? responseData['task']
                : responseData;
        if (taskData is Map<String, dynamic>) {
          debugPrint("Task added successfully, parsing response.");
          return Task.fromJson(
              taskData); // Task.fromJson handles the new fields
        } else {
          debugPrint("Add task Error: Invalid response format.");
          throw Exception('Invalid response format after adding task.');
        }
      } else {
        debugPrint(
            "Add task Error: Unexpected status code ${response.statusCode}.");
        // Let _handleResponse throw the appropriate error based on status/body
        _handleResponse(response);
        // This line likely won't be reached if _handleResponse throws, but added for clarity
        throw Exception('Failed to add task (Status ${response.statusCode})');
      }
    } on TimeoutException {
      debugPrint("Add task timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      // Don't just print here, rethrow so UI can catch it
      debugPrint("Add task error: $e");
      rethrow;
    }
  }

  // **** MODIFIED: addSubtask can now potentially forward recurrence ****
  // Note: You might decide subtasks don't need recurrence, but the capability is here.
  Future<Task> addSubtask(int parentId, String content,
      {RecurrenceType recurrenceType = RecurrenceType.none,
      DateTime? startDate}) async {
    debugPrint("Adding subtask under parent $parentId");
    // Simply call the main addTask, passing the recurrence info if provided
    return addTask(content,
        parentId: parentId,
        recurrenceType: recurrenceType,
        startDate: startDate);
  }

  Future<bool> updateTaskCompletion(int taskId, bool newCompletedStatus) async {
    String url = '$_baseUrl/complete/$taskId';
    debugPrint("Updating completion for task $taskId to $newCompletedStatus");
    try {
      final response = await http.post(
        Uri.parse(url),
        // Backend likely doesn't need body, just uses URL param and maybe auth
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(_timeoutDuration);
      final data = _handleResponse(response);
      // Ensure backend response matches expected structure
      if (data is Map && data.containsKey('completed_status')) {
        final status = data['completed_status'];
        if (status is bool) {
          debugPrint("Task $taskId completion updated to $status.");
          return status;
        } else {
          throw Exception('Invalid "completed_status" type in response.');
        }
      } else {
        throw Exception('Invalid response format after toggling completion.');
      }
    } on TimeoutException {
      debugPrint("Update completion timed out for task $taskId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Update completion error for task $taskId: $e");
      rethrow;
    }
  }

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

  // **** NEW: Method to Update Recurrence ****
  // Assumes backend has endpoint like POST /update-recurrence/:id
  Future<bool> updateTaskRecurrence(int taskId,
      RecurrenceType newRecurrenceType, DateTime? newStartDate) async {
    String url = '$_baseUrl/update-recurrence/$taskId';
    debugPrint(
        "Updating recurrence for task $taskId: type=${recurrenceTypeToString(newRecurrenceType)}, start=$newStartDate");
    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({
                'recurrence_type': recurrenceTypeToString(
                    newRecurrenceType), // Convert enum to string for backend
                'start_date':
                    newStartDate?.toIso8601String() // Send date string or null
              }))
          .timeout(_timeoutDuration);
      _handleResponse(response); // Checks for non-2xx status codes
      debugPrint("Task $taskId recurrence updated successfully.");
      return true; // Assume success if no exception is thrown
    } on TimeoutException {
      debugPrint("Update recurrence timed out for task $taskId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Update recurrence error for task $taskId: $e");
      rethrow; // Re-throw the exception to be caught by the UI layer
    }
  }

  Future<void> deleteTask(int taskId) async {
    String url = '$_baseUrl/delete/$taskId';
    debugPrint("Deleting task $taskId");
    try {
      final response = await http
          .post(
            Uri.parse(url),
            // Depending on backend, might just need POST or might need DELETE method
            // headers: {'Content-Type': 'application/json; charset=UTF-8'} // Often not needed for delete
          )
          .timeout(_timeoutDuration);
      _handleResponse(response); // Throws on non-2xx
      debugPrint("Task $taskId deleted successfully.");
    } on TimeoutException {
      debugPrint("Delete task timed out for task $taskId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Delete task error for task $taskId: $e");
      rethrow;
    }
  }

  Future<List<Task>> fetchSubtasks(int parentId) async {
    // Assumes backend provides this endpoint
    String url = '$_baseUrl/subtasks/$parentId';
    debugPrint("Fetching subtasks for parent $parentId from: $url");
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      final List<dynamic> body = _handleResponse(response);
      List<Task> subtasks = body
          .map((dynamic item) => Task.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint("Fetched ${subtasks.length} subtasks for parent $parentId.");
      return subtasks;
    } on TimeoutException {
      debugPrint("Fetch subtasks timed out for parent $parentId.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Fetch subtasks error for parent $parentId: $e");
      rethrow;
    }
  }

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
        final details = data['details'] as String? ?? "No details provided.";
        debugPrint("AI response received.");
        return details;
      } else {
        debugPrint("AI Error: Invalid response format.");
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

  Future<String> getMotivation() async {
    String url = '$_baseUrl/motivate-me';
    debugPrint("Requesting motivation.");
    try {
      final response = await http.post(Uri.parse(url), headers: {
        'Content-Type': 'application/json; charset=UTF-8'
      } // Backend might not need this header
          ).timeout(_timeoutDuration);
      final data = _handleResponse(response);
      if (data is Map && data.containsKey('motivation')) {
        final quote =
            data['motivation'] as String? ?? "Keep up the great work!";
        debugPrint("Motivation received.");
        return quote;
      } else {
        debugPrint("Motivation Error: Invalid response format.");
        throw Exception('Invalid response format from motivate-me.');
      }
    } on TimeoutException {
      debugPrint("Get motivation timed out.");
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      debugPrint("Get motivation error: $e");
      rethrow;
    }
  }
}
