import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/isar_db.dart';
import '../models/itinerary_day.dart';
import '../models/itinerary_item.dart';

class ItineraryRepository {
  final _fs = FirebaseFirestore.instance;

  Future<void> ensureDays({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Normalizamos a "solo fecha"
    DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
    final start = d(startDate);
    final end = d(endDate);

    if (kIsWeb) {
      // WEB: Check/Create in Firestore
      int dayNum = 1;
      final batch = _fs.batch();
      bool batchHasOps = false;

      // This is a simplified check. Ideally we read existing ones first.
      // For now, let's just query existing days to avoid overwrites or excessive reads
      final daysRef = _fs.collection('trips').doc(tripId).collection('days');
      
      // Optimization: Read all days once
      final snapshot = await daysRef.get();
      final existingDates = snapshot.docs
          .map((doc) => (doc.data()['date'] as Timestamp).toDate())
          .map((dt) => d(dt))
          .toSet();

      for (var cur = start; !cur.isAfter(end); cur = cur.add(const Duration(days: 1))) {
        if (!existingDates.contains(cur)) {
          final newDayRef = daysRef.doc();
          batch.set(newDayRef, {
            'tripId': tripId,
            'date': Timestamp.fromDate(cur),
            'dayNumber': dayNum,
          });
          batchHasOps = true;
        }
        dayNum++;
      }

      if (batchHasOps) {
        await batch.commit();
      }

    } else {
      // NATIVE: Isar
      final isar = await IsarDb.instance();
      await isar.writeTxn(() async {
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
  }

  Future<List<ItineraryDay>> listDays(String tripId) async {
    if (kIsWeb) {
      // WEB: Firestore
      final snap = await _fs
          .collection('trips')
          .doc(tripId)
          .collection('days')
          .orderBy('date')
          .get();
      
      return snap.docs.map((doc) {
        final data = doc.data();
        return ItineraryDay()
          ..tripId = tripId
          ..date = (data['date'] as Timestamp).toDate()
          ..dayNumber = data['dayNumber'] ?? 0;
          // Note: ID handling skipped for ItineraryDay as it's not usually deleted individually by ID in this UI
      }).toList();

    } else {
      // NATIVE: Isar
      final isar = await IsarDb.instance();
      return isar.itineraryDays
          .where()
          .filter()
          .tripIdEqualTo(tripId)
          .sortByDate()
          .findAll();
    }
  }

  Future<List<ItineraryItem>> listItems({
    required String tripId,
    required DateTime dayDate,
  }) async {
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);

    if (kIsWeb) {
      // WEB: Firestore
      // Storing date as Timestamp at midnight
      final snap = await _fs
          .collection('trips')
          .doc(tripId)
          .collection('items')
          .where('dayDate', isEqualTo: Timestamp.fromDate(d))
          .get();

      final items = snap.docs.map((doc) {
        final data = doc.data();
        return ItineraryItem()
          ..id = 0 // Dummy ID for Web
          ..firestoreId = doc.id
          ..tripId = tripId
          ..dayDate = d
          ..title = data['title'] ?? ''
          ..timeHHmm = data['timeHHmm']
          ..notes = data['notes']
          ..locationUrl = data['locationUrl']
          ..createdAt = (data['createdAt'] as Timestamp?)?.toDate()
          ..updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      }).toList();

      // Sort
      items.sort((a, b) {
        final ta = a.timeHHmm;
        final tb = b.timeHHmm;
        if (ta == null && tb == null) return a.title.compareTo(b.title);
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      return items;

    } else {
      // NATIVE: Isar
      final isar = await IsarDb.instance();
      final items = await isar.itineraryItems
          .filter()
          .tripIdEqualTo(tripId)
          .and()
          .dayDateEqualTo(d)
          .findAll();

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
  }

  Future<ItineraryItem> addItem({
    required String tripId,
    required DateTime dayDate,
    required String title,
    String? timeHHmm,
    String? notes,
    String? locationUrl,
  }) async {
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final now = DateTime.now();

    if (kIsWeb) {
      // WEB: Firestore
      final ref = _fs.collection('trips').doc(tripId).collection('items').doc();
      
      final cleanTime = (timeHHmm != null && timeHHmm.trim().isNotEmpty) ? timeHHmm.trim() : null;
      final cleanNotes = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null;
      final cleanUrl = (locationUrl != null && locationUrl.trim().isNotEmpty) ? locationUrl.trim() : null;

      await ref.set({
        'tripId': tripId,
        'dayDate': Timestamp.fromDate(d),
        'title': title,
        'timeHHmm': cleanTime,
        'notes': cleanNotes,
        'locationUrl': cleanUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ItineraryItem()
        ..id = 0
        ..firestoreId = ref.id
        ..tripId = tripId
        ..dayDate = d
        ..title = title
        ..timeHHmm = cleanTime
        ..notes = cleanNotes
        ..locationUrl = cleanUrl
        ..createdAt = now
        ..updatedAt = now;

    } else {
      // NATIVE: Isar
      final isar = await IsarDb.instance();
      return await isar.writeTxn(() async {
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
        return item;
      });
    }
  }

  Future<void> deleteItem(int id, {String? firestoreId, String? tripId}) async {
    if (kIsWeb) {
      if (firestoreId == null || tripId == null) return;
      // WEB: Firestore
      await _fs
          .collection('trips')
          .doc(tripId)
          .collection('items')
          .doc(firestoreId)
          .delete();
    } else {
      // NATIVE: Isar
      final isar = await IsarDb.instance();
      await isar.writeTxn(() async {
        await isar.itineraryItems.delete(id);
      });
    }
  }
}
