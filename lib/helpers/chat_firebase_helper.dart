import 'package:firebase_database/firebase_database.dart';

class ChatFirebaseHelper {
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref("chat");

  Future<void> sendMessage(Map<String, dynamic> message) async {
    final newMsg = _chatRef.push();
    await newMsg.set(message);
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    final snapshot = await _chatRef.get();

    if (snapshot.exists) {
      final messages = <Map<String, dynamic>>[];
      (snapshot.value as Map).forEach((key, value) {
        messages.add(Map<String, dynamic>.from(value));
      });
      return messages;
    } else {
      return [];
    }
  }
}
