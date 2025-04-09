import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // <-- Add Import
import 'api_service.dart'; // Import the API service
import 'task.dart'; // Import the Task model (using 'completed')
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'category_selector.dart';
import 'task_detail_dialog.dart';

// --- Import AdMob & Speech Packages ---
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

// --- Main with AdMob Init ---
Future<void> main() async {
  // MUST ensure bindings are ready before initializing plugins
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize AdMob SDK
    await MobileAds.instance.initialize();
    print("AdMob SDK Initialized Successfully");
  } catch (e) {
    print("Error initializing AdMob SDK: $e");
  }
  runApp(const MyApp()); // Run the Flutter App
}

// --- MyApp (Theme Management) ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false; // State for theme mode
  void _toggleTheme() {
    // No async needed
    setState(() {
      _isDarkMode = !_isDarkMode;
      HapticFeedback.mediumImpact(); // <-- ADD MEDIUM HAPTIC FEEDBACK HERE
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      title: 'TaskNova',
      theme: _buildTheme(Brightness.light), // Light theme
      darkTheme: _buildTheme(Brightness.dark), // Dark theme
      themeMode:
          _isDarkMode ? ThemeMode.dark : ThemeMode.light, // Control theme mode
      home: TaskNovaHomePage(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ), // Pass state & function
    );
  }

  // Helper function to build themes consistently
  ThemeData _buildTheme(Brightness brightness) {
    final Color surfaceColor =
        brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white;
    final Color onSurfaceColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;
    final Color primaryColor = brightness == Brightness.dark
        ? Colors.blueGrey[700]!
        : const Color(0xFF0d6efd);

    return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0d6efd), // Base seed color
          brightness: brightness,
          surface: surfaceColor,
          onSurface: onSurfaceColor,
          primary: primaryColor, // Explicitly set primary if needed elsewhere
          error: brightness == Brightness.dark
              ? Colors.redAccent[200]
              : Colors.red[700], // Define error color
          primaryContainer: brightness == Brightness.dark
              ? Colors.blueGrey[800]
              : Colors.blue[100], // For styled boxes
        ),
        useMaterial3: true, // Use Material 3 design features
        brightness: brightness,
        // Consistent AppBar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        // Optional default styling for widgets
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        // Define Icon Theme defaults if needed
        iconTheme: IconThemeData(
            color: brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54),
        // Consistent icon button style
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            // Keep primary color for key action buttons like Add/Mic if desired, but others might use default iconTheme
            // foregroundColor: primaryColor, // Removing this lets IconButton use IconTheme color by default
            padding: const EdgeInsets.all(8),
          ),
        ),
        // Dialog Theme (optional: sets defaults for AlertDialog)
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  16.0) // Default rounded shape for all dialogs
              ),
          titleTextStyle: TextStyle(
            // Default title style
            color: onSurfaceColor,
            fontSize:
                20.0, // or use Theme.of(context).textTheme.titleLarge?.fontSize
            fontWeight: FontWeight.w600,
          ),
        ),
        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor, // Use primary color for text buttons
          ),
        ));
  }
}

// --- TaskNovaHomePage StatefulWidget ---
class TaskNovaHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged; // Receive theme state and callback
  const TaskNovaHomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });
  @override
  State<TaskNovaHomePage> createState() => _TaskNovaHomePageState();
}

// --- State class for TaskNovaHomePage ---
class _TaskNovaHomePageState extends State<TaskNovaHomePage> {
  // State Variables
  List<String> _categories = ['default']; // Default category list
  String _selectedCategory = 'default'; // Currently selected filter category
  bool _loadingCategories = true; // Track category loading state
  List<Task> _tasks = []; // Holds the list of tasks
  bool _isLoading = true; // Track initial loading state
  String? _errorMessage; // Store potential error messages
  final TextEditingController _taskInputController =
      TextEditingController(); // For text input
  final ApiService _apiService = ApiService(); // Service for API calls

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // AdMob State
  BannerAd? _bannerAd; // The banner ad object
  bool _isBannerAdLoaded = false; // Track if the banner ad has loaded
  final String _bannerAdUnitId =
      "ca-app-pub-3940256099942544/6300978111"; // TEST BANNER ID

