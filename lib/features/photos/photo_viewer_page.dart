import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'photo_model.dart';

class PhotoViewerPage extends StatelessWidget {
  final TripPhoto photo;

  const PhotoViewerPage({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM HH:mm', 'es_MX').format(photo.timestamp);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(photo.uploaderName, style: const TextStyle(fontSize: 16)),
             Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: photo.url,
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
