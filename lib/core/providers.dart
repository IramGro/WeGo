import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Get the list of trips for the current user
    // We'll just take the most recent one to "simulate" the current selection
    // Or we could persist the selected trip ID in SharedPrefs if needed.
    // For now, let's stream the "most recent" trip found in userData.
    final trips = await repo.getUserTrips();
    if (trips.isEmpty) {
      yield null;
    } else {
      // Convert the Firestore (Map) data into a LocalTrip object for the UI
      final first = trips.first; 
      yield LocalTrip()
        ..tripId = first['id']
        ..name = first['name']
        ..code = first['code'];
    }
  } else {
    // 2. MOBILE STRATEGY: Isar
    final isar = await IsarDb.instance();
    yield* isar.localTrips.where().watch(fireImmediately: true).map((list) {
      return list.isEmpty ? null : list.first;
    });
  }
});
