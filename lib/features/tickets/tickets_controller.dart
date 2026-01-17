import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'ticket_model.dart';
import '../../data/local/local_trip_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

final ticketsControllerProvider = StateNotifierProvider<TicketsController, AsyncValue<List<Ticket>>>((ref) {
  return TicketsController();
});

class TicketsController extends StateNotifier<AsyncValue<List<Ticket>>> {
  TicketsController() : super(const AsyncValue.loading()) {
    _loadTickets();
  }

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _tripStore = LocalTripStore();
  final _auth = FirebaseAuth.instance;

  Future<void> _loadTickets() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
         state = const AsyncValue.data([]);
         return;
      }
      
      final trip = await _tripStore.getCurrentTrip();
      if (trip == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      final snapshot = await _db
          .collection('trips')
          .doc(trip.tripId)
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

  Future<void> uploadTicket({required String filePath, required String title}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final trip = await _tripStore.getCurrentTrip();
      if (trip == null) throw Exception('No trip selected');

      final file = File(filePath);
      // ... upload logic ...
      
      final fileName = '${const Uuid().v4()}_${file.uri.pathSegments.last}';
      final ref = _storage.ref().child('trips/${trip.tripId}/tickets/$fileName');
 
      // Upload file
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        String ext = fileName.split('.').last.toLowerCase();

        final newDoc = _db.collection('trips').doc(trip.tripId).collection('tickets').doc();
        
        final ticket = Ticket(
          id: newDoc.id,
          tripId: trip.tripId,
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
      // Handle error, maybe rethrow so UI handles it
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
