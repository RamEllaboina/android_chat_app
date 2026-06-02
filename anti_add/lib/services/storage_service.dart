import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Upload an image for a chat message and return its download URL
  Future<String> uploadChatImage({
    required String roomId,
    required File imageFile,
  }) async {
    try {
      final String fileId = _uuid.v4();
      final Reference ref = _storage
          .ref()
          .child('chats')
          .child(roomId)
          .child('images')
          .child('$fileId.jpg');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload an avatar for a user profile
  Future<String> uploadProfileAvatar({
    required String userId,
    required File avatarFile,
  }) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('profile_avatar.jpg');

      final UploadTask uploadTask = ref.putFile(avatarFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Support Web upload using bytes (conditional upload)
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    try {
      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putData(bytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload data bytes: $e');
    }
  }
}
