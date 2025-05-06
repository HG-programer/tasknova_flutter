// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Removed unused import for flutter_tts

import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

// Import the separated files
import 'task.dart';
import 'api_service.dart';
import 'task_detail_dialog.dart';
import 'dialogs/motivation_dialog.dart'; // Needs public MotivationDialogContent
import 'dialogs/ai_dialog.dart'; // Needs public AiDialogContent

// --- Constants ---
const Duration _kShortDuration = Duration(milliseconds: 200);
const Duration _kMediumDuration = Duration(milliseconds: 350);
const Duration _kLongDuration = Duration(milliseconds: 400);
const double _kIconSizeSmall = 18.0;
const double _kIconSizeMedium = 22.0;
const double _kIconSizeLarge = 32.0;
const EdgeInsets _kInputRowPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);
const EdgeInsets _kListItemPadding =
    EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0);
const EdgeInsets _kErrorPadding = EdgeInsets.all(24);
const EdgeInsets _kEmptyListPadding = EdgeInsets.all(32.0);

//==============================================================================
// Main Application Entry Point & Theme Setup
//==============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Consider deferring AdMob initialization if it causes startup lag
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Error initializing AdMob SDK: $e");
  }
  runApp(const MyApp());
}

// --- Main Application Widget ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      HapticFeedback.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskNova',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: TaskNovaHomePage(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF121212) : Colors.white;
    final Color onSurfaceColor = isDark ? Colors.white : Colors.black87;
    final Color primaryColor =
        isDark ? Colors.blueGrey[700]! : const Color(0xFF0d6efd);
    final Color primaryContainerColor =
        isDark ? Colors.blueGrey[800]! : Colors.blue[100]!;
    final Color onPrimaryContainerColor =
        isDark ? Colors.blue[100]! : Colors.blue[900]!;
    final Color surfaceContainerHighestColor =
        isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final Color errorColor = isDark ? Colors.redAccent[200]! : Colors.red[700]!;
    final Color outlineColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color hintColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final Color disabledColor = isDark ? Colors.grey[600]! : Colors.grey[500]!;
    final Color dividerColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final Color chipBackgroundColor =
        isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final Color chipSelectedColor =
        primaryColor.withAlpha((0.85 * 255).round());
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        primary: primaryColor,
        error: errorColor,
        primaryContainer: primaryContainerColor,
        onPrimaryContainer: onPrimaryContainerColor,
        surfaceContainerHighest: surfaceContainerHighestColor,
      ).copyWith(
        surfaceTint: Colors.transparent,
        outline: outlineColor,
      ),
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 1.0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: 1.0,
        color: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? const Color(0xFF1e1e1e) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        titleTextStyle: TextStyle(
          color: onSurfaceColor,
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: onSurfaceColor
              .withAlpha((0.85 * 255).round()), // Correct alpha use
          fontSize: 15.0,
          height: 1.4,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBackgroundColor, // Guaranteed non-null
        selectedColor: chipSelectedColor,
        labelStyle: TextStyle(
          // Guaranteed non-null style provided
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide.none,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      iconTheme: IconThemeData(
        // Guaranteed non-null color provided
        color: iconColor,
        size: _kIconSizeMedium,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(padding: const EdgeInsets.all(8)),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      hintColor: hintColor,
      disabledColor: disabledColor,
      inputDecorationTheme: InputDecorationTheme(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: outlineColor, width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 1.5)),
        labelStyle:
            TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        hintStyle: TextStyle(color: hintColor),
        isDense: true,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: surfaceContainerHighestColor,
        circularTrackColor: surfaceContainerHighestColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        actionTextColor: isDark ? Colors.lightBlue[200] : Colors.lightBlue[100],
        elevation: 4.0,
      ),
    );
  }
}

//==============================================================================
// Home Page Widget
//==============================================================================
class TaskNovaHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged;
  const TaskNovaHomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<TaskNovaHomePage> createState() => _TaskNovaHomePageState();
}

class _TaskNovaHomePageState extends State<TaskNovaHomePage> {
  // --- State ---
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _taskInputController = TextEditingController();
  final ApiService _apiService = ApiService();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // AdMob State
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _bannerAdUnitId =
      "ca-app-pub-3940256099942544/6300978111"; // Test Ad ID

  // Speech Recognition State
  final SpeechToText _speechToText = SpeechToText();
  bool _isSpeechEnabled = false;
  bool _isListening = false;
  // String _lastWords = ''; // REMOVED - Unused field

  // Audio Player State
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    // Initial load sequence
    _loadInitialData(); // Start fetching tasks
    _loadBannerAd(); // Start loading banner ad
    _initSpeech(); // Initialize speech recognition

    // Consider moving _initSpeech if it's heavy and not immediately needed
    // e.g., initialize only when the mic button is first pressed

