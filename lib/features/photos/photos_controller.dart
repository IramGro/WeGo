import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_app/data/local/local_trip_store.dart';
import 'package:uuid/uuid.dart';
import 'photo_model.dart';

final photosControllerProvider = StateNotifierProvider<PhotosController, AsyncValue<void>>((ref) {
  return PhotosController();
});

final photosStreamProvider = StreamProvider.autoDispose<List<TripPhoto>>((ref) {
  final controller = ref.watch(photosControllerProvider.notifier);
  return controller.getPhotos();
});

class PhotosController extends StateNotifier<AsyncValue<void>> {
  PhotosController() : super(const AsyncValue.data(null));

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _tripStore = LocalTripStore();
  final _uuid = const Uuid();

  Stream<List<TripPhoto>> getPhotos() async* {
    final trip = await _tripStore.getCurrentTrip();
    if (trip == null) {
      yield [];
      return;
    }

    yield* _db
        .collection('trips')
        .doc(trip.tripId)
        .collection('photos')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TripPhoto.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> uploadPhoto(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final trip = await _tripStore.getCurrentTrip();
      if (trip == null) throw Exception('No hay viaje seleccionado');

      final file = File(filePath);
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref().child('trips/${trip.tripId}/photos/$fileName');

      // Upload
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();

        final photo = TripPhoto(
          id: '',
          url: url,
          uploaderId: user.uid,
          uploaderName: user.displayName ?? 'Viajero',
          timestamp: DateTime.now(),
        );

        await _db
            .collection('trips')
            .doc(trip.tripId)
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
