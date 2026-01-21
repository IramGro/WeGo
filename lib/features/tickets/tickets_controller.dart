import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_app/core/providers.dart';
import 'package:uuid/uuid.dart';
import 'ticket_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

final ticketsControllerProvider = StateNotifierProvider<TicketsController, AsyncValue<List<Ticket>>>((ref) {
  return TicketsController(ref);
});

class TicketsController extends StateNotifier<AsyncValue<List<Ticket>>> {
  final Ref ref;
  TicketsController(this.ref) : super(const AsyncValue.loading()) {
    _loadTickets();
  }

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  Future<String?> _getTripId() async {
    final tripAsync = ref.read(currentTripStreamProvider);
    return tripAsync.value?.tripId;
  }

  Future<void> _loadTickets() async {
     // ... same persistence logic, but we need tripId ...
     // Wait, _loadTickets is called in constructor. Constructor is sync.
     // Accessing provider in constructor via Ref is OK but reading .value might be null initially.
     // However, constructor calls this async method.
     // Ideally, we should watch the trip ID changes, but StateNotifier is simpler.
     // Let's retry fetching tripId effectively.

     // Better strategy: this controller should probably react to trip changes if we want it perfect,
     // but 'loadTickets' is called once. 
     // Let's just try to get it.
     
     try {
       final user = _auth.currentUser;
       if (user == null) {
          state = const AsyncValue.data([]);
          return;
       }
       
       // Delay slightly to ensure provider might be ready? No, provider is stream.
       // Let's await the stream future.
       final tripAsync = await ref.read(currentTripStreamProvider.future);
       final tripId = tripAsync?.tripId;
       
       if (tripId == null) {
         state = const AsyncValue.data([]);
         return;
       }
       
       final snapshot = await _db
           .collection('trips')
           .doc(tripId)
           .collection('tickets')
           .where('userId', isEqualTo: user.uid)
           .orderBy('uploadedAt', descending: true)
           .get();
 
       final tickets = snapshot.docs
           .map((doc) => Ticket.fromMap(doc.id, doc.data()))
           .toList();
 
       state = AsyncValue.data(tickets);
     } catch (e, st) {
       state = AsyncValue.error(e, st);
     }
  }

  Future<void> uploadTicket({required PlatformFile file, required String title}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final tripId = await _getTripId();
      if (tripId == null) throw Exception('No trip selected');

      final fileName = '${const Uuid().v4()}_${file.name}';
      final storageRef = _storage.ref().child('trips/$tripId/tickets/$fileName');
 
      TaskSnapshot snapshot;
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('No file data found for Web');
        final metadata = SettableMetadata(contentType: 'application/pdf'); // Generic or detected
        snapshot = await storageRef.putData(file.bytes!, metadata);
      } else {
        if (file.path == null) throw Exception('No file path found');
        snapshot = await storageRef.putFile(File(file.path!));
      }

      if (snapshot.state == TaskState.success) {
        final url = await storageRef.getDownloadURL();
        String ext = fileName.split('.').last.toLowerCase();

        final newDoc = _db.collection('trips').doc(tripId).collection('tickets').doc();
        
        final ticket = Ticket(
          id: newDoc.id,
          tripId: tripId,
          title: title,
          url: url,
          fileType: ext,
          userId: user.uid,
          uploadedAt: DateTime.now(),
        );

        await newDoc.set(ticket.toMap());

        // Refresh list
        await _loadTickets();
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteTicket(Ticket ticket) async {
    try {
       // Delete from storage (try/catch in case it's gone)
       try {
         final ref = _storage.refFromURL(ticket.url);
         await ref.delete();
       } catch (_) {}

       // Delete from firestore
       await _db
           .collection('trips')
           .doc(ticket.tripId)
           .collection('tickets')
           .doc(ticket.id)
           .delete();

       await _loadTickets();
    } catch (e) {
      rethrow;
    }
  }
}
