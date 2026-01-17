import 'package:isar/isar.dart';

import '../local/isar_db.dart';
import '../models/itinerary_day.dart';
import '../models/itinerary_item.dart';

class ItineraryRepository {
  Future<void> ensureDays({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final isar = await IsarDb.instance();

    // Normalizamos a "solo fecha"
    DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);

    final start = d(startDate);
    final end = d(endDate);

    await isar.writeTxn(() async {
      // Crea los days faltantes (si ya existen, no duplica)
      int dayNum = 1;
      for (var cur = start; !cur.isAfter(end); cur = cur.add(const Duration(days: 1))) {
        final exists = await isar.itineraryDays
            .filter()
            .tripIdEqualTo(tripId)
            .and()
            .dateEqualTo(cur)
            .findFirst();

        if (exists == null) {
          final day = ItineraryDay()
            ..tripId = tripId
            ..date = cur
            ..dayNumber = dayNum;
          await isar.itineraryDays.put(day);
        }
        dayNum++;
      }
    });
  }

  Future<List<ItineraryDay>> listDays(String tripId) async {
    final isar = await IsarDb.instance();
    return isar.itineraryDays
        .where()
        .filter()
        .tripIdEqualTo(tripId)
        .sortByDate()
        .findAll();
  }

  Future<List<ItineraryItem>> listItems({
    required String tripId,
    required DateTime dayDate,
  }) async {
    final isar = await IsarDb.instance();
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);

    final items = await isar.itineraryItems
        .filter()
        .tripIdEqualTo(tripId)
        .and()
        .dayDateEqualTo(d)
        .findAll();

    // Orden simple: primero los que tienen hora (asc), luego sin hora
    items.sort((a, b) {
      final ta = a.timeHHmm;
      final tb = b.timeHHmm;
      if (ta == null && tb == null) return a.title.compareTo(b.title);
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });

    return items;
  }

  Future<void> addItem({
    required String tripId,
    required DateTime dayDate,
    required String title,
    String? timeHHmm,
    String? notes,
    String? locationUrl,
  }) async {
    final isar = await IsarDb.instance();
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);

    await isar.writeTxn(() async {
      final now = DateTime.now();
      final item = ItineraryItem()
        ..tripId = tripId
        ..dayDate = d
        ..title = title
        ..timeHHmm = (timeHHmm != null && timeHHmm.trim().isNotEmpty) ? timeHHmm.trim() : null
        ..notes = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null
        ..locationUrl = (locationUrl != null && locationUrl.trim().isNotEmpty) ? locationUrl.trim() : null
        ..createdAt = now
        ..updatedAt = now;

      await isar.itineraryItems.put(item);
    });
  }

  Future<void> deleteItem(int id) async {
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.itineraryItems.delete(id);
    });
  }
}
