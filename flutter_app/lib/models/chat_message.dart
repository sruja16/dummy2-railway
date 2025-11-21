// lib/models/chat_message.dart
import 'package:flutter/foundation.dart';

enum Sender { user, bot, system }

class ChatMessage {
  final String id;
  final Sender sender;
  final String text;
  final DateTime createdAt;
  final bool isTyping; // used for typing indicator

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    DateTime? createdAt,
    this.isTyping = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': describeEnum(sender),
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'isTyping': isTyping,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final s = j['sender'] as String? ?? 'user';
    return ChatMessage(
      id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: Sender.values.firstWhere((e) => describeEnum(e) == s, orElse: () => Sender.user),
      text: j['text'] ?? '',
      createdAt:
          j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
      isTyping: j['isTyping'] == true,
    );
  }
}