  // Speech Recognition State
  final SpeechToText _speechToText =
      SpeechToText(); // Speech recognizer instance
  bool _isSpeechEnabled = false; // Is speech available on device?
  bool _isListening = false; // Is the app currently listening?
  String _lastWords = ''; // Last recognized phrase buffer

  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _loadTasks(); // Fetch tasks when screen loads
    _loadBannerAd(); // Attempt to load the ad banner
    _initSpeech(); // Initialize speech recognition
    _loadCategories();
  }

  @override
  void dispose() {
    _taskInputController.dispose();
    _bannerAd?.dispose();
    _speechToText.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- AdMob Banner Loading ---
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(), // Standard ad request
      size: AdSize.banner, // Standard banner size
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
          print('$ad loaded.');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Banner Ad failed to load: $err');
          if (mounted) setState(() => _isBannerAdLoaded = false);
        },
      ),
    )..load();
    print("Attempting to load banner ad...");
  }

  // --- Load Tasks from API (with Pull-to-Refresh support) ---
  Future<void> _loadTasks() async {
    if (!mounted) return;
    final bool isRefreshing = !_isLoading;
    if (!isRefreshing) {
      setState(() => _isLoading = true);
    }
    setState(() => _errorMessage = null);

    try {
      final tasks = await _apiService.fetchTasks();
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            "Load tasks failed: ${e.toString().replaceFirst('Exception: ', '')}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Add Task via API (FOR ANIMATED LIST - FIXED with setState) ---
// Inside class _TaskNovaHomePageState { ... }

// === REPLACE OLD _addTask WITH THIS VERSION ===
  Future<void> _addTask({String? content, String? category}) async {
    final String taskContent = content ?? _taskInputController.text.trim();
    // Use the currently selected category if none is passed explicitly
    final String taskCategory = category ?? _selectedCategory;

    if (taskContent.isEmpty || !mounted) return;
    FocusScope.of(context).unfocus();
    print(
        "Attempting to add task: '$taskContent' in category: '$taskCategory'"); // Debug log

    try {
      // Pass category to the ApiService method
      final newTask = await _apiService.addTask(taskContent,
          category: taskCategory // Send category to API
          );
      print("API success. New Task ID: ${newTask.id}");

      if (mounted) {
        setState(() {
          final insertIndex = _tasks.length;
          print(
              "Updating UI: Inserting '${newTask.content}' at index $insertIndex");
          _tasks.insert(insertIndex, newTask);
          _listKey.currentState?.insertItem(insertIndex,
              duration: const Duration(milliseconds: 400));
        });

        if (content == null) {
          // Only clear text field if not added via speech
          _taskInputController.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task added!'), backgroundColor: Colors.green));
      } else {
        print("Widget unmounted after API call, task add aborted.");
      }
    } catch (e) {
      if (mounted) {
        print("Error adding task: $e");
        _showErrorSnackbar("Add failed", e);
      }
    }
  }
// ===========================================

  // --- Toggle Task Completion (uses 'completed') ---

// ... other code ...

// Inside class _TaskNovaHomePageState extends State<TaskNovaHomePage>

  Future<void> _toggleTaskCompletion(Task task) async {
    if (!mounted) return;
    final originalState = task.completed;

    // Optimistic UI update and haptic feedback
    setState(() {
      task.completed = !originalState; // Update the task's completed state
      HapticFeedback.lightImpact(); // <-- Trigger light vibration
    });

    // Attempt to sync with backend
    try {
      final confirmedState = await _apiService.updateTaskCompletion(
        task.id,
        !originalState, // Send the *new* intended state to the backend
      );
      // If backend confirmation differs from our optimistic update, revert UI
      if (mounted && confirmedState != task.completed) {
        // print("Backend confirmation mismatch! Reverting toggle.");
        setState(() {
          task.completed = confirmedState; // Use the state confirmed by backend
        });
      } else if (mounted) {
        // print("Task ${task.id} toggle synced with backend.");
      }
    } catch (e) {
      // If API call fails, roll back the optimistic UI update
      if (mounted) {
        setState(() {
          task.completed = originalState; // Revert to the original state
        });
        _showErrorSnackbar("Update failed", e);
      }
    }
  }

// ... rest of your _TaskNovaHomePageState class ...

  // --- Delete Task (FOR ANIMATED LIST, void return API) ---
// Inside class _TaskNovaHomePageState extends State<TaskNovaHomePage>

  Future<void> _deleteTask(int taskId, int index) async {
    // Basic checks
    if (!mounted || index < 0 || index >= _tasks.length) return;

    // Store the task data before removing it
    final taskToDelete = _tasks[index];

    // --- Initiate Removal Animation & Haptic Feedback ---
    _listKey.currentState?.removeItem(
        index,
        // Builder for the item during removal animation
        (context, animation) => _buildRemovedTaskItem(taskToDelete, animation),
        duration: const Duration(milliseconds: 300));
    HapticFeedback.lightImpact(); // <-- ADD HAPTIC FEEDBACK HERE

    // Optimistically remove the task data from the local list
    // Should happen AFTER starting the animation to allow _buildRemovedTaskItem to access data
    // Consider wrapping in setState if other parts of UI depend on _tasks.length immediately
    setState(() {
      _tasks.removeAt(index);
    });

    // Show confirmation SnackBar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Task "${taskToDelete.content}" deleted.'),
        backgroundColor: Colors.green));

    // Attempt to delete from backend
    try {
      await _apiService.deleteTask(taskId);
      // print("Task ${taskToDelete.id} deleted from backend.");
    } catch (e) {
      // print("Backend delete failed: $e");
      // Handle backend failure: Re-insert the item visually
      if (mounted) {
        // Calculate correct insertion index (in case other items were added/removed)
        final insertIndex = index < _tasks.length ? index : _tasks.length;
        // Put data back into the list
        setState(() {
          _tasks.insert(insertIndex, taskToDelete);
        });
        // Insert back into AnimatedList (may cause flicker)
        _listKey.currentState?.insertItem(insertIndex, duration: Duration.zero);

        _showErrorSnackbar("Delete failed on backend", e);

        // Reloading the whole list might be simpler but less ideal UX on error
        // _loadTasks();
      }
    }
  }

// ... rest of your _TaskNovaHomePageState class ...

  // === ADD THIS METHOD ===
  void _openTaskDetailDialog(Task task) {
    print("Opening detail dialog for task ID: ${task.id}"); // Debug print
    showAnimatedDialog(
      // Use the helper if you have it, otherwise showDialog
      context: context,
      builder: (dialogContext) => TaskDetailDialog(
        task: task, // Pass the specific task
        apiService: _apiService, // Pass the ApiService instance
        categories: _categories, // Pass the list of available categories
        onTaskUpdated: (updatedTask) {
          // This callback gets called from INSIDE the dialog
          // when a subtask/category/content is changed there.
          print(
              "Task updated callback received for task ID: ${updatedTask.id}");
          if (mounted) {
            // Just trigger a rebuild of the main list to reflect
            // any direct mutations made to the task object.
            setState(() {});
            // More sophisticated state management might replace
            // the item in the _tasks list instead.
          }
        },
      ),
    );
  }

  // =====================
  // --- Helper to Build Removed Task Item for AnimatedList ---
  Widget _buildRemovedTaskItem(Task task, Animation<double> animation) {
    final theme = Theme.of(context);
    final textStyleComplete = theme.textTheme.titleMedium?.copyWith(
      decoration: TextDecoration.lineThrough,
      color: theme.textTheme.titleMedium?.color?.withOpacity(0.6),
      decorationColor: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
      decorationThickness: 1.5,
    );

    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.5), // Faded background
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListTile(
            dense: true,
            leading: Checkbox(
                value: task.completed, onChanged: null), // Static checkbox
            title: Text(
              task.content,
              style: textStyleComplete, // Use faded style
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const SizedBox(width: 80), // Placeholder width
          ),
        ),
      ),
    );
  }

  // --- Speech Recognition Methods ---
  void _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (e) => print('Speech Init Err: $e'),
        onStatus: _speechStatusListener,
      );
      if (mounted) setState(() => _isSpeechEnabled = available);
      print("Speech recognition available: $available");
    } catch (e) {
      print("Could not initialize speech recognition: $e");
      if (mounted) setState(() => _isSpeechEnabled = false);
    }
  }

  void _speechStatusListener(String status) {
    final bool currentlyListening = _speechToText.isListening;
    if (mounted && currentlyListening != _isListening) {
      setState(() => _isListening = currentlyListening);
      print("Speech status changed: $status - Listening: $_isListening");
      if (!_isListening && _lastWords.isNotEmpty) {
        print(
            "Adding task from speech status change (stop/pause/error): $_lastWords");
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _lastWords.isNotEmpty) {
            // Check mounted again
            _addTaskFromSpeech(_lastWords);
          }
        });
      } else if (!_isListening) {
        _resetInputHint();
      }
    }
  }

  void _startListening() async {
    if (!_isSpeechEnabled) {
      _showErrorSnackbar("Speech", "Not available");
      return;
    }
    if (_isListening || !mounted) return;
    _lastWords = "";
    if (mounted) setState(() => _isListening = true);
    _taskInputController.clear();
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: "en_US",
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
      );
    } catch (e) {
      print("Error starting listening: $e");
      if (mounted) {
        _showErrorSnackbar("Speech start error", e);
        setState(() => _isListening = false);
        _resetInputHint();
      }
    }
  }

  void _stopListening() async {
    if (!_isListening || !mounted) return; // Added mounted check
    await _speechToText.stop();
    print("Manual stop listening requested.");
    _resetInputHint();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final recognized = result.recognizedWords;
    setState(() {
      _lastWords = recognized;
      _taskInputController.text = _lastWords;
      _taskInputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _taskInputController.text.length),
      );
    });
    print("Recognized words: '$recognized' | Final: ${result.finalResult}");
    if (result.finalResult && recognized.isNotEmpty) {
      print("Processing final speech result.");
      _addTaskFromSpeech(recognized);
    }
  }

