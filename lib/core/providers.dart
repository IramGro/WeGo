import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/local/local_trip_store.dart';
import '../data/models/local_trip.dart';
import '../data/local/isar_db.dart';
import '../data/repositories/trip_repository.dart';

// Global tab index for bottom navigation
final tabIndexProvider = StateProvider<int>((ref) => 0);

final tripRepositoryProvider = Provider((ref) => TripRepository());

// Stream of the current trip
// On Mobile: From Isar (Offline-first)
// On Web: From Firestore (Online-only)
final currentTripStreamProvider = StreamProvider<LocalTrip?>((ref) async* {
  if (kIsWeb) {
    // 1. WEB STRATEGY: Fetch from Firestore
    final repo = ref.read(tripRepositoryProvider);
    final trips = await repo.getUserTrips();
    
    if (trips.isEmpty) {
      yield null;
    } else {
      final tripId = trips.first['id'];
      
      yield* FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (data == null) return null;
            
            final t = LocalTrip()
              ..tripId = tripId
              ..name = data['name'] ?? ''
              ..code = data['code'] ?? '';
              
            if (data['startDate'] != null) {
              t.startDate = (data['startDate'] as Timestamp).toDate();
            }
            if (data['endDate'] != null) {
              t.endDate = (data['endDate'] as Timestamp).toDate();
            }
            if (data['destination'] != null) {
              t.destination = data['destination'];
            }
            if (data['useGeolocation'] != null) {
              t.useGeolocation = data['useGeolocation'];
            }
            
            return t;
          });
    }
  } else {
    // 2. MOBILE STRATEGY: Isar
    final isar = await IsarDb.instance();
    yield* isar.localTrips.where().watch(fireImmediately: true).map((list) {
      return list.isEmpty ? null : list.first;
    });
  }
});
