import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send friend request
  Future<void> sendFriendRequest(String receiverId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    // Check if already friends
    final isFriend = await checkIfFriends(currentUserId, receiverId);
    if (isFriend) {
      throw Exception('Already friends');
    }
    
    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }
    
    // Check if request already received
    final receivedRequest = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: receiverId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
        
    if (receivedRequest.docs.isNotEmpty) {
      throw Exception('You already have a pending request from this user');
    }

    // Send new request
    await _firestore.collection('friend_requests').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    print('✅ Friend request sent from $currentUserId to $receiverId');
  }

  // Get incoming friend requests
  Stream<List<FriendRequestModel>> getIncomingRequests() {
    final currentUserId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FriendRequestModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get outgoing friend requests
  Stream<List<FriendRequestModel>> getOutgoingRequests() {
    final currentUserId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FriendRequestModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Accept friend request - FIXED: Properly add both sides
  Future<void> acceptRequest(String requestId, String senderId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    print('📱 Accepting request from $senderId to $currentUserId');
    
    // Add to current user's friends collection
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(senderId)
        .set({
      'uid': senderId,
      'addedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Added $senderId to $currentUserId friends');
    
    // Add to sender's friends collection
    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('friends')
        .doc(currentUserId)
        .set({
      'uid': currentUserId,
      'addedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Added $currentUserId to $senderId friends');

    // Delete the request
    await _firestore.collection('friend_requests').doc(requestId).delete();
    
    print('✅ Friend request deleted');
  }

  // Reject friend request
  Future<void> rejectRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
    print('✅ Friend request rejected');
  }

  // Remove friend
  Future<void> removeFriend(String friendId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    // Remove from current user's friends
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId)
        .delete();
    
    // Remove from friend's collection
    await _firestore
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(currentUserId)
        .delete();
    
    print('✅ Removed friend: $friendId');
  }

  // Get friends list for current user
  Stream<List<UserModel>> getFriendsList() {
    final currentUserId = _auth.currentUser!.uid;
    
    print('🔄 Getting friends list for: $currentUserId');
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .asyncMap((friendsSnapshot) async {
      List<UserModel> friends = [];
      
      print('📊 Found ${friendsSnapshot.docs.length} friend documents');
      
      for (var friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.id;
        final userDoc = await _firestore.collection('users').doc(friendId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          friends.add(UserModel.fromMap(userData, friendId));
          print('✅ Added friend: ${userData['name']}');
        } else {
          print('⚠️ User $friendId not found');
        }
      }
      
      print('🎉 Total friends: ${friends.length}');
      return friends;
    }).handleError((error) {
      print('❌ Error getting friends: $error');
      return <UserModel>[];
    });
  }

  // Check if two users are friends
  Future<bool> checkIfFriends(String userId1, String userId2) async {
    try {
      final check = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('friends')
          .doc(userId2)
          .get();
      
      return check.exists;
    } catch (e) {
      print('❌ Error checking friends: $e');
      return false;
    }
  }

  // Get friend request status
  Future<String?> getFriendRequestStatus(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    try {
      // Check if already friends
      final isFriend = await checkIfFriends(currentUserId, otherUserId);
      if (isFriend) return 'friends';
      
      // Check for pending request from current user
      final sentRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: otherUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (sentRequest.docs.isNotEmpty) return 'request_sent';
      
      // Check for pending request to current user
      final receivedRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (receivedRequest.docs.isNotEmpty) return 'request_received';
      
      return 'not_friends';
    } catch (e) {
      print('❌ Error getting status: $e');
      return 'not_friends';
    }
  }
}

// Friend Request Model
class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime timestamp;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.timestamp,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return FriendRequestModel(
      id: docId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}