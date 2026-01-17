import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderPhoto;
  final DateTime timestamp;
  final String type; // 'text', 'image', 'poll'
  final List<String>? pollOptions;
  final Map<String, dynamic>? votes; // { '0': [uids] }

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderPhoto,
    required this.timestamp,
    this.type = 'text',
    this.pollOptions,
    this.votes,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'pollOptions': pollOptions,
      'votes': votes,
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Usuario',
      senderPhoto: map['senderPhoto'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? 'text',
      pollOptions: (map['pollOptions'] as List?)?.map((e) => e.toString()).toList(),
      votes: map['votes'] != null ? Map<String, dynamic>.from(map['votes']) : null,
    );
  }
}
