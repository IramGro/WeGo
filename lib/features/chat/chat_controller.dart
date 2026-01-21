import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_app/data/local/local_trip_store.dart';
import 'package:trip_app/core/providers.dart';
import 'chat_model.dart';

final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  return ChatController(ref);
});

final chatStreamProvider = StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  final controller = ref.watch(chatControllerProvider.notifier);
  return controller.getMessages();
});

class ChatController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  ChatController(this.ref) : super(const AsyncValue.data(null));

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // final _tripStore = LocalTripStore(); // We use provider now

  Future<String?> _getTripId() async {
    // Prefer the reactive provider which handles both Web (Firestore) and Mobile (Isar)
    final tripAsync = ref.read(currentTripStreamProvider);
    return tripAsync.value?.tripId;
  }

  Stream<List<ChatMessage>> getMessages() async* {
    final tripId = await _getTripId();
    if (tripId == null) {
      yield [];
      return;
    }

    yield* _db
        .collection('trips')
        .doc(tripId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> sendMessage(String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tripId = await _getTripId();
    if (tripId == null) return;

    if (text.trim().isEmpty) return;

    final message = ChatMessage(
      id: '', // Firestore gen
      text: text.trim(),
      senderId: user.uid,
      senderName: user.displayName ?? 'Viajero',
      senderPhoto: user.photoURL ?? '',
      timestamp: DateTime.now(),
    );

    await _db
        .collection('trips')
        .doc(tripId)
        .collection('messages')
        .add(message.toMap());
  }

  Future<void> sendPoll(String question, List<String> options) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tripId = await _getTripId();
    if (tripId == null) return;

    if (question.trim().isEmpty || options.length < 2) return;

    final message = ChatMessage(
      id: '',
      text: question.trim(),
      senderId: user.uid,
      senderName: user.displayName ?? 'Viajero',
      senderPhoto: user.photoURL ?? '',
      timestamp: DateTime.now(),
      type: 'poll',
      pollOptions: options,
      votes: {for (var i = 0; i < options.length; i++) i.toString(): []},
    );

    await _db
        .collection('trips')
        .doc(tripId)
        .collection('messages')
        .add(message.toMap());
  }

  Future<void> vote(String messageId, int optionIndex) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tripId = await _getTripId();
    if (tripId == null) return;

    final docRef = _db
        .collection('trips')
        .doc(tripId)
        .collection('messages')
        .doc(messageId);

    // In a real app we'd use a transaction to remove previous votes
    // For simplicity, we'll fetch and update
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final votes = Map<String, dynamic>.from(data['votes'] ?? {});
    
    // Remove user from all options
    votes.forEach((key, value) {
      (value as List).remove(user.uid);
    });

    // Add user to selected option
    final key = optionIndex.toString();
    votes[key] = [...(votes[key] as List? ?? []), user.uid];

    await docRef.update({'votes': votes});
  }
}