// Inside class _TaskNovaHomePageState extends State<TaskNovaHomePage>

  void _addTaskFromSpeech(String content) async {
    // Basic checks
    if (!mounted || content.isEmpty) return;

    final String taskContentForAudio =
        content; // Keep content for audio if needed later
    // print("Adding task from speech content: $content"); // Optional logging

    // Clear speech buffer and text field immediately
    if (mounted) setState(() => _lastWords = '');
    _resetInputHint();

    // --- Attempt to add the task via API ---
    // Wrap _addTask in its own try-catch to differentiate add errors from audio errors
    bool addTaskSucceeded = false;
    try {
      await _addTask(
          content: taskContentForAudio); // Call the main adder function
      addTaskSucceeded = true; // Assume success if no exception is caught here
    } catch (e_add) {
      // _addTask should ideally handle showing its own error snackbar via _showErrorSnackbar
      print("Error occurred within _addTask from speech: $e_add");
      // No need to re-throw or show another error here if _addTask handles it
      addTaskSucceeded = false;
    }

    // --- Play confirmation sound and Haptic feedback *only if* task add seemed successful ---
    if (addTaskSucceeded && mounted) {
      // Check mounted again before playing audio/haptics
      try {
        await _audioPlayer.play(AssetSource('audio/gotitcaptain.mp3'));
        HapticFeedback.lightImpact(); // <-- ADD HAPTIC FEEDBACK HERE
        // print("Played confirmation sound."); // Optional logging
      } catch (e_audio) {
        print(
            "Error playing confirmation sound: $e_audio"); // Optional logging for audio error
      }
    }
  }

