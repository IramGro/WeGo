
class Ticket {
  final String id;
  final String tripId;
  final String title;
  final String url;
  final String fileType; // 'pdf', 'doc', etc.
  final String userId;
  final DateTime uploadedAt;

  Ticket({
    required this.id,
    required this.tripId,
    required this.title,
    required this.url,
    required this.fileType,
    required this.userId,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'title': title,
      'url': url,
      'fileType': fileType,
      'userId': userId,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory Ticket.fromMap(String id, Map<String, dynamic> map) {
    return Ticket(
      id: id,
      tripId: map['tripId'] ?? '',
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      fileType: map['fileType'] ?? 'unknown',
      userId: map['userId'] ?? '',
      uploadedAt: DateTime.tryParse(map['uploadedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
