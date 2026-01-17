import 'package:cloud_firestore/cloud_firestore.dart';

class TripPhoto {
  final String id;
  final String url;
  final String uploaderId;
  final String uploaderName;
  final DateTime timestamp;

  TripPhoto({
    required this.id,
    required this.url,
    required this.uploaderId,
    required this.uploaderName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory TripPhoto.fromMap(String id, Map<String, dynamic> map) {
    return TripPhoto(
      id: id,
      url: map['url'] ?? '',
      uploaderId: map['uploaderId'] ?? '',
      uploaderName: map['uploaderName'] ?? 'Viajero',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
