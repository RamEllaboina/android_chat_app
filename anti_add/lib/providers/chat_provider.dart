import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';

// Provide DatabaseService instance
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Provide StorageService instance
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Stream of all users (contacts list)
final contactsProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllUsers();
});

// Stream of user chat rooms
final chatRoomsProvider = StreamProvider<List<ChatRoomModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(databaseServiceProvider).getChatRooms(user.uid);
});

// Stream of messages for a specific chat room
final messagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, roomId) {
  return ref.watch(databaseServiceProvider).getMessages(roomId);
});

// Provider for specific User details
final userDetailProvider = StreamProvider.family<UserModel, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getUserStream(userId);
});

// Modern Notifier managing messaging loading state
class ChatController extends Notifier<bool> {
  Timer? _typingTimer;

  @override
  bool build() {
    // Return initial loading state (false)
    return false;
  }

  DatabaseService get _dbService => ref.read(databaseServiceProvider);
  StorageService get _storageService => ref.read(storageServiceProvider);

  // Send textual message
  Future<void> sendTextMessage({
    required String roomId,
    required String text,
  }) async {
    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) return;

    await _dbService.sendMessage(
      roomId: roomId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName,
      text: text,
    );
  }

  // Upload and send image message
  Future<void> sendImageMessage({
    required String roomId,
    required File imageFile,
  }) async {
    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) return;

    state = true; // Set loading state to true for sending media
    try {
      final imageUrl = await _storageService.uploadChatImage(
        roomId: roomId,
        imageFile: imageFile,
      );

      await _dbService.sendMessage(
        roomId: roomId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName,
        text: '📷 Photo',
        mediaUrl: imageUrl,
        isImage: true,
      );
    } finally {
      state = false;
    }
  }

  // Set typing status with auto-timeout (stops typing status after 2 seconds)
  void setTypingStatus(String roomId, bool isTyping) {
    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) return;

    _dbService.setTypingStatus(
      roomId: roomId,
      userId: currentUser.uid,
      isTyping: isTyping,
    );

    if (isTyping) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _dbService.setTypingStatus(
          roomId: roomId,
          userId: currentUser.uid,
          isTyping: false,
        );
      });
    }
  }

  // Open Chat and Mark Messages as Read
  void enterChat(String roomId) {
    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) return;

    _dbService.markMessagesAsRead(
      roomId: roomId,
      userId: currentUser.uid,
    );
  }

  // Create group chat
  Future<String> createGroupChat({
    required String name,
    required List<String> memberIds,
    File? avatarFile,
  }) async {
    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) throw Exception('User not logged in');

    state = true;
    try {
      String? avatarUrl;
      final List<String> allMembers = [currentUser.uid, ...memberIds];
      
      final String tempRoomId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      if (avatarFile != null) {
        // Upload group image
        avatarUrl = await _storageService.uploadChatImage(
          roomId: tempRoomId,
          imageFile: avatarFile,
        );
      }

      final String roomId = await _dbService.createGroupChat(
        name: name,
        members: allMembers,
        avatarUrl: avatarUrl,
      );
      
      return roomId;
    } finally {
      state = false;
    }
  }

  void cancelTimer() {
    _typingTimer?.cancel();
  }
}

// Global Chat Controller Provider
final chatControllerProvider = NotifierProvider<ChatController, bool>(() {
  return ChatController();
});
