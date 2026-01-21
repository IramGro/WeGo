import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_app/core/providers.dart'; // Import provider
import 'package:uuid/uuid.dart';
import 'photo_model.dart';
import 'package:image_picker/image_picker.dart'; // XFile

final photosControllerProvider = StateNotifierProvider<PhotosController, AsyncValue<void>>((ref) {
  return PhotosController(ref);
});

final photosStreamProvider = StreamProvider.autoDispose<List<TripPhoto>>((ref) {
  final controller = ref.watch(photosControllerProvider.notifier);
  return controller.getPhotos();
});

class PhotosController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  PhotosController(this.ref) : super(const AsyncValue.data(null));

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  Future<String?> _getTripId() async {
     final tripAsync = ref.read(currentTripStreamProvider);
     return tripAsync.value?.tripId;
  }

  Stream<List<TripPhoto>> getPhotos() async* {
    final tripId = await _getTripId();
    if (tripId == null) {
      yield [];
      return;
    }

    yield* _db
        .collection('trips')
        .doc(tripId)
        .collection('photos')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TripPhoto.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> uploadPhoto(XFile file) async {
    state = const AsyncValue.loading();
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final tripId = await _getTripId();
      if (tripId == null) throw Exception('No hay viaje seleccionado');

      final fileName = '${_uuid.v4()}.jpg';
      final storageRef = _storage.ref().child('trips/$tripId/photos/$fileName');

      TaskSnapshot snapshot;
      if (kIsWeb) {
        // Web: Upload bytes
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        snapshot = await storageRef.putData(bytes, metadata);
      } else {
        // Mobile: Upload file
        final ioFile = File(file.path);
        snapshot = await storageRef.putFile(ioFile);
      }
      
      if (snapshot.state == TaskState.success) {
        final url = await storageRef.getDownloadURL();

        final photo = TripPhoto(
          id: '',
          url: url,
          uploaderId: user.uid,
          uploaderName: user.displayName ?? 'Viajero',
          timestamp: DateTime.now(),
        );

        await _db
            .collection('trips')
            .doc(tripId)
            .collection('photos')
            .add(photo.toMap());
        
        state = const AsyncValue.data(null);
      } else {
        throw Exception('Error subiendo imagen');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
