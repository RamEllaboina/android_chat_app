import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _usersCollection => _firestore.collection('users');

  // Save/Update user data after login
  Future<void> saveUserData(User user) async {
    try {
      final userDoc = _usersCollection.doc(user.uid);
      final docSnapshot = await userDoc.get();

      final Map<String, dynamic> userData = {
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'profilePic': user.photoURL ?? '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': docSnapshot.exists
            ? (docSnapshot.data() as Map<String, dynamic>)['createdAt']
            : FieldValue.serverTimestamp(),
      };

      await userDoc.set(userData, SetOptions(merge: true));
      print('✅ User saved: ${user.uid}');
    } catch (e) {
      print('❌ Error saving user: $e');
    }
  }

  // Get current user data stream
  Stream<UserModel?> getCurrentUserStream() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _usersCollection.doc(currentUser.uid).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return UserModel.fromMap(data, doc.id);
        }
      }
      return null;
    }).handleError((error) {
      print('❌ Error getting current user: $error');
      return null;
    });
  }

  // Get all users except current user
  Stream<List<UserModel>> getAllUsers() {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    
    if (currentUserId.isEmpty) {
      return Stream.value([]);
    }
    
    return _usersCollection.snapshots().map((snapshot) {
      final List<UserModel> users = [];
      for (var doc in snapshot.docs) {
        if (doc.id != currentUserId) {
          final data = doc.data() as Map<String, dynamic>;
          users.add(UserModel.fromMap(data, doc.id));
        }
      }
      return users;
    }).handleError((error) {
      print('❌ Error getting all users: $error');
      return <UserModel>[];
    });
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return UserModel.fromMap(data, doc.id);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting user by ID: $e');
      return null;
    }
  }

  // Update user online status
  Future<void> updateUserOnlineStatus(bool isOnline) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _usersCollection.doc(currentUser.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating online status: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? profilePic,
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final Map<String, dynamic> updateData = {};
    if (name != null) updateData['name'] = name;
    if (profilePic != null) updateData['profilePic'] = profilePic;

    if (updateData.isNotEmpty) {
      try {
        await _usersCollection.doc(currentUser.uid).update(updateData);
      } catch (e) {
        print('❌ Error updating profile: $e');
      }
    }
  }
}