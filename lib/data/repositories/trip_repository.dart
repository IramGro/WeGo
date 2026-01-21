import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../local/local_trip_store.dart';

class TripRepository {
  TripRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
    LocalTripStore? localStore,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid(),
        _local = localStore ?? LocalTripStore();

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;
  final Uuid _uuid;
  final LocalTripStore _local;

  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<void> _addToUserTrips(String uid, String tripId, String name, String code) async {
    await _fs.collection('users').doc(uid).collection('trips').doc(tripId).set({
      'name': name,
      'code': code,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getUserTrips() async {
    await ensureSignedIn();
    final uid = _auth.currentUser!.uid;
    
    final snap = await _fs
        .collection('users')
        .doc(uid)
        .collection('trips')
        .orderBy('joinedAt', descending: true)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': data['name'] ?? 'Viaje',
        'code': data['code'] ?? '',
      };
    }).toList();
  }

  Future<({String tripId, String code})> createTrip({required String name}) async {
    await ensureSignedIn();

    final uid = _auth.currentUser!.uid;
    final tripId = _uuid.v4();
    final code = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();

    await _fs.collection('trips').doc(tripId).set({
      'name': name,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    });

    await _fs.collection('trips').doc(tripId).collection('members').doc(uid).set({
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Guardar referencia en el usuario
    await _addToUserTrips(uid, tripId, name, code);

    // Guardar local (offline) solo si NO es web
    if (!kIsWeb) {
      await selectTrip(tripId: tripId, name: name, code: code);
    }

    return (tripId: tripId, code: code);
  }

  Future<void> selectTrip({required String tripId, required String name, required String code}) async {
      // En Web, no usamos almacenamiento local Isar.
      if (kIsWeb) return; 

      await _local.saveTrip(tripId: tripId, name: name, code: code);
      
      // Sincronizar fechas desde Firestore si existen
      final snap = await _fs.collection('trips').doc(tripId).get();
      final data = snap.data();
      if (data != null && data['startDate'] != null && data['endDate'] != null) {
        await _local.setTripDates(
          startDate: (data['startDate'] as Timestamp).toDate(),
          endDate: (data['endDate'] as Timestamp).toDate(),
        );
      }
      if (data != null) {
        await _local.setTripLocation(
          destination: data['destination'] as String?,
          useGeolocation: (data['useGeolocation'] as bool?) ?? false,
        );
      }
  }

  Future<void> updateTripLocation({
    required String tripId,
    String? destination,
    required bool useGeolocation,
  }) async {
    await _fs.collection('trips').doc(tripId).update({
      'destination': destination,
      'useGeolocation': useGeolocation,
    });
    
    if (!kIsWeb) {
      await _local.setTripLocation(destination: destination, useGeolocation: useGeolocation);
    }
  }

  Future<void> updateTripDates({required String tripId, required DateTime startDate, required DateTime endDate}) async {
    // Save to Firestore
    await _fs.collection('trips').doc(tripId).update({
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    });

    // Save locally
    if (!kIsWeb) {
      await _local.setTripDates(startDate: startDate, endDate: endDate);
    }
  }

  Future<({String tripId, String name, String code})> joinTripByCode({required String code}) async {
    await ensureSignedIn();

    final uid = _auth.currentUser!.uid;
    final normalized = code.trim().toUpperCase();

    final snap = await _fs
        .collection('trips')
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No existe un viaje con ese código.');
    }

    final doc = snap.docs.first;
    final data = doc.data();
    final name = (data['name'] as String?) ?? 'Trip';
    final storedCode = (data['code'] as String?) ?? normalized;

    await _fs.collection('trips').doc(doc.id).collection('members').doc(uid).set({
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Guardar referencia en el usuario
    await _addToUserTrips(uid, doc.id, name, storedCode);

    // Guardar local (offline)
    if (!kIsWeb) {
      await selectTrip(tripId: doc.id, name: name, code: storedCode);
    }

    return (tripId: doc.id, name: name, code: storedCode);
  }
}
