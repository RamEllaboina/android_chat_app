import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final String? partnerId;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.isGroup,
    this.partnerId,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Mark room messages as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).enterChat(widget.roomId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty) {
      ref.read(chatControllerProvider.notifier).setTypingStatus(widget.roomId, true);
    } else {
      ref.read(chatControllerProvider.notifier).setTypingStatus(widget.roomId, false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    // Stop typing status
    ref.read(chatControllerProvider.notifier).setTypingStatus(widget.roomId, false);
    
    await ref.read(chatControllerProvider.notifier).sendTextMessage(
          roomId: widget.roomId,
          text: text,
        );
  }

  Future<void> _sendImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final chatNotifier = ref.read(chatControllerProvider.notifier);
        await chatNotifier.sendImageMessage(
          roomId: widget.roomId,
          imageFile: File(pickedFile.path),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final currentFirebaseUser = ref.watch(firebaseUserProvider);
    final messagesAsync = ref.watch(messagesProvider(widget.roomId));
    
    // Check if uploading image
    final isUploading = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildAppBarTitle(theme),
      ),
      body: Column(
        children: [
          // Message stream board list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        const Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Whenever message list loads, trigger a read receipts sync
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(chatControllerProvider.notifier).enterChat(widget.roomId);
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentFirebaseUser?.uid;

                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      isGroup: widget.isGroup,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading messages: $err')),
            ),
          ),

          // Uploading media overlay indicator
          if (isUploading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: theme.scaffoldBackgroundColor.withOpacity(0.9),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading media file...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // Typing listener overlay
          _buildTypingIndicatorRow(theme),

          // Message send input bar
          _buildInputBar(theme, isDark),
        ],
      ),
    );
  }

  // Build top App Bar title area with custom user status details
  Widget _buildAppBarTitle(ThemeData theme) {
    if (widget.isGroup) {
      return Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            child: Icon(Icons.group, size: 20, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Text(widget.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );
    } else {
      final partnerId = widget.partnerId!;
      final partnerAsync = ref.watch(userDetailProvider(partnerId));

      return partnerAsync.when(
        data: (partner) {
          final presenceText = partner.isOnline
              ? 'Online'
              : 'Last seen ${DateFormat('h:mm a').format(partner.lastSeen)}';

          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                backgroundImage: partner.photoUrl != null ? NetworkImage(partner.photoUrl!) : null,
                child: partner.photoUrl == null
                    ? Text(partner.displayName.isNotEmpty ? partner.displayName[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(partner.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    presenceText,
                    style: TextStyle(
                      fontSize: 11,
                      color: partner.isOnline ? Colors.green : Colors.grey[500],
                      fontWeight: partner.isOnline ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => Text(widget.roomName, style: const TextStyle(fontSize: 16)),
        error: (_, __) => Text(widget.roomName, style: const TextStyle(fontSize: 16)),
      );
    }
  }

  // Real-time typing indicators feed
  Widget _buildTypingIndicatorRow(ThemeData theme) {
    if (widget.isGroup) {
      // Listen to room dynamic changes
      // To get real-time room typing status, we query the chat_rooms document stream
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const SizedBox.shrink();

          final typingRaw = data['typingUsers'] as Map?;
          if (typingRaw == null) return const SizedBox.shrink();

          final me = ref.watch(firebaseUserProvider);

          // We lookup displays of currently typing IDs
          // For simplicity, we print "Someone is typing..."
          bool anyoneElseTyping = false;
          typingRaw.forEach((key, val) {
            if (key != me?.uid && val == true) {
              anyoneElseTyping = true;
            }
          });

          if (!anyoneElseTyping) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const TypingIndicator(dotSize: 5),
                const SizedBox(width: 8),
                Text(
                  'Someone is typing...',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // 1-to-1 Chat: listen directly to partner typing flag inside room document
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const SizedBox.shrink();

          final typingUsers = data['typingUsers'] as Map?;
          final isTyping = typingUsers?[widget.partnerId] == true;

          if (!isTyping) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const TypingIndicator(dotSize: 5),
                const SizedBox(width: 8),
                Text(
                  '${widget.roomName} is typing...',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // Build bottom text entry bar layout
  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0F14) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[950]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Media attachment button
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary),
              onPressed: _sendImage,
            ),
            const SizedBox(width: 8),

            // Message text input
            Expanded(
              child: TextFormField(
                controller: _messageController,
                onChanged: _onTextChanged,
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF15181F) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Action Send Button
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
