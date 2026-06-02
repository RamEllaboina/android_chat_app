import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgoraService {
  // 👇 REPLACE WITH YOUR AGORA APP ID 👇
  static const String appId = '885006e695cf4abf97c03df2cd488f6a';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Generate unique channel name for two users
  String generateChannelName(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return 'call_${ids.join('_')}';
  }

  // Create call record in Firestore
  Future<void> createCallRecord({
    required String receiverId,
    required String callType, // 'video' or 'audio'
  }) async {
    final currentUserId = _auth.currentUser!.uid;
    final channelName = generateChannelName(currentUserId, receiverId);

    await _firestore.collection('calls').doc(channelName).set({
      'callerId': currentUserId,
      'receiverId': receiverId,
      'callType': callType,
      'status': 'initiated',
      'startTime': FieldValue.serverTimestamp(),
      'duration': 0,
    });
  }

  // Update call status
  Future<void> updateCallStatus({
    required String channelName,
    required String status,
    int? duration,
  }) async {
    final updateData = {
      'status': status,
      'endTime': FieldValue.serverTimestamp(),
    };
    
    if (duration != null) {
      updateData['duration'] = duration;
    }

    await _firestore.collection('calls').doc(channelName).update(updateData);
  }

  // Get call history
  Stream<List<QueryDocumentSnapshot>> getCallHistory() {
    final currentUserId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('calls')
        .where('callerId', isEqualTo: currentUserId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
}