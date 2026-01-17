import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> firestoreSmokeTest() async {
  await FirebaseFirestore.instance.collection('smoke').add({
    'ok': true,
    'ts': FieldValue.serverTimestamp(),
  });
}
