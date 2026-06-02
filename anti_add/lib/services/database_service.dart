import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of all users (for starting a chat)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Stream of a specific user's status
  Stream<UserModel> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!);
      }
      throw Exception('User not found');
    });
  }

  // Stream of chat rooms for the current user
  Stream<List<ChatRoomModel>> getChatRooms(String currentUserId) {
    return _firestore
        .collection('chat_rooms')
        .where('members', arrayContains: currentUserId)
        .orderBy('recentTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Stream of messages in a room
  Stream<List<MessageModel>> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Get or Create 1-to-1 Chat Room
  Future<String> getOrCreateOneToOneChat(String user1, String user2) async {
    // Determine deterministic ID to avoid duplicates
    final List<String> sortedIds = [user1, user2]..sort();
    final String roomId = '${sortedIds[0]}_${sortedIds[1]}';

    final DocumentSnapshot doc =
        await _firestore.collection('chat_rooms').doc(roomId).get();

    if (!doc.exists) {
      final ChatRoomModel newRoom = ChatRoomModel(
        id: roomId,
        isGroup: false,
        members: [user1, user2],
        recentMessage: 'No messages yet',
        recentSender: '',
        recentTimestamp: DateTime.now(),
        typingUsers: {user1: false, user2: false},
      );

      await _firestore.collection('chat_rooms').doc(roomId).set(newRoom.toMap());
    }

    return roomId;
  }

  // Create Group Chat Room
  Future<String> createGroupChat({
    required String name,
    required List<String> members,
    String? avatarUrl,
  }) async {
    final String roomId = _firestore.collection('chat_rooms').doc().id;

    final Map<String, bool> typingMap = {};
    for (var member in members) {
      typingMap[member] = false;
    }

    final ChatRoomModel newRoom = ChatRoomModel(
      id: roomId,
      name: name,
      isGroup: true,
      members: members,
      recentMessage: 'Group created',
      recentSender: '',
      recentTimestamp: DateTime.now(),
      typingUsers: typingMap,
      groupAvatarUrl: avatarUrl,
    );

    await _firestore.collection('chat_rooms').doc(roomId).set(newRoom.toMap());
    return roomId;
  }

  // Send Message
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
    String? mediaUrl,
    bool isImage = false,
  }) async {
    final String messageId = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc()
        .id;

    final MessageModel newMessage = MessageModel(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      readBy: [senderId], // Sender has read it by default
      isImage: isImage,
    );

    // Save message in subcollection
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .set(newMessage.toMap());

    // Update parent ChatRoom info
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'recentMessage': isImage ? '📷 Photo' : text,
      'recentSender': senderName,
      'recentTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update typing indicator status
  Future<void> setTypingStatus({
    required String roomId,
    required String userId,
    required bool isTyping,
  }) async {
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'typingUsers.$userId': isTyping,
    });
  }

  // Mark all messages in room as read (add user to readBy)
  Future<void> markMessagesAsRead({
    required String roomId,
    required String userId,
  }) async {
    final QuerySnapshot unreadSnapshot = await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        // Note: In Firestore, we can filter client-side or build query since readBy doesn't contain userId
        .get();

    final WriteBatch batch = _firestore.batch();
    bool hasUpdates = false;

    for (var doc in unreadSnapshot.docs) {
      final List<dynamic> readBy = doc.get('readBy') ?? [];
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  // Update presence status (onResume / onPause hooks)
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
