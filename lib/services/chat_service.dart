import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate unique chat room ID
  String generateChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  // Get messages collection reference
  CollectionReference getMessagesCollection(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages');
  }

  // Send text message
  Future<void> sendTextMessage({
    required String receiverId,
    required String message,
  }) async {
    final currentUserId = _auth.currentUser!.uid;
    final chatRoomId = generateChatRoomId(currentUserId, receiverId);

    await getMessagesCollection(chatRoomId).add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': message,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
    });
    
    print('✅ Message sent to $receiverId');
  }

  // Send image message
  Future<void> sendImageMessage({
    required String receiverId,
    required String imageUrl,
  }) async {
    final currentUserId = _auth.currentUser!.uid;
    final chatRoomId = generateChatRoomId(currentUserId, receiverId);

    await getMessagesCollection(chatRoomId).add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': imageUrl,
      'type': 'image',
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
    });
    
    print('✅ Image sent to $receiverId');
  }

  // Get messages stream (realtime)
  Stream<List<MessageModel>> getMessages(String receiverId) {
    final currentUserId = _auth.currentUser!.uid;
    final chatRoomId = generateChatRoomId(currentUserId, receiverId);

    return getMessagesCollection(chatRoomId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MessageModel.fromMap(data, doc.id);
      }).toList();
    }).handleError((error) {
      print('❌ Error getting messages: $error');
      return <MessageModel>[];
    });
  }

  // Mark all messages as seen
  Future<void> markAllMessagesAsSeen(String receiverId) async {
    final currentUserId = _auth.currentUser!.uid;
    final chatRoomId = generateChatRoomId(currentUserId, receiverId);

    try {
      final unreadMessages = await getMessagesCollection(chatRoomId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isSeen', isEqualTo: false)
          .get();

      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isSeen': true});
      }
      
      print('✅ Marked ${unreadMessages.docs.length} messages as seen');
    } catch (e) {
      print('❌ Error marking messages as seen: $e');
    }
  }

  // Get unread messages count
  Stream<int> getUnreadMessagesCount(String senderId) {
    final currentUserId = _auth.currentUser!.uid;
    final chatRoomId = generateChatRoomId(currentUserId, senderId);

    return getMessagesCollection(chatRoomId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isSeen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
          print('❌ Error getting unread count: $error');
          return 0;
        });
  }
}