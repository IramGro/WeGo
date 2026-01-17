import 'package:isar/isar.dart';

import '../models/local_trip.dart';
import 'isar_db.dart';

class LocalTripStore {
  Future<void> saveTrip({
    required String tripId,
    required String name,
    required String code,
  }) async {
    final isar = await IsarDb.instance();

    await isar.writeTxn(() async {
      await isar.localTrips.clear();

      final t = LocalTrip()
        ..tripId = tripId
        ..name = name
        ..code = code
        ..joinedAt = DateTime.now();

      await isar.localTrips.put(t);
    });
  }

  Future<LocalTrip?> getCurrentTrip() async {
    final isar = await IsarDb.instance();
    final list = await isar.localTrips.where().findAll();
    return list.isEmpty ? null : list.first;
  }

  Future<void> setTripDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final isar = await IsarDb.instance();

    await isar.writeTxn(() async {
      final list = await isar.localTrips.where().findAll();
      if (list.isEmpty) return;

      final t = list.first;
      t.startDate = startDate;
      t.endDate = endDate;
      await isar.localTrips.put(t);
    });
  }

  Future<void> setTripLocation({
    String? destination,
    required bool useGeolocation,
  }) async {
    final isar = await IsarDb.instance();

    await isar.writeTxn(() async {
      final list = await isar.localTrips.where().findAll();
      if (list.isEmpty) return;

      final t = list.first;
      t.destination = destination;
      t.useGeolocation = useGeolocation;
      await isar.localTrips.put(t);
    });
  }

  Future<void> clear() async {
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async => isar.localTrips.clear());
  }
}
