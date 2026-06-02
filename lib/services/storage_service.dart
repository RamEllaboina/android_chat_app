import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image message with better error handling
  Future<String> uploadImageMessage({
    required XFile image,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      // Generate unique filename
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${senderId}_$receiverId.jpg';
      final ref = _storage.ref().child('chat_images/$fileName');
      
      // Convert XFile to File
      final File file = File(image.path);
      
      // Check if file exists
      if (!await file.exists()) {
        throw Exception('Image file does not exist at path: ${image.path}');
      }
      
      // Upload file
      final uploadTask = await ref.putFile(file);
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('Upload successful! URL: $downloadUrl');
      return downloadUrl;
      
    } on FirebaseException catch (e) {
      print('Firebase error: ${e.code} - ${e.message}');
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      print('Upload error details: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
}