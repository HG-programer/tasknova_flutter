// lib/dialogs/motivation_dialog.dart

import 'package:flutter/material.dart';
import '../api_service.dart'; // Adjust path if your api_service.dart is elsewhere

// Constants from main.dart (if needed, or define locally)
const Duration _kMediumDuration = Duration(milliseconds: 300);
const EdgeInsets _kDialogActionsPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 8);

// *** Ensure the class name is EXACTLY this and PUBLIC (no underscore) ***
class MotivationDialogContent extends StatefulWidget {
  final ApiService apiService;

  // *** Ensure the constructor takes 'apiService' and uses super.key ***
  const MotivationDialogContent(
      {required this.apiService,
      super.key // It's good practice to include the key
      });

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
    // Ensure mounted check is still valid before async calls
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _motivationalQuote = null; // Clear previous quote on retry
    });
    try {
      final quote = await widget.apiService.getMotivation();
      if (mounted) {
        // Check mounted again after await
        setState(() {
          _motivationalQuote = quote;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Check mounted again after await (in catch)
        setState(() {
          _error = e
              .toString()
              .replaceFirst("Exception: ", ""); // Clean error message
          _isLoading = false;
        });
      }
    }
  }

// Inside the build method of _MotivationDialogContentState in lib/dialogs/motivation_dialog.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Motivation'),
      content: Container(
        constraints:
            const BoxConstraints(minHeight: 80, minWidth: 250, maxWidth: 400),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: _kMediumDuration,
          child: _isLoading
              ? _keyCenteredProgress()
              : _error != null
                  ? _keyCenteredError(theme, _error)
                  : _keyCenteredQuote(theme, _motivationalQuote),
        ),
      ),
      // *** CORRECTED ACTIONS ***
      actions: <Widget>[
        if (_error != null)
          TextButton(
            // Show Retry button if there's an error
            onPressed: _fetchMotivationalQuote,
            child: const Text('Retry'),
          ),
        // Use MainAxisAlignment in actionsAlignment to space out instead of Spacer
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              Text(_error != null ? 'Close' : 'Got it!'), // Dynamic button text
        ),
      ],
      // Control alignment here - this pushes buttons apart if 'Retry' is present
      actionsAlignment: _error != null
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      actionsPadding: _kDialogActionsPadding,
    );
  }

// ... rest of the helper methods (_keyCenteredProgress, etc.) remain the same ...

  /* Reusable Helper Widgets with Keys */
  Widget _keyCenteredProgress() => const Center(
      key: ValueKey('loading'), // Key for AnimatedSwitcher
      child: CircularProgressIndicator());

  Widget _keyCenteredError(ThemeData theme, String? errorMsg) => Center(
      key: const ValueKey('error'), // Key for AnimatedSwitcher
      child: _buildDialogErrorContent(theme, errorMsg));

  Widget _keyCenteredQuote(ThemeData theme, String? quote) => Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 8.0), // Add padding to text
        key: const ValueKey('quote'), // Key for AnimatedSwitcher
        child: SelectableText(
          // Make quote selectable
          quote ?? 'Keep pushing!',
          textAlign: TextAlign.center,
          // Use a slightly more prominent style
          style: theme.textTheme.titleMedium
              ?.copyWith(fontStyle: FontStyle.italic, height: 1.4 // Line height
                  ),
        ),
      );

  // Common error display widget
  Widget _buildDialogErrorContent(ThemeData theme, String? errorMsg) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_very_dissatisfied, // More fitting icon?
              color: theme.colorScheme.error
                  .withAlpha((255 * 0.8).round()), // Use alpha
              size: 40),
          const SizedBox(height: 12),
          Padding(
            // Add padding to error text
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Oops! ${errorMsg ?? 'Failed to get motivation'}',
                style: (theme.textTheme.bodyMedium ?? const TextStyle())
                    .copyWith(
                        color: theme.colorScheme.error
                            .withAlpha((255 * 0.9).round())), // Use alpha
                textAlign: TextAlign.center),
          )
        ]);
  }
}
