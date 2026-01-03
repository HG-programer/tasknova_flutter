// lib/constants.dart
import 'package:flutter/material.dart';

/// Durations used throughout the app for animations and UI timing
class AppDurations {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 400);
  
  // Dialog-specific durations
  static const Duration dialogAnimation = Duration(milliseconds: 300);
  
  // Private constructor to prevent instantiation
  AppDurations._();
}

/// Icon sizes used throughout the app
class AppIconSizes {
  static const double small = 18.0;
  static const double medium = 22.0;
  static const double large = 32.0;
  
  // Private constructor to prevent instantiation
  AppIconSizes._();
}

/// Padding values used throughout the app
class AppPadding {
  static const EdgeInsets inputRow = EdgeInsets.fromLTRB(16, 16, 16, 8);
  static const EdgeInsets listItem = EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0);
  static const EdgeInsets error = EdgeInsets.all(24);
  static const EdgeInsets emptyList = EdgeInsets.all(32.0);
  static const EdgeInsets dialogActions = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  
  // Private constructor to prevent instantiation
  AppPadding._();
}

/// Border radius values used throughout the app
class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  
  // Private constructor to prevent instantiation
  AppBorderRadius._();
}

/// API and networking constants
class ApiConstants {
  static const String baseUrl = 'https://todo-app-ai.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 20);
  static const String contentTypeJson = 'application/json; charset=UTF-8';
  
  // Status codes
  static const int successStartCode = 200;
  static const int successEndCode = 300;
  
  // Private constructor to prevent instantiation
  ApiConstants._();
}

/// Default values for the app
class AppDefaults {
  static const String defaultCategory = 'default';
  static const String defaultTaskContent = '';
  static const String defaultMotivation = 'Keep up the great work!';
  static const String defaultAiResponse = 'No details provided.';
  
  // Private constructor to prevent instantiation
  AppDefaults._();
}

/// String constants and error messages
class AppStrings {
  static const String appTitle = 'TaskNova';
  static const String noCategories = 'No categories';
  static const String requestTimeout = 'Request timed out. Please try again.';
  static const String jsonDecodeError = 'Failed to decode server response.';
  static const String invalidResponseFormat = 'Invalid response format from server.';
  static const String addTaskFailed = 'Failed to add task: ';
  static const String addSubtaskFailed = 'Failed to add subtask: ';
  static const String deleteTaskFailed = 'Failed to delete task: ';
  static const String updateTaskFailed = 'Failed to update task: ';
  static const String fetchTasksFailed = 'Failed to fetch tasks: ';
  static const String initAdmobError = 'Error initializing AdMob SDK: ';
  
  // Private constructor to prevent instantiation
  AppStrings._();
}
