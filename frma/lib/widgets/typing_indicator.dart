// lib/widgets/typing_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

/// A widget that displays an animated typing indicator (dots)
/// optionally with a message like "Assistant is typing...".
class TypingIndicator extends StatefulWidget {
  /// Optional message to display next to the dots. Defaults to "Assistant is typing".
  final String? customMessage;

  const TypingIndicator({
    Key? key,
    this.customMessage,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  // Animation controller for the pulsing dots effect.
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, // Required for animations
      duration:
          const Duration(milliseconds: 1500), // Duration of one animation cycle
    )..repeat(); // Make the animation loop continuously
  }

  @override
  void dispose() {
    _controller.dispose(); // Clean up the controller when the widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme and settings info from providers
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final backgroundColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final message = widget.customMessage ??
        'Assistant is typing'; // Use default message if none provided

    return Align(
      alignment: Alignment
          .centerLeft, // Align indicator to the left (like assistant message)
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Row takes minimum space needed
          children: [
            // Container for the animated dots
            Container(
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                // Generate 3 dots
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Stagger the animation for each dot using a delay
                      final double delay = index * 0.2;
                      // Calculate the current value (0.0 to 1.0) for this dot's animation cycle
                      final double value = (_controller.value + delay) % 1.0;
                      // Animate size and opacity based on the value
                      final double size =
                          4.0 + (value * 4.0); // Grows from 4.0 to 8.0
                      final double opacity =
                          0.3 + (value * 0.7); // Fades from 0.3 to 1.0

                      // Apply opacity and render the dot
                      return Opacity(
                        opacity: opacity.clamp(
                            0.3, 1.0), // Clamp opacity just in case
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: settingsProvider
                                .primaryColor, // Use theme color
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),

            // Display the message next to the dots if provided
            if (message.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
