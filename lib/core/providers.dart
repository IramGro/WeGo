import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/local_trip_store.dart';
import '../data/models/local_trip.dart';
import '../data/local/isar_db.dart';
// import 'package:isar/isar.dart';

// Global tab index for bottom navigation
final tabIndexProvider = StateProvider<int>((ref) => 0);

// Stream of the current trip from Isar for real-time UI updates
final currentTripStreamProvider = StreamProvider<LocalTrip?>((ref) async* {
  final isar = await IsarDb.instance();
  // Watch the collection and yield the first element (current trip)
  yield* isar.localTrips.where().watch(fireImmediately: true).map((list) {
    return list.isEmpty ? null : list.first;
  });
});
