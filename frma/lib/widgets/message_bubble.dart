// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard and HapticFeedback
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart'; // To access providers

import '../models/message.dart'; // The data model for a message
import '../providers/settings_provider.dart'; // For reading font size, primary color
import '../providers/theme_provider.dart'; // For checking dark mode

/// A widget that displays a single chat message in a styled bubble.
/// Aligns to the right for user messages and left for assistant messages.
class MessageBubble extends StatelessWidget {
  final Message message; // The message data to display

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access necessary providers for styling
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    // Determine bubble color based on sender and theme
    final bubbleColor = message.isUser
        ? (settingsProvider.primaryColor.withOpacity(
            isDark ? 0.7 : 0.2)) // User message color uses primary theme color
        : (isDark
            ? Colors.grey.shade800
            : Colors.grey.shade200); // Assistant message color

    final textColor =
        isDark ? Colors.white : Colors.black; // Basic text color based on theme
    final formattedTime =
        _formatTime(message.timestamp); // Format timestamp for display

    return Align(
      // Align bubble left/right based on sender
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Allow copying message text on long press
        onLongPress: () {
          HapticFeedback.lightImpact(); // Subtle vibration feedback
          _copyToClipboard(context);
        },
        child: Container(
          // Limit bubble width to 75% of screen width
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                // Subtle shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            // Bubble content: message text and timestamp
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Align text to start
              children: [
                // Use SelectableText to allow user selection/copying naturally too
                SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: settingsProvider
                        .fontSize, // Use font size from settings
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Display formatted time below the message text
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6), // Dimmed timestamp color
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Copies the message text to the clipboard.
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        behavior:
            SnackBarBehavior.floating, // Make it float above bottom nav bar
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Formats the message timestamp for display (e.g., "9:30 AM" or "Apr 24, 9:30 AM").
  String _formatTime(DateTime messageTime) {
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    // If the message is not from today, show date and time.
    if (difference.inDays > 0 || now.day != messageTime.day) {
      return DateFormat('MMM d, h:mm a')
          .format(messageTime); // e.g., Apr 24, 9:30 AM
    } else {
      // If the message is from today, just show the time.
      return DateFormat('h:mm a').format(messageTime); // e.g., 9:30 AM
    }
  }
}