// ... rest of your _TaskNovaHomePageState class ...

  void _resetInputHint() {
    if (mounted) _taskInputController.clear();
  }

  // --- Show Dialog Methods ---

  /// Helper Function to Show Dialogs with Animation
  Future<T?> showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
    Duration transitionDuration = const Duration(milliseconds: 350),
    Curve scaleCurve = Curves.easeOutCubic,
    Curve fadeCurve = Curves.easeOutCubic,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: transitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext);
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: scaleCurve),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: fadeCurve),
            child: child,
          ),
        );
      },
    );
  }

  // Updated functions using the helper
  Future<void> _showMotivationDialog() async {
    showAnimatedDialog<void>(
      context: context,
      builder: (dialogContext) =>
          MotivationDialogContent(apiService: _apiService),
    );
  }

  Future<void> _showAiResponseDialog(Task task) async {
    showAnimatedDialog<void>(
      context: context,
      builder: (dialogContext) => _AiDialogContent(
        apiService: _apiService,
        taskContent: task.content,
      ),
    );
  }

  // Inside class _TaskNovaHomePageState { ... }

// === ADD THIS ENTIRE METHOD ===
  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _loadingCategories = true);

    try {
      final categories = await _apiService.fetchCategories();
      if (mounted) {
        setState(() {
          // Ensure 'default' is always present and first? Or handle empty list.
          _categories = [
            'default',
            ...categories.where((c) => c != 'default').toSet()
          ]; // Example: Ensure default is first
          // Ensure selectedCategory is valid
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory =
                _categories.isNotEmpty ? _categories.first : 'default';
          }
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCategories = false);
        _showErrorSnackbar("Load categories failed", e);
      }
    }
  }
