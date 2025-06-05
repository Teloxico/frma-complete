// lib/models/message.dart
import 'dart:convert';

/// Represents a single chat message in the conversation.
class Message {
  final String text;
  final bool
      isUser; // True if the message is from the user, false if from the assistant.
  final DateTime timestamp; // Time the message was created.

  Message({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ??
            DateTime.now(); // Default to current time if not provided.

  /// Converts this Message object into a JSON map for storage or transmission.
  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp':
            timestamp.toIso8601String(), // Use standard ISO format for dates.
      };

  /// Creates a Message object from a JSON map.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['text'] as String? ??
          '', // Provide default value if 'text' is missing.
      isUser: json['isUser'] as bool? ??
          false, // Provide default value if 'isUser' is missing.
      // Parse timestamp from ISO string, defaulting to now() if missing or invalid.
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
