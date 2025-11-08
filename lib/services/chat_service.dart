// // firebase_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dash_chat_2/dash_chat_2.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class ChatFirebaseService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final User user = FirebaseAuth.instance.currentUser!;

//   Future<List<ChatMessage>> loadMessages() async {
//     try {
//       final querySnapshot = await _firestore
//           .collection('chats')
//           .doc(user.uid)
//           .collection('messages')
//           .orderBy('createdAt', descending: true)
//           .get();

//       return querySnapshot.docs.map((doc) {
//         final data = doc.data();
//         return ChatMessage(
//           text: data['text'],
//           user: ChatUser(
//             id: data['userId'],
//             firstName: data['userFirstName'],
//           ),
//           createdAt: (data['createdAt'] as Timestamp).toDate(),
//         );
//       }).toList();
//     } catch (e) {
//       throw Exception('Error loading messages: $e');
//     }
//   }

//   Future<void> saveMessage(ChatMessage message) async {
//     try {
//       await _firestore
//           .collection('chats')
//           .doc(user.uid)
//           .collection('messages')
//           .add({
//         'text': message.text,
//         'userId': message.user.id,
//         'userFirstName': message.user.firstName,
//         'createdAt': Timestamp.fromDate(message.createdAt),
//       });
//     } catch (e) {
//       throw Exception('Error saving message: $e');
//     }
//   }

//   Future<void> clearWholeChat() async {
//     try {
//       final messagesSnapshot = await _firestore
//           .collection('chats')
//           .doc(user.uid)
//           .collection('messages')
//           .get();

//       for (var doc in messagesSnapshot.docs) {
//         await doc.reference.delete();
//       }
//     } catch (e) {
//       throw Exception('Error deleting chat: $e');
//     }
//   }
// }


import 'package:dash_chat_2/dash_chat_2.dart';

class ChatMemoryService {
  // In-memory list to store messages during the session
  List<ChatMessage> _messages = [];

  // Get all messages
  List<ChatMessage> getMessages() {
    return _messages;
  }

  // Add a new message
  void addMessage(ChatMessage message) {
    _messages.add(message);
  }

  // Clear all messages
  void clearChat() {
    _messages.clear();
  }
}