// ===============================

  // --- Error Snackbar Helper ---
  void _showErrorSnackbar(String prefix, Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "$prefix: ${error.toString().replaceFirst('Exception: ', '')}"),
          backgroundColor:
              Theme.of(context).colorScheme.error, // Use themed error color
          behavior: SnackBarBehavior.floating, // Optional: Make snackbar float
          shape: RoundedRectangleBorder(
            // Optional: Rounded corners
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      );
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    const String inputHint = 'Enter a new task...';
    final theme = Theme.of(context); // Get theme for UI elements

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskNova'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Motivate',
            onPressed: _showMotivationDialog,
            // Use foregroundColor from AppBar theme implicitly
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: widget.onThemeChanged,
            // Use foregroundColor from AppBar theme implicitly
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                // --- Task Input Row ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskInputController,
                          onChanged: (value) {
                            // Need setState to update suffixIcon visibility
                            if (mounted) setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText: inputHint,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    8), // Consistent rounding
                                borderSide: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.5)) // Subtle border
                                ),
                            focusedBorder: OutlineInputBorder(
                                // Style when focused
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10), // Adjusted padding
                            suffixIcon: _taskInputController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20.0),
                                    tooltip: 'Clear Text',
                                    color: theme.iconTheme.color?.withOpacity(
                                        0.7), // Use themed icon color
                                    onPressed: () {
                                      if (mounted) {
                                        // Check mounted before setState
                                        setState(
                                            () => _taskInputController.clear());
                                      }
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _addTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Task Button (using themed icon color now)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 30,
                        // Using specific primary color might be intended here
                        color: theme.colorScheme.primary,
                        tooltip: 'Add Task',
                        onPressed: _addTask,
                      ),
                      const SizedBox(width: 4),
                      // Mic Button (using themed icon color)
                      IconButton(
                        icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                        iconSize: 30,
                        color: _isListening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        tooltip:
                            _isListening ? 'Stop Listening' : 'Add via Voice',
                        onPressed:
                            (_speechToText.isNotListening || !_isListening)
                                ? _startListening
                                : _stopListening,
                      ),
                    ],
                  ),
                ),
                // --- Task List Area ---
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary))) // Themed loading
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                      color: theme.colorScheme
                                          .error), // Themed error text
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _tasks.isEmpty
                              ? Center(
                                  // Keeping improved empty state
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_box_outline_blank,
                                            size: 80.0,
                                            color: theme.iconTheme.color
                                                ?.withOpacity(
                                                    0.5)), // Themed icon
                                        const SizedBox(height: 16.0),
                                        Text(
                                            'All tasks complete, or list is empty!',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                    color: theme.textTheme
                                                        .bodyMedium?.color
                                                        ?.withOpacity(
                                                            0.7)), // Themed text
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 8.0),
                                        Text(
                                            'Add a new task using the field above\nor tap the microphone!',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                    color: theme.textTheme
                                                        .bodyMedium?.color
                                                        ?.withOpacity(
                                                            0.6)), // Themed text
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadTasks,
                                  child: AnimatedList(
                                    key: _listKey,
                                    initialItemCount: _tasks.length,
                                    padding: const EdgeInsets.only(
                                        bottom:
                                            80), // Add padding at bottom to avoid overlap with potential FAB/Banner
                                    itemBuilder: (context, index, animation) {
                                      if (index >= _tasks.length) {
                                        return const SizedBox
                                            .shrink(); // Bounds check
                                      }
                                      return _buildAnimatedTaskItem(
                                          _tasks[index], animation, index);
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
          // --- Ad Banner Area ---
          if (_isBannerAdLoaded && _bannerAd != null)
            SafeArea(
              top: false,
              child: Container(
                color: theme.colorScheme.surface, // Theme background
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          else
            SizedBox(height: AdSize.banner.height.toDouble()), // Reserve space
        ],
      ),
    );
  }

  // --- Helper: Build list item with polish ---
  Widget _buildAnimatedTaskItem(
      Task task, Animation<double> animation, int index) {
    final theme = Theme.of(context);
    final textStyleIncomplete = theme.textTheme.titleMedium?.copyWith(
      decoration: TextDecoration.none,
      color: theme.textTheme.titleMedium?.color,
    );
    final textStyleComplete = theme.textTheme.titleMedium?.copyWith(
      decoration: TextDecoration.lineThrough,
      color: theme.textTheme.titleMedium?.color?.withOpacity(0.6),
      decorationColor: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
      decorationThickness: 1.5,
    );

    // === Make sure this matches your existing animation setup ===
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      axis: Axis.vertical,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Container(
            decoration: BoxDecoration(
                // Make sure cardColor is defined or fallback
                color: Theme.of(context).cardColor ??
                    (widget.isDarkMode ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  // Optional subtle shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: ListTile(
              // === MODIFY THIS LISTTILE ===
              key: ValueKey(task.id),
              dense: true,
              onTap: () => _toggleTaskCompletion(task),
              onLongPress: () =>
                  _openTaskDetailDialog(task), // <<< ADDED onLongPress

              leading: Transform.scale(
                // Keep Checkbox
                scale: 1.1,
                child: Checkbox(
                  value: task.completed,
                  activeColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => _toggleTaskCompletion(task),
                ),
              ),

              title: AnimatedDefaultTextStyle(
                // Keep Title
                style: task.completed
                    ? (textStyleComplete ?? const TextStyle())
                    : (textStyleIncomplete ??
                        const TextStyle()), // Use fallback
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Text(
                  task.content, // Make sure you changed this from task to task.content
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // === ADD SUBTITLE HERE ===
              subtitle: task.hasSubtasks
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: task.totalSubtasks > 0
                                  ? (task.completedSubtasks /
                                      task.totalSubtasks)
                                  : 0.0,
                              backgroundColor: theme
                                      .colorScheme.surfaceVariant ??
                                  Colors.grey
                                      .shade300, // Use theme color or fallback
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary.withOpacity(0.7),
                              ),
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(
                                  2), // Optional rounded corners
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.completedSubtasks}/${task.totalSubtasks}', // Counts
                            // Style the count text
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    )
                  : null, // No subtitle if no subtasks
              // === END SUBTITLE ===

              // === MODIFY TRAILING ROW CHILDREN HERE ===
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === ADD CATEGORY INDICATOR (Conditional) ===
                  if (task.category != 'default')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(
                          right: 6), // Spacing before next button
                      decoration: BoxDecoration(
                        // Use a themed background, maybe less opaque
                        color:
                            theme.colorScheme.primaryContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12), // Pill shape
                      ),
                      child: Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 10, // Small text
                          fontWeight: FontWeight.w500,
                          // Themed text color
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // === END CATEGORY INDICATOR ===

                  // --- KEEP EXISTING AI BUTTON ---
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: task.completed ? 0.6 : 1.0,
                    child: IconButton(
                      icon: const Icon(Icons.psychology_alt, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Ask AI',
                      onPressed: task.completed
                          ? null
                          : () => _showAiResponseDialog(task),
                      // Themed icon color
                      color: theme.iconTheme.color?.withOpacity(0.8),
                    ),
                  ),
                  // --- KEEP EXISTING DELETE BUTTON ---
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: task.completed ? 0.6 : 1.0,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete Task',
                      // Themed error color
                      color: theme.colorScheme.error.withOpacity(0.8),
                      onPressed: () => _deleteTask(task.id, index),
                    ),
                  ),
                ],
              ),
              // === END TRAILING ROW MODIFICATION ===
            ), // End ListTile
          ), // End Container
        ), // End Padding
      ), // End FadeTransition
    ); // End SizeTransition
  }
} // End _TaskNovaHomePageState

