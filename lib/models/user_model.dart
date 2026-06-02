import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePic,
    required this.isOnline,
    required this.lastSeen,
    required this.createdAt,
  });

  // Convert from Firestore document
factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
  return UserModel(
    uid: docId,
    name: map['name'] ?? '',
    email: map['email'] ?? '',
    profilePic: map['profilePic'] ?? '',
    isOnline: map['isOnline'] ?? false,
    lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': createdAt,
    };
  }

  // Copy with updated values
  UserModel copyWith({
    String? name,
    String? email,
    String? profilePic,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePic: profilePic ?? this.profilePic,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}