    _speechToText.statusListener = _speechStatusListener;
  }

  @override
  void dispose() {
    _taskInputController.dispose();
    _bannerAd?.dispose();
    // Safely stop speech if listening
    if (_isListening) {
      _speechToText.stop().catchError(
          (e) => debugPrint("Error stopping speech on dispose: $e"));
    }
    _speechToText.cancel().catchError((e) => debugPrint(
        "Error cancelling speech on dispose: $e")); // Good practice to cancel too
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Data Loading ---
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tasks = await _apiService.fetchTasks();
      if (!mounted) return; // Check again after async gap
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Load failed: ${e.toString()}"); // Log for debugging
      if (!mounted) return; // Check again
      setState(() {
        _errorMessage =
            "Load failed. Please check connection."; // User-friendly message
        _isLoading = false;
      });
    }
  }

  // Helper to prepare categories.
  List<String> _prepareCategories(List<String> cats) {
    final Set<String> uniqueCats = {
      'default',
      ...cats
    }; // Ensure 'default' exists and handle duplicates
    final List<String> sortedCats = uniqueCats.toList();
    sortedCats.sort((a, b) {
      if (a == 'default') return -1;
      if (b == 'default') return 1;
      return a.compareTo(b);
    });
    return sortedCats;
  }

  // --- Ad Loading ---
  void _loadBannerAd() {
    // Ensure previous ad is disposed if any
    _bannerAd?.dispose();
    _bannerAd = null;
    if (mounted) {
      setState(() => _isBannerAdLoaded = false); // Reset loading state
    } else {
      return; // Don't proceed if not mounted
    }

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner Ad loaded.');
          if (mounted) {
            setState(() {
              // Keep the current ad instance
              _bannerAd = ad as BannerAd;
              _isBannerAdLoaded = true;
            });
          } else {
            // Widget was disposed before ad loaded
            ad.dispose();
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner Ad load failed: $err');
          ad.dispose(); // Dispose the failed ad
          if (mounted) {
            setState(() => _isBannerAdLoaded = false);
          }
        },
        // Add other listeners if needed (onAdOpened, onAdClosed, etc.)
      ),
    )..load(); // Start loading
  }

  // --- Task List Refresh ---
  Future<void> _loadTasks() async {
    if (!mounted) return;
    // Consider showing visual feedback during refresh, though RefreshIndicator does this
    setState(() => _errorMessage = null); // Clear previous errors
    try {
      final tasks = await _apiService.fetchTasks();
      if (mounted) {
        // Animate list changes might be complex here, simple setState is usually sufficient for refresh
        setState(() => _tasks = tasks);
      }
    } catch (e) {
      debugPrint("Refresh failed: $e");
      if (mounted) {
        _showErrorSnackbar("Refresh failed", e);
      }
    }
  }

  // --- CRUD Operations ---
  Future<void> _addTask(
      {String? content, String? category, int? parentId}) async {
    final String taskContent = content ?? _taskInputController.text.trim();
    final String taskCategory = category ?? 'default';

    if (taskContent.isEmpty || !mounted) return;

    FocusScope.of(context).unfocus(); // Dismiss keyboard

    // Optional: Show a temporary loading indicator if add takes time
    // bool wasLoading = true; // If using indicator
    // setState(() => _isAddingTask = true); // Set loading state

    try {
      final newTask = await _apiService.addTask(taskContent,
          category: taskCategory, parentId: parentId);

      if (!mounted) return; // Check again after await

      bool listKeyWasAvailable = false;

      // Only handle insertion for top-level tasks in this list view
      if (newTask.parentId == null) {
        // 1. Modify the data source FIRST
        _tasks.insert(0, newTask);

        // 2. Inform the AnimatedList WITHOUT wrapping this in setState
        // Check if the list state is available (important!)
        if (_listKey.currentState != null) {
          _listKey.currentState!.insertItem(0, duration: _kLongDuration);
          debugPrint(
              "[_addTask] Called AnimatedList.insertItem for task ID ${newTask.id}");
          listKeyWasAvailable = true; // Animation should have been triggered
        } else {
          // List state wasn't ready (e.g., was showing empty/error message)
          debugPrint(
              "[_addTask] _listKey.currentState was null. Relying on setState to show the item.");
          listKeyWasAvailable = false;
        }
      }
      // ELSE: If it's a subtask, its state is managed elsewhere (e.g., TaskDetailDialog)

      // 3. Call setState AFTER data modification and potential AnimatedList interaction.
      // This signals Flutter to rebuild necessary parts of the UI.
      // It ensures the list reflects the added item, especially if:
      //    a) The list key was null (list wasn't visible/ready)
      //    b) Other UI elements depend on the list length or content (though less common here)
      //    c) To handle the clearing of the text field below consistently.
      setState(() {
        // Any other state updates needed after adding can go here.
        // If you cleared the input *before* setState, the state change might be lost.
        if (content == null) {
          // Clear input only if added via text field
          _taskInputController.clear();
          debugPrint("[_addTask] Cleared text input controller.");
        }
        // _isAddingTask = false; // Reset loading indicator if used
      });

      // --- Post-Addition UI Feedback (after state is updated) ---
      _showSuccessSnackbar('Task added!');
      HapticFeedback.lightImpact();
      _playSuccessSound(); // Fine to call here, assumed quick/async
    } catch (e) {
      debugPrint("[_addTask] Add Task failed: $e");
      // if (mounted) setState(() => _isAddingTask = false); // Reset loading on error if used
      if (mounted) {
        // Check mounted status before showing snackbar
        _showErrorSnackbar("Add failed", e);
      }
    }
    // No finally block needed for loading state if set within setState
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    if (!mounted) return;
    final int taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex == -1) return; // Task not found in the current list

    final originalState = _tasks[taskIndex].completed;

    // Optimistic UI Update
    setState(() {
      // Mutate the task object directly within the list for visual change
      _tasks[taskIndex].completed = !originalState;
      // This relies on AnimatedDefaultTextStyle inside buildAnimatedTaskItem
      // and potentially updates to subtask progress if logic is tied here.
    });
    HapticFeedback.lightImpact(); // Provide feedback immediately

    try {
      // Make API call
      await _apiService.updateTaskCompletion(task.id, !originalState);
      // Optional: Refresh subtask counts/progress if API returns updated Task?
    } catch (e) {
      debugPrint("Update completion failed: $e");
      if (mounted) {
        // Revert UI if API call failed
        setState(() {
          _tasks[taskIndex].completed = originalState;
        });
        _showErrorSnackbar("Update failed", e);
      }
    }
  }

  Future<void> _deleteTask(int taskId, int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _tasks.length ||
        _tasks[index].id != taskId) {
      debugPrint(
          "[_deleteTask] Precondition failed: mounted=$mounted, index=$index, length=${_tasks.length}, task.id=${_tasks.length > index && index >= 0 ? _tasks[index].id : 'N/A'}, expectedId=$taskId");
      return; // Precondition failed
    }

    // 1. Get the task to remove for the animation builder and potential rollback
    final Task taskToDelete = _tasks[index]; // Keep reference

    // 2. Optimistically update the state list *first*
    _tasks.removeAt(index);

    // 3. Tell AnimatedList to remove the item visually, IF the list key is available
    bool listKeyWasAvailable = false;
    if (_listKey.currentState != null) {
      _listKey.currentState!.removeItem(
        index, // Index from which item was removed
        (context, animation) => _buildRemovedTaskItem(
            taskToDelete, animation), // Builder for outgoing animation
        duration: _kMediumDuration,
      );
      debugPrint(
          "[_deleteTask] Called AnimatedList.removeItem for task ID ${taskToDelete.id} at index $index.");
      listKeyWasAvailable = true;
    } else {
      debugPrint(
          "[_deleteTask] _listKey.currentState was null when removing item. Will rely on setState later if API succeeds.");
      listKeyWasAvailable = false;
      // No animation, but the data is removed. If API fails, need to setState on rollback.
      // If API succeeds, need a setState to ensure UI redraws without the item.
    }

    // Give optimistic feedback *before* API call
    HapticFeedback.lightImpact();
    _showSuccessSnackbar('Task "${taskToDelete.content}" deleted.',
        isDelete: true); // Show confirmation early

    // 4. Call the API
    try {
      await _apiService.deleteTask(taskId);
      debugPrint("[_deleteTask] API delete successful for task ID $taskId.");

      // 5. If the animation couldn't run, call setState now to ensure the UI redraws correctly
      if (!listKeyWasAvailable && mounted) {
        debugPrint(
            "[_deleteTask] API success, calling setState because AnimatedList animation couldn't run.");
        setState(() {});
      }
      // If animation DID run, the list is visually correct already, no extra setState needed on success.
    } catch (e) {
      debugPrint("[_deleteTask] Delete API failed for task ID $taskId: $e");
      if (mounted) {
        // 6. Rollback UI on API error
        debugPrint(
            "[_deleteTask] Rolling back deletion for task ID $taskId at index $index.");
        // Insert the original task data back into the list state
        _tasks.insert(index, taskToDelete);

        // Attempt to tell AnimatedList to insert it back visually (instantly)
        bool rollbackInsertAnimated = false;
        if (_listKey.currentState != null) {
          // Note: This might look odd if the user scrolled during the delete attempt.
          _listKey.currentState!.insertItem(index, duration: Duration.zero);
          debugPrint(
              "[_deleteTask] Called AnimatedList.insertItem for rollback.");
          rollbackInsertAnimated = true;
        } else {
          debugPrint(
              "[_deleteTask] _listKey.currentState was null during rollback insertItem.");
        }

        // ALWAYS call setState after rollback attempt to guarantee UI consistency,
        // whether insertItem ran or not.
        setState(() {});
        _showErrorSnackbar("Delete failed, restored task", e);
      }
    }
  }

  Widget _buildRemovedTaskItem(Task task, Animation<double> animation) {
    final theme = Theme.of(context);
    // Use slightly faded text style
    final textStyleFaded =
        (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      decoration: TextDecoration.lineThrough,
      color: theme.disabledColor.withAlpha((255 * 0.7).round()), // Use alpha
    );
    return SizeTransition(
      sizeFactor: CurvedAnimation(
          // Apply curve to size transition too
          parent: animation,
          curve: Curves.easeOutCubic),
      child: Padding(
        padding: _kListItemPadding,
        child: Card(
          // Fade the card background as it animates out
          color: theme.cardTheme.color
              ?.withAlpha((255 * 0.6).round()), // Use alpha
          elevation: 0, // Reduce elevation during removal
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Checkbox(
              value: task.completed,
              onChanged: null, // Non-interactive during removal
              // Consider styling disabled checkbox
              side: BorderSide(color: theme.disabledColor),
              checkColor: theme.scaffoldBackgroundColor,
              activeColor: theme.disabledColor
                  .withAlpha((255 * 0.5).round()), // Use alpha
            ),
            title: Text(
              task.content,
              style: textStyleFaded,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const SizedBox(width: 90), // Keep layout consistent
          ),
        ),
      ),
    );
  }

  // --- Speech Recognition ---
  void _initSpeech() async {
    bool available = false;
    try {
      available = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('Speech Init Error: $errorNotification');
          // Show user feedback?
          if (mounted) {
            setState(() => _isSpeechEnabled = false);
            // Maybe show a snackbar "Speech recognition unavailable"
          }
        },
        // onStatus: (status) => print('Speech Status: $status'), // Already handled by listener
        // debugLog: false, // REMOVED - Undefined parameter
      );
    } catch (e) {
      debugPrint("Could not initialize speech recognition: $e");
      available = false; // Ensure it's false on exception
    } finally {
      if (mounted) {
        setState(() => _isSpeechEnabled = available);
        if (!available) {
          // Consider informing user speech isn't available permanently (if needed)
        }
      }
    }
  }

  void _speechStatusListener(String status) {
    debugPrint("Speech Status: $status");
    // Update listening state based on the speech engine's status
    if (mounted) {
      final isCurrentlyListening = _speechToText.isListening;
      // Check if state needs updating to avoid unnecessary rebuilds
      if (_isListening != isCurrentlyListening) {
        setState(() {
          _isListening = isCurrentlyListening;
        });
      }
      // Update the text field hint *after* state update
      // Moved _resetInputHint call here to ensure it runs *after* setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetInputHint();
      });
    }
  }

  void _startListening() async {
    if (!_isSpeechEnabled || !mounted) {
      _showErrorSnackbar("Speech not enabled",
          "Please grant permission or check device settings.");
      return;
    }
    if (_isListening) {
      debugPrint("Already listening, ignoring start request.");
      return; // Already listening
    }

    // _lastWords = ""; // REMOVED - Field unused

    // Update state *before* starting listen to change UI immediately
    setState(() => _isListening = true);
    _taskInputController.clear(); // Clear text field
    _resetInputHint(); // Update hint immediately

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: "en_US", // Consider making this configurable?
        listenFor: const Duration(seconds: 30), // Max listen duration
        pauseFor:
            const Duration(seconds: 3), // Duration of silence before stopping
        listenOptions: SpeechListenOptions(
          partialResults: true, // Show words as they are recognized
          cancelOnError: true, // Stop listening on error
          listenMode: ListenMode
              .confirmation, // Wait for confirmation (may vary by platform)
          // Other options like sampleRate, autoPunctuation might be available
        ),
      );
    } catch (e) {
      debugPrint("Speech listen error: $e");
      if (mounted) {
        _showErrorSnackbar("Speech start error", e);
        // Ensure state is reverted if listen fails to start
        setState(() => _isListening = false);
        _resetInputHint();
      }
    }
  }

  void _stopListening() async {
    if (!_isListening || !mounted) return;
    // Don't set _isListening to false here, let the status listener handle it
    try {
      await _speechToText.stop();
      // State update will happen via _speechStatusListener
    } catch (e) {
      debugPrint("Error stopping speech: $e");
      // Force state update if stop command fails? Might be needed.
      if (mounted) {
        setState(() => _isListening = false);
        _resetInputHint();
      }
    }
  }

  // Called multiple times during listening (partial results) and once at the end (final result)
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    final recognized = result.recognizedWords;
    // Update the controller text continuously for partial results if listening
    if (_isListening) {
      _taskInputController.text = recognized;
      // Keep cursor at the end
      _taskInputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _taskInputController.text.length));
    }

    // _lastWords = recognized; // REMOVED - Field unused

    // Check if this is the final result and has content
    if (result.finalResult && recognized.trim().isNotEmpty) {
      debugPrint("Final Speech Result: $recognized");
      _addTaskFromSpeech(recognized.trim());
      //  _lastWords = ''; // REMOVED - Field unused
      // Don't clear controller here, _addTask might clear it or speech might stop naturally
      // State (_isListening=false) update should come from status listener 'final'
    }
  }

  Future<void> _addTaskFromSpeech(String content) async {
    if (!mounted || content.isEmpty) return;
    // Use the existing _addTask method, passing the recognized content
    await _addTask(content: content);
  }

  void _resetInputHint() {
    if (!mounted) return;
    // Only change hint based on the current _isListening state
    final hintText = _isListening ? 'Listening...' : 'Enter a new task...';
    // Avoid clearing user input if they stopped listening and typed something
    if (_isListening) {
      _taskInputController.text = hintText; // Set text to 'Listening...'
      // Move cursor to end
      _taskInputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _taskInputController.text.length));
    } else {
      // If currently not listening, and the text field ONLY contains 'Listening...',
      // clear it. Otherwise, leave user's text.
      if (_taskInputController.text == 'Listening...') {
        _taskInputController.clear();
      }
      // Intentionally removed check against _lastWords to avoid clearing potentially corrected user input
    }
  }

  // --- UI Helpers ---
  Future<void> _playSuccessSound() async {
    if (!mounted) return;
    try {
      // Ensure you have 'audio/gotitcaptain.mp3' in your assets/audio folder
      // and declared in pubspec.yaml
      await _audioPlayer.play(AssetSource('audio/gotitcaptain.mp3'));
    } catch (e) {
      debugPrint("Error playing confirmation sound: $e");
      // Maybe show a less intrusive error, like a log or subtle UI cue
      // _showErrorSnackbar("Sound Error", "Could not play confirmation sound."); // Maybe too intrusive
    }
  }

  Future<T?> showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
    Duration transitionDuration = _kMediumDuration,
    Curve scaleCurve = Curves.easeOutCubic, // Keep parameters if needed later
    Curve fadeCurve = Curves.easeOutCubic, // Keep parameters if needed later
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // Use a semi-transparent barrier color
      barrierColor: Colors.black.withAlpha((255 * 0.5).round()), // Use alpha
      transitionDuration: transitionDuration,
      pageBuilder: (ctx, animation1, animation2) => Theme(
        // Ensure dialog uses the app's theme
        data: Theme.of(context),
        child: builder(ctx),
      ),
      transitionBuilder: (context, animation1, animation2, child) {
        // Combine Scale and Fade transitions
        final curvedAnimation = CurvedAnimation(
            parent: animation1,
            curve: Curves.easeOutCubic); // Use scaleCurve here?
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
              opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation1,
                      curve: Curves.easeInOut)), // Use fadeCurve here?
              child: child),
        );
      },
    );
  }

  // --- Dialog Openers ---
  // Assumes MotivationDialogContent is correctly defined and imported
  Future<void> _showMotivationDialog() async {
    if (!mounted) return; // Check mounted before showing dialog
    showAnimatedDialog<void>(
      context: context,
      // ***** THIS LINE STILL CAUSES ERROR IF MotivationDialogContent IS NOT RESOLVED *****
      builder: (_) => MotivationDialogContent(apiService: _apiService),
    );
  }

  // Assumes AiDialogContent is correctly defined and imported
  Future<void> _showAiResponseDialog(Task task) async {
    if (!mounted) return; // Check mounted
    // Don't show AI dialog for completed tasks? Already handled in buildAnimatedTaskItem's onPressed
    showAnimatedDialog<void>(
      context: context,
      builder: (_) =>
          AiDialogContent(apiService: _apiService, taskContent: task.content),
    );
  }

  // Consolidated error snackbar
  void _showErrorSnackbar(String prefix, Object error) {
    if (!mounted) return;
    // Improve error message formatting
    final String errorMessage = error is Exception
        ? error.toString().replaceFirst("Exception: ", "")
        : error.toString();
    debugPrint("$prefix Error: $errorMessage"); // Log detailed error

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$prefix: $errorMessage"), // Show cleaner message
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating, // Match theme if defined
        shape: Theme.of(context).snackBarTheme.shape, // Use theme shape
      ),
    );
  }

  // Consolidated success snackbar
  void _showSuccessSnackbar(String message, {bool isDelete = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isDelete
            ? Colors.orange[700] // Or use theme.colorScheme.tertiary?
            : Colors.green[600], // Or use theme.colorScheme.secondary?
        behavior: SnackBarBehavior.floating,
        shape: Theme.of(context).snackBarTheme.shape,
      ),
    );
  }

  // --- Dialog Openers --- (Inside _TaskNovaHomePageState class)

  // ... (other dialog openers like _showMotivationDialog, _showAiResponseDialog)

  Future<void> _openTaskDetailDialog(Task taskFromListItem) async {
    // Renamed parameter for clarity
    if (!mounted) return;

    // Find the task in the current list state using the ID from the list item
    final int taskIndex = _tasks.indexWhere((t) => t.id == taskFromListItem.id);
    if (taskIndex == -1) {
      _showErrorSnackbar(
          "Error", "Task not found in list. It might have been deleted.");
      return;
    }

    // *** DEBUGGING: Check the task data retrieved from the state list ***
    final Task taskFromState = _tasks[taskIndex];
    debugPrint("--- Opening Task Detail Dialog ---");
    debugPrint(
        "[_openTaskDetailDialog] Task found in state (_tasks[$taskIndex]):");
    debugPrint("  ID: ${taskFromState.id}");
    debugPrint("  Content: '${taskFromState.content}'"); // Check this value!
    debugPrint("  Category: '${taskFromState.category}'"); // Check this value!
    debugPrint("  Completed: ${taskFromState.completed}");
    debugPrint(
        "  Subtasks: ${taskFromState.completedSubtasks}/${taskFromState.totalSubtasks}");
    // Add other relevant fields if necessary

    // Prepare categories (handling potential errors as before)
    List<String> categoriesToShow = ['default'];
    try {
      final fetchedCategories = await _apiService.fetchCategories();
      if (mounted) {
        categoriesToShow = _prepareCategories(fetchedCategories);
      } else {
        return; // Widget disposed during category fetch
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar("Could not load categories", e);
      }
      // Continue with default categories
    }

    if (!mounted) return; // Check again before showing dialog

    // *** CRITICAL STEP: Create a copy to pass to the dialog ***
    // *** Assumes Task.copyWith correctly copies ALL fields from taskFromState ***
    Task taskToSend = Task.copyWith(taskFromState);

    // *** DEBUGGING: Check the task data *after* the copy operation ***
    debugPrint(
        "[_openTaskDetailDialog] Task data AFTER Task.copyWith (taskToSend):");
    debugPrint("  ID: ${taskToSend.id}"); // Should match taskFromState.id
    debugPrint(
        "  Content: '${taskToSend.content}'"); // Should match taskFromState.content
    debugPrint(
        "  Category: '${taskToSend.category}'"); // Should match taskFromState.category
    // Add other fields if necessary to compare

    // Use the showAnimatedDialog helper
    showAnimatedDialog(
      context: context,
      builder: (dialogContext) => TaskDetailDialog(
        // Pass the copied task
        task: taskToSend,
        apiService: _apiService,
        categories: categoriesToShow,
        // Callback when the dialog signals a potential update
        onTaskPossiblyUpdated: (updatedTaskData) {
          // Ensure the main page is still mounted when the callback occurs
          if (mounted) {
            // *** DEBUGGING: Check the data received FROM the dialog ***
            debugPrint(
                "[onTaskPossiblyUpdated Callback] Data received from dialog:");
            debugPrint("  ID: ${updatedTaskData.id}");
            debugPrint(
                "  Content: '${updatedTaskData.content}'"); // What content did dialog return?
            debugPrint(
                "  Category: '${updatedTaskData.category}'"); // What category did dialog return?
            debugPrint("  Completed: ${updatedTaskData.completed}");
            debugPrint(
                "  Subtasks: ${updatedTaskData.completedSubtasks}/${updatedTaskData.totalSubtasks}");

            setState(() {
              // Find the index again, as list might have changed
              final currentIndex =
                  _tasks.indexWhere((t) => t.id == updatedTaskData.id);
              if (currentIndex != -1) {
                // *** CRITICAL STEP: Update the state list with a copy of the returned data ***
                // *** Assumes Task.copyWith is correctly implemented ***
                _tasks[currentIndex] = Task.copyWith(updatedTaskData);

                // *** DEBUGGING: Verify the task in state AFTER update ***
                debugPrint(
                    "[onTaskPossiblyUpdated Callback] Task in _tasks[$currentIndex] AFTER update:");
                debugPrint("  Content: '${_tasks[currentIndex].content}'");
                debugPrint("  Category: '${_tasks[currentIndex].category}'");
              } else {
                debugPrint(
                    "[onTaskPossiblyUpdated Callback] Warning: Task ID ${updatedTaskData.id} not found in list anymore.");
              }
              // setState rebuilds the specific list item that changed
            });
          } else {
            debugPrint(
                "[onTaskPossiblyUpdated Callback] Warning: HomePage not mounted when callback received.");
          }
        },
      ),
    );
    debugPrint("--- Task Detail Dialog Opened ---");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine clear button visibility based on controller text, not listening state directly affecting display here
    final bool showClearButton = _taskInputController.text.isNotEmpty &&
        _taskInputController.text != 'Listening...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskNova'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Motivate',
            onPressed: _showMotivationDialog, // Assumes MotivationDialog works
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: widget.onThemeChanged,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Input Row ---
          _buildInputRow(theme, showClearButton), // Pass calculated state

          // --- Main Content Area ---
          Expanded(
            child: AnimatedSwitcher(
              // Animate between states
              duration: _kMediumDuration,
              child: _isLoading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorState() // Already wrapped in Padding etc.
                      : _buildTaskList(), // Includes RefreshIndicator and AnimatedList
            ),
          ),

          // --- Banner Ad ---
          // Conditionally build the Ad container
          if (_isBannerAdLoaded && _bannerAd != null)
            SafeArea(
              // Keep SafeArea for the ad
              top: false, // Don't apply safe area padding to the top
              child: Container(
                key: const ValueKey(
                    'ad_loaded'), // Key for AnimatedSwitcher if used
                color: theme.scaffoldBackgroundColor, // Match background
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          else // Placeholder if ad not loaded/available
            SizedBox(
                key: const ValueKey(
                    'ad_placeholder'), // Key for AnimatedSwitcher if used
                height: AdSize.banner.height.toDouble() // Reserve space
                ),
        ],
      ),
    );
  }

  Widget _buildInputRow(ThemeData theme, bool showClearButton) {
    return Padding(
      padding: _kInputRowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              label: "Task input field",
              child: TextField(
                controller: _taskInputController,
                // Input field is only truly read-only when listening actively
                // It should be editable otherwise, even if speech isn't enabled.
                readOnly: _isListening,
                onChanged: (_) {
                  // Need setState to update the clear button visibility
                  if (mounted) {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  // Use controller state to determine hint/text, _resetInputHint handles this
                  hintText:
                      _isListening ? 'Listening...' : 'Enter a new task...',
                  suffixIcon: showClearButton
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: _kIconSizeSmall + 2,
                          ),
                          tooltip: 'Clear Text',
                          // Use theme color directly, theme provides non-null iconTheme
                          color: theme.iconTheme.color!
                              .withAlpha((255 * 0.7).round()), // Use alpha
                          onPressed: () {
                            if (mounted) {
                              // Simply clear the controller and update state
                              _taskInputController.clear();
                              setState(() {});
                            }
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) =>
                    _addTask(), // Add task on keyboard submission
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: "Add task",
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add_circle),
              iconSize: _kIconSizeLarge,
              color: theme.colorScheme.primary,
              tooltip: 'Add Task',
              // Disable add button while listening? Makes sense.
              onPressed: _isListening ? null : _addTask,
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: _isListening
                ? "Stop voice input"
                : (_isSpeechEnabled
                    ? "Add task via voice"
                    : "Voice input unavailable"),
            button: true,
            child: IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              iconSize: _kIconSizeLarge,
              color: _isListening
                  ? theme.colorScheme.error
                  : (_isSpeechEnabled
                      ? theme.colorScheme.primary
                      : theme.disabledColor), // Grey out if not enabled
              tooltip: _isListening
                  ? 'Stop Listening'
                  : (_isSpeechEnabled ? 'Add via Voice' : 'Speech Unavailable'),
              // Only allow press if speech is enabled
              onPressed: _isSpeechEnabled
                  ? (_isListening ? _stopListening : _startListening)
                  : null, // Disable if speech not enabled
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    // Keep this structure, it provides good context and a retry action
    return Center(
      // Use Center for vertical/horizontal alignment
      key: const ValueKey('error'), // Key for AnimatedSwitcher
      child: Padding(
        padding: _kErrorPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take only needed vertical space
          mainAxisAlignment:
              MainAxisAlignment.center, // Center content vertically
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: [
            Icon(
              Icons.error_outline, // Use a more standard error icon?
              size: 60,
              color: theme.colorScheme.error
                  .withAlpha((255 * 0.8).round()), // Use alpha
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load tasks",
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "An unknown error occurred.",
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withAlpha((255 * 0.7).round()) // Use alpha
                  ),
              textAlign: TextAlign.center, // Center error message text
            ),
            const SizedBox(height: 24), // Increased spacing before button
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadInitialData, // Call initial load again
              style: ElevatedButton.styleFrom(
                // Style explicitly or rely on theme
                backgroundColor: theme
                    .colorScheme.errorContainer, // Use themed container colors
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    final theme = Theme.of(context); // Define theme here for use in empty state
    // Key is important for AnimatedSwitcher when switching between empty/list
    if (_tasks.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: _kEmptyListPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_box_outline_blank,
                size: 80.0,
                color: theme.iconTheme.color!.withAlpha(
                    (255 * 0.5).round()), // Use alpha & direct access
              ),
              const SizedBox(height: 16.0),
              Text(
                'No tasks here!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    // Use headlineSmall style
                    // Use alpha and safe access
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withAlpha((255 * 0.7).round())),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Add a new task above or use the mic.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    // Use alpha and safe access
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withAlpha((255 * 0.6).round())),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      // Use a Key on RefreshIndicator if it's the direct child of AnimatedSwitcher
      return RefreshIndicator(
        key: const ValueKey('list'),
        onRefresh: _loadTasks,
        child: AnimatedList(
          key: _listKey, // Use the global key
          initialItemCount: _tasks.length, // Reflect current list length
          padding: const EdgeInsets.only(
              top: 8, bottom: 80), // Padding for content and FAB/Ad space
          itemBuilder: (context, index, animation) {
            // Safety check - though should not happen if initialItemCount is correct
            if (index >= _tasks.length) return const SizedBox.shrink();
            final task = _tasks[index];
            // Pass task, animation, and index to the builder method
            return _buildAnimatedTaskItem(task, animation, index);
          },
        ),
      );
    }
  }

  Widget _buildAnimatedTaskItem(
      Task task, Animation<double> animation, int index) {
    debugPrint(
        "Build Item ${task.id}: isRecurring=${task.isRecurring} (Type: ${task.recurrenceType})");
    final theme = Theme.of(context);
    final bool isComplete = task.completed;

    // Define text styles based on completion state
    final textStyle =
        (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      decoration: isComplete ? TextDecoration.lineThrough : TextDecoration.none,
      color: isComplete
          ? theme.disabledColor
          : theme.colorScheme.onSurface
              .withAlpha((255 * 0.87).round()), // Use alpha
      decorationColor: isComplete
          ? theme.disabledColor
              .withAlpha((255 * 0.7).round()) // Use alpha safely
          : null,
      decorationThickness: 1.5,
    );

    final int totalSubs = task.totalSubtasks;
    final int completedSubs = task.completedSubtasks;
    final bool hasSubs = totalSubs > 0;
    final double? subProgress = hasSubs
        ? (completedSubs / totalSubs.toDouble())
        : null; // Ensure double division
    final bool isRecurring = task.isRecurring; // Use the getter from Task model

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: Padding(
          padding: _kListItemPadding,
          child: Card(
            child: InkWell(
              onTap: () => _toggleTaskCompletion(task),
              onLongPress: () => _openTaskDetailDialog(task),
              borderRadius: BorderRadius.circular(12.0), // Match card shape
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 0,
                    right: 8.0,
                    top: 4.0,
                    bottom: 4.0), // Adjust padding slightly
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- Checkbox ---
                    Semantics(
                      label:
                          "Mark task ${task.content} as ${isComplete ? 'incomplete' : 'complete'}",
                      checked: isComplete,
                      child: Checkbox(
                        value: isComplete,
                        onChanged: (_) => _toggleTaskCompletion(task),
                      ),
                    ),
                    // --- Task Content & Progress ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // *** MODIFIED SECTION for Recurrence Icon ***
                            Semantics(
                              label:
                                  "Task description: ${task.content}${isRecurring ? ' (Recurring)' : ''}", // Add semantics info
                              child: Row(
                                // Use Row to place icon next to text
                                crossAxisAlignment: CrossAxisAlignment
                                    .start, // Align icon/text top
                                children: [
                                  // Conditionally display recurrence icon
                                  if (isRecurring)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 6.0,
                                          top: 2.0), // Adjust padding/alignment
                                      child: Icon(
                                        Icons.repeat,
                                        size: _kIconSizeSmall -
                                            2, // Make icon smaller
                                        color: theme.hintColor.withAlpha((255 *
                                                0.8)
                                            .round()), // Use hint color safely
                                      ),
                                    ),
                                  // Text takes remaining space
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      style:
                                          textStyle, // Apply calculated style
                                      duration: _kShortDuration,
                                      curve: Curves.easeInOut,
                                      child: Text(
                                        task.content,
                                        maxLines: 2, // Limit lines
                                        overflow: TextOverflow
                                            .ellipsis, // Handle overflow
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // *** END OF MODIFIED SECTION ***

                            // Show progress bar if subtasks exist
                            if (hasSubs && subProgress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Semantics(
                                  label:
                                      "Subtask progress: $completedSubs of $totalSubs complete",
                                  value: "${(subProgress * 100).round()}%",
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: subProgress,
                                          minHeight: 5,
                                          borderRadius:
                                              BorderRadius.circular(2.5),
                                          // Uses theme for colors
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$completedSubs/$totalSubs',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // --- Action Buttons ---
                    SizedBox(
                      // Keep fixed width for consistency
                      width: 90,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // --- Category Chip (Optional) ---
                          if (task.category != 'default')
                            Semantics(
                              label: "Task category: ${task.category}",
                              child: Container(
                                constraints: const BoxConstraints(
                                    maxWidth: 45), // Limit chip width
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  // Use theme chip colors with alpha safely
                                  color: theme.chipTheme
                                      .backgroundColor // Removed '!' and use '?.' for safety
                                      ?.withAlpha((255 * 0.7).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  task.category,
                                  // Use chip theme label style safely
                                  style: theme.chipTheme.labelStyle
                                      ?.copyWith(fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          // --- AI Button ---
                          Semantics(
                            label: "Ask AI about this task",
                            button: true,
                            enabled: !isComplete, // Disable if task complete
                            child: AnimatedOpacity(
                              duration: _kShortDuration,
                              opacity:
                                  isComplete ? 0.4 : 1.0, // Fade if disabled
                              child: IconButton(
                                icon: const Icon(Icons.psychology_alt,
                                    size: _kIconSizeSmall),
                                visualDensity:
                                    VisualDensity.compact, // Make denser
                                padding:
                                    const EdgeInsets.all(4), // Reduce padding
                                tooltip: 'Ask AI',
                                // Disable onPressed, not just visually hide
                                onPressed: isComplete
                                    ? null
                                    : () => _showAiResponseDialog(task),
                                // Use theme icon color with alpha safely
                                color: theme.iconTheme
                                    .color // Removed '!' and use '?.' for safety
                                    ?.withAlpha((255 * 0.7).round()),
                              ),
                            ),
                          ),
                          // --- Delete Button ---
                          Semantics(
                            label: "Delete task",
                            button: true,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: _kIconSizeSmall),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              tooltip: 'Delete Task',
                              // Use theme error color with alpha
                              color: theme.colorScheme.error
                                  .withAlpha((255 * 0.8).round()), // Use alpha
                              onPressed: () => _deleteTask(task.id, index),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} // End of _TaskNovaHomePageState