// ===================================================
// 💬 DIALOG WIDGETS (WITH NEW STYLING/TRANSITIONS)
// ===================================================

class MotivationDialogContent extends StatefulWidget {
  final ApiService apiService;

  const MotivationDialogContent({required this.apiService, super.key});

  @override
  State<MotivationDialogContent> createState() =>
      _MotivationDialogContentState();
}

class _MotivationDialogContentState extends State<MotivationDialogContent> {
  bool _isLoading = true;
  String? _motivationalQuote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMotivationalQuote();
  }

  Future<void> _fetchMotivationalQuote() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Assuming your ApiService has a method to fetch motivational quotes
      final quote = await widget.apiService.getMotivation();
      if (mounted) {
        setState(() {
          _motivationalQuote = quote;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: const Text('Motivation'),
      content: Container(
        constraints: const BoxConstraints(minHeight: 80, minWidth: 250),
        alignment: Alignment.center,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: theme.colorScheme.error, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Oops! $_error',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Text(
                    _motivationalQuote ??
                        'Stay focused and keep pushing forward! You are doing great!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _fetchMotivationalQuote,
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// _AiDialogContent widget definition remains the same
class _AiDialogContent extends StatefulWidget {
  final ApiService apiService;
  final String taskContent;
  const _AiDialogContent(
      {required this.apiService, required this.taskContent, super.key});
  @override
  State<_AiDialogContent> createState() => _AiDialogContentState();
}

// === CORRECTED STATE CLASS ===
class _AiDialogContentState extends State<_AiDialogContent> {
  bool _isDialogLoading = true;
  String? _aiResponse;
  String? _aiError;

  // --- TTS State ---
  late FlutterTts flutterTts;
  bool _isSpeaking = false;
  // --- End TTS State ---

  @override
  void initState() {
    super.initState();
    _initializeTts(); // Initialize TTS
    _fetchAiResponse();
  }

  // === CORRECTED Initialize TTS Method ===
  void _initializeTts() {
    flutterTts = FlutterTts();
    // ADD THESE LISTENERS!
    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      print("TTS Completion Handler Fired"); // Debug print
    });
    flutterTts.setErrorHandler((msg) {
      print("TTS Error Handler Fired: $msg"); // Debug print
      if (mounted) setState(() => _isSpeaking = false);
    });
    flutterTts.setStartHandler(() {
      print("TTS Start Handler Fired"); // Debug print
      if (mounted) setState(() => _isSpeaking = true);
    });
    // --- End Listener Addition ---
    // flutterTts.setLanguage("en-US"); // Optional
    // flutterTts.setPitch(1.0);      // Optional
    // flutterTts.setSpeechRate(0.5); // Optional
  }
  // ===================================

  // === ADDED Dispose Method ===
  @override
  void dispose() {
    flutterTts.stop(); // Stop speaking when dialog is disposed
    print("AI Dialog Disposed - TTS Stopped"); // Debug print
    super.dispose(); // Call parent dispose AFTER stopping TTS
  }
  // ==========================

  Future<void> _fetchAiResponse() async {
    if (!mounted) return;
    setState(() {
      _isDialogLoading = true;
      _aiError = null;
      _aiResponse = null;
      _isSpeaking = false; // Ensure speaking state is reset on fetch
    });
    try {
      final result = await widget.apiService.askAI(widget.taskContent);
      if (mounted) {
        setState(() {
          _aiResponse = result;
          _isDialogLoading = false;
        });
        // No automatic _speak call here - user triggers via button
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.toString().replaceFirst('Exception: ', '');
          _isDialogLoading = false;
        });
      }
    }
  }

  // === Speak/Stop Functions (Keep these) ===
  Future<void> _speak(String text) async {
    if (text.isNotEmpty && mounted) {
      var result = await flutterTts.stop(); // Stop just in case
      if (result == 1) {
        // Check if stop was successful before speaking
        // setState(() => _isSpeaking = true); // setStartHandler should manage this
        await flutterTts.speak(text);
      }
    }
  }

  Future<void> _stopSpeaking() async {
    if (mounted) {
      var result = await flutterTts.stop();
      // if (result == 1) setState(() => _isSpeaking = false); // Let completion handler manage this for consistency
    }
  }
  // ===========================================

  // *** CORRECTED build Method ***
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      // Use theme's default title text style
      title: const Text('AI Insights'),

      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80, minWidth: 250),
          alignment: Alignment.center,
          child: _isDialogLoading
              ? Center(
                  child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ))
              : _aiError != null
                  ? Column(
                      // Consistent Error display
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: theme.colorScheme.error, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Oops! $_aiError',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : SelectableText(_aiResponse ?? 'No insights found.',
                      style: theme.textTheme.bodyLarge),
        ),
      ),

      // === CORRECTED Actions - includes Speak/Stop Button ===
      actions: <Widget>[
        // Add the Speak/Stop Button
        if (!_isDialogLoading && _aiResponse != null && _aiResponse!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(_isSpeaking
                  ? Icons.stop_circle_outlined // Icon for Stop
                  : Icons.play_circle_outline), // Icon for Play
              tooltip: _isSpeaking ? 'Stop Reading' : 'Read Aloud',
              color: theme.colorScheme.primary,
              iconSize: 28,
              onPressed: _isSpeaking
                  ? _stopSpeaking
                  : () => _speak(_aiResponse!), // Call speak with response
            ),
          ),
        // --- End Speak/Stop Button ---

        // Existing Retry Button
        if (_aiError != null)
          TextButton(
            onPressed: _fetchAiResponse,
            child: const Text('Retry'),
          ),
        // Existing Close Button
        TextButton(
            child: const Text('Close'),
            onPressed: () {
              if (_isSpeaking) {
                // Ensure speech stops on close if playing
                _stopSpeaking();
              }
              Navigator.of(context).pop();
            }),
      ],
      // ====================================================
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    );
  } // End build
} // End State class
