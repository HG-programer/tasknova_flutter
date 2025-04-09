// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'task.dart'; // Ensure this imports your updated Task model

class ApiService {
  // Ensure this URL points to your *deployed* backend
  // Using HTTPS is highly recommended.
  // If testing locally with Flask running: http://10.0.2.2:5000 (Android emulator)
  // or http://127.0.0.1:5000 (iOS simulator/Desktop) - CHANGE IF NEEDED
  static const String _baseUrl = 'https://todo-app-ai.onrender.com';

  /// Fetches all top-level tasks (no parentId) or tasks for a specific category.
  /// Modify backend endpoint if needed for filtering.
  Future<List<Task>> fetchTasks({String? category}) async {
    // TODO: Update endpoint if backend supports category filtering like /tasks?category=...
    String url = '$_baseUrl/tasks';
    print("Fetching tasks from: $url"); // Debug log
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      // Ensure backend returns subtasks nested or handle separately
      List<Task> tasks =
          body.map((dynamic item) => Task.fromJson(item)).toList();
      print("Fetched ${tasks.length} tasks"); // Debug log
      return tasks;
    } else {
      print(
          "Failed to load tasks. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception('Failed to load tasks (Status ${response.statusCode})');
    }
  }

  /// Fetches the list of available categories from the backend.
  Future<List<String>> fetchCategories() async {
    String url = '$_baseUrl/categories'; // Assumes backend has this endpoint
    print("Fetching categories from: $url"); // Debug log
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<String> categories = body
          .map((dynamic item) => item.toString())
          .toList(); // Safely convert to String
      print("Fetched categories: $categories"); // Debug log
      return categories;
    } else {
      print(
          "Failed to load categories. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed to load categories (Status ${response.statusCode})');
    }
  }

