// lib/dialogs/ai_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
// *** CORRECTED Import Paths ***
import '../api_service.dart'; // Use '../' to go up one level from 'dialogs' to 'lib'
// import '../task.dart'; // Not actually needed directly by AiDialogContent itself

// Enum for TTS state
enum TtsState { playing, stopped }

// Renamed StatefulWidget for AI dialog
class AiDialogContent extends StatefulWidget {
  final ApiService apiService;
  final String taskContent; // Only needs the task content string

  const AiDialogContent({
    super.key,
    required this.apiService,
    required this.taskContent,
  });

  @override
  State<AiDialogContent> createState() => _AiDialogContentState();
}

// State class for AiDialogContent
class _AiDialogContentState extends State<AiDialogContent> {
  bool _isDialogLoading = true;
  String? _aiResponse;
  String? _aiError;
  late FlutterTts flutterTts;
  bool _isTtsInitialized = false;
  TtsState _ttsState = TtsState.stopped;

  // Static constants for styling
  static const EdgeInsets _kDialogActionsPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const Duration _kMediumDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  // Helper to initialize TTS then fetch AI response
  Future<void> _initializeAndFetch() async {
    _initializeTts();
    await _fetchAiResponse();
  }

  // Initialize Text-to-Speech engine
  void _initializeTts() async {
    flutterTts = FlutterTts();
    try {
      flutterTts.setStartHandler(() {
        if (mounted) setState(() => _ttsState = TtsState.playing);
      });
      flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _ttsState = TtsState.stopped);
      });
      flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) {
          setState(() => _ttsState = TtsState.stopped);
          _showTtsErrorSnackbar(msg);
        }
      });
      await flutterTts.awaitSpeakCompletion(true);
      if (mounted) setState(() => _isTtsInitialized = true);
      debugPrint("TTS Initialized Successfully for AI Dialog");
    } catch (e) {
      debugPrint("TTS Initialization Failed (AI Dialog): $e");
      if (mounted) {
        setState(() => _isTtsInitialized = false);
        _showTtsErrorSnackbar("Could not initialize Text-to-Speech.");
      }
    }
  }

  @override
  void dispose() {
    // Stop TTS if it's running and initialized
    if (_isTtsInitialized && _ttsState == TtsState.playing) {
      flutterTts.stop().catchError((e) {
        debugPrint("Error stopping TTS during AI dialog dispose: $e");
      });
    }
    super.dispose();
  }

  // Fetch the AI response from the backend
  Future<void> _fetchAiResponse() async {
    if (!mounted) return;
    // Stop ongoing speech before fetching again
    if (_isTtsInitialized && _ttsState == TtsState.playing) {
      try {
        await flutterTts.stop();
      } catch (e) {
        debugPrint("Error stopping TTS before AI fetch: $e");
      }
    }
    setState(() {
      _isDialogLoading = true;
      _aiError = null;
      _aiResponse = null;
      _ttsState = TtsState.stopped; // Reset visual state
    });
    try {
      final result = await widget.apiService.askAI(widget.taskContent);
      if (mounted) {
        setState(() {
          _aiResponse = result;
          _isDialogLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e
              .toString()
              .replaceFirst("Exception: ", ""); // Clean error message
          _isDialogLoading = false;
        });
      }
    }
  }

  // Handle starting/stopping speech
  Future<void> _speak(String text) async {
    if (!_isTtsInitialized || text.isEmpty || !mounted) {
      if (!_isTtsInitialized && mounted) {
        _showTtsErrorSnackbar("Text-to-Speech is not available.");
      }
      return;
    }

    if (_ttsState == TtsState.playing) {
      await _stopSpeaking();
    } else {
      try {
        await flutterTts.speak(text); // Let handlers update state
      } catch (e) {
        debugPrint("TTS speak error: $e");
        _showTtsErrorSnackbar("Could not start speaking.");
        if (mounted) setState(() => _ttsState = TtsState.stopped);
      }
    }
  }

  // Handle stopping speech explicitly
  Future<void> _stopSpeaking() async {
    if (!_isTtsInitialized || !mounted || _ttsState == TtsState.stopped) return;
    try {
      await flutterTts.stop(); // Let handler update state
    } catch (e) {
      debugPrint("TTS stop error: $e");
      _showTtsErrorSnackbar("Failed to stop speaking.");
      if (mounted) {
        setState(
            () => _ttsState = TtsState.stopped); // Force stop state if error
      }
    }
  }

  // Show TTS-specific errors
  void _showTtsErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("TTS Error: $message"),
        backgroundColor: Colors.orange[800]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canAttemptSpeak = _isTtsInitialized &&
        !_isDialogLoading &&
        _aiResponse != null &&
        _aiResponse!.isNotEmpty;
    final bool isSpeaking = _ttsState == TtsState.playing;

    return AlertDialog(
      title: const Text('AI Insights'),
      content: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          // Use ConstrainedBox instead of Container for constraints
          constraints: const BoxConstraints(
              minHeight: 100, minWidth: 280, maxWidth: 400),
          child: AnimatedSwitcher(
            duration: _kMediumDuration,
            child: _isDialogLoading
                ? _keyCenteredProgress()
                : _aiError != null
                    ? _keyCenteredError(theme, _aiError)
                    : _keyCenteredResponse(theme, _aiResponse),
          ),
        ),
      ),
      actions: <Widget>[
        if (canAttemptSpeak)
          IconButton(
            icon: Icon(isSpeaking
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline),
            tooltip: isSpeaking ? 'Stop Reading' : 'Read Aloud',
            color: isSpeaking
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            iconSize: 28,
            onPressed: () => _speak(_aiResponse!), // Pass response directly
          ),
        if (_aiError != null)
          TextButton(
              onPressed: _fetchAiResponse, child: const Text('Retry AI')),
        const Spacer(),
        TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop()),
      ],
      actionsPadding: _kDialogActionsPadding,
    );
  }

  // --- Reusable helper widgets ---
  Widget _keyCenteredProgress() => const Center(
      key: ValueKey('ai_loading'), child: CircularProgressIndicator());

  Widget _keyCenteredError(ThemeData theme, String? errorMsg) => Center(
      key: const ValueKey('ai_error'),
      child: _buildDialogErrorContent(theme, errorMsg));

  Widget _keyCenteredResponse(ThemeData theme, String? response) => Padding(
        key: const ValueKey('ai_response'),
        padding: const EdgeInsets.symmetric(
            vertical: 8.0, horizontal: 8.0), // Add horizontal padding too
        child: SelectableText(response ?? 'No insights available.',
            style: theme.dialogTheme.contentTextStyle,
            textAlign: TextAlign.start // Left-align AI response usually better
            ),
      );

  Widget _buildDialogErrorContent(ThemeData theme, String? errorMsg) => Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Oops! ${errorMsg ?? 'An unknown error occurred'}',
                  style:
                      (theme.dialogTheme.contentTextStyle ?? const TextStyle())
                          .copyWith(
                              color: theme.colorScheme.error
                                  .withAlpha((255 * 0.9).round())), // Use alpha
                  textAlign: TextAlign.center),
            )
          ]);
}


// **** DELETE any definition of TaskDetailDialog from this file ****