  /// Adds a new task (potentially as a subtask) with category.
  /// Backend '/add' endpoint needs to handle 'content', 'category', 'parent_id'.
  Future<Task> addTask(String taskContent,
      {String category = 'default', int? parentId}) async {
    String url = '$_baseUrl/add';
    print(
        "Adding task: '$taskContent', Category: '$category', ParentID: $parentId to $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'content': taskContent,
        'category': category,
        'parent_id': parentId, // Send null if it's a root task
      }),
    );

    if (response.statusCode == 201) {
      // Expecting 201 Created
      // Ensure backend returns the created task including its ID and potentially nested subtasks
      final responseData = jsonDecode(response.body);
      // Adjust based on actual backend response structure
      final taskData = responseData.containsKey('task')
          ? responseData['task']
          : responseData;
      print("Task added successfully: ${jsonEncode(taskData)}"); // Debug log
      return Task.fromJson(taskData);
    } else {
      print(
          "Failed to add task. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception('Failed to add task (Status ${response.statusCode})');
    }
  }

  /// Helper specifically for adding a subtask (calls the main addTask).
  Future<Task> addSubtask(int parentId, String content) async {
    print("Adding subtask '$content' to parent $parentId"); // Debug log
    // Uses the main addTask method, providing the parentId.
    // Assumes subtasks inherit category from parent unless specified otherwise by backend.
    return addTask(content, parentId: parentId);
  }

  /// Toggles the completion status of a task.
  /// Matches the existing backend endpoint `/complete/<id>`.
  Future<bool> updateTaskCompletion(int taskId, bool newCompletedStatus) async {
    // NOTE: The backend currently *toggles* status on POST /complete/<id>.
    // It doesn't actually use the 'newCompletedStatus' sent from here.
    // If the backend changes to *set* the status, this body would need updating.
    String url = '$_baseUrl/complete/$taskId';
    print("Toggling completion for task $taskId at $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      // body: jsonEncode({'completed': newCompletedStatus}), // Backend might ignore this body currently
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final confirmedStatus = data['completed_status'] as bool;
      print(
          "Task $taskId completion toggled. New status from backend: $confirmedStatus"); // Debug log
      return confirmedStatus; // Return the actual status confirmed by backend
    } else {
      print(
          "Failed to update task completion for $taskId. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed to update task completion (Status ${response.statusCode})');
    }
  }

  /// Updates the content (description) of a task.
  /// Assumes backend endpoint `/update-content/<id>`.
  Future<bool> updateTaskContent(int taskId, String newContent) async {
    String url = '$_baseUrl/update-content/$taskId';
    print(
        "Updating content for task $taskId to '$newContent' at $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'content': newContent}),
    );

    if (response.statusCode == 200) {
      print("Task $taskId content updated successfully."); // Debug log
      return true; // Or return Task.fromJson if backend sends updated task
    } else {
      print(
          "Failed to update task content for $taskId. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed to update task content (Status ${response.statusCode})');
    }
  }

  /// Updates the category of a task.
  /// Assumes backend endpoint `/update-category/<id>`.
  Future<bool> updateTaskCategory(int taskId, String newCategory) async {
    String url = '$_baseUrl/update-category/$taskId';
    print(
        "Updating category for task $taskId to '$newCategory' at $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'category': newCategory}),
    );

    if (response.statusCode == 200) {
      print("Task $taskId category updated successfully."); // Debug log
      return true; // Or return Task.fromJson if backend sends updated task
    } else {
      print(
          "Failed to update task category for $taskId. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed to update task category (Status ${response.statusCode})');
    }
  }

  /// Deletes a task.
  /// Matches existing backend endpoint `/delete/<id>` (assuming POST or maybe DELETE method).
  /// KEEPING METHOD AS POST FOR NOW TO MATCH YOUR FLASK APP
  Future<void> deleteTask(int taskId) async {
    String url = '$_baseUrl/delete/$taskId';
    print("Deleting task $taskId at $url"); // Debug log
    // TODO: Change to http.delete if your backend route uses the DELETE method
    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200 || response.statusCode == 204) {
      // 204 No Content is also success for delete
      print("Task $taskId deleted from backend."); // Debug log
    } else {
      print(
          "Failed to delete task $taskId. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception('Failed to delete task (Status ${response.statusCode})');
    }
  }

  /// Fetches subtasks for a specific parent task ID.
  /// Assumes backend endpoint `/subtasks/<parentId>`.
  Future<List<Task>> fetchSubtasks(int parentId) async {
    String url = '$_baseUrl/subtasks/$parentId';
    print("Fetching subtasks for parent $parentId from $url"); // Debug log
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Task> subtasks =
          body.map((dynamic item) => Task.fromJson(item)).toList();
      print(
          "Fetched ${subtasks.length} subtasks for parent $parentId"); // Debug log
      return subtasks;
    } else {
      print(
          "Failed to load subtasks for parent $parentId. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed to load subtasks (Status ${response.statusCode})');
    }
  }

  /// Calls the Ask AI backend endpoint.
  Future<String> askAI(String taskText) async {
    String url = '$_baseUrl/ask-ai';
    print("Asking AI about '$taskText' at $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'task_text': taskText}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('details')) {
        print("AI call successful."); // Debug log
        return data['details'];
      } else {
        final error = data.containsKey('error')
            ? data['error']
            : 'Unknown AI response format';
        print("AI call returned error in JSON: $error"); // Debug log
        throw Exception(error);
      }
    } else {
      print(
          "AI call failed. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception('Failed AI API call (Status ${response.statusCode})');
    }
  }

  /// Calls the Motivate Me backend endpoint.
  Future<String> getMotivation() async {
    String url = '$_baseUrl/motivate-me';
    print("Getting motivation from $url"); // Debug log
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      // No body needed
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('motivation')) {
        print("Motivation call successful."); // Debug log
        return data['motivation'];
      } else {
        final error = data.containsKey('error')
            ? data['error']
            : 'Unknown motivation response format';
        print("Motivation call returned error in JSON: $error"); // Debug log
        throw Exception(error);
      }
    } else {
      print(
          "Motivation call failed. Status: ${response.statusCode}, Body: ${response.body}"); // Debug log
      throw Exception(
          'Failed motivation API call (Status ${response.statusCode})');
    }
  }
}
