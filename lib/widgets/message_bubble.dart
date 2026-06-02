import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../screens/media/fullscreen_image.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        padding: _getPadding(),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: _getBorderRadius(),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMessageContent(context),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.getFormattedTime(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                if (isMe)
                  Icon(
                    message.isSeen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isSeen
                        ? Colors.blueAccent
                        : Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _getPadding() {
    if (message.type == MessageType.image) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  }

  Color _getBackgroundColor() {
    if (message.type == MessageType.image) {
      return Colors.transparent;
    }
    return isMe ? const Color(0xFF4CAF50) : Colors.grey[300]!;
  }

  BorderRadius _getBorderRadius() {
    if (message.type == MessageType.image) {
      return BorderRadius.circular(16);
    }
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.white : Colors.black87,
          ),
        );

      case MessageType.image:
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullscreenImage(
                  imageUrl: message.message,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              message.message,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 220,
                  height: 220,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Image load error: $error');
                print('Image URL: ${message.message}');
                return Container(
                  width: 220,
                  height: 220,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 40, color: Colors.red),
                        SizedBox(height: 8),
                        Text('Failed to load image'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );

      case MessageType.video:
        return Container(
          width: 200,
          height: 150,
          color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('Video message'),
              ],
            ),
          ),
        );

      case MessageType.audio:
        return Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.music_note, color: isMe ? Colors.white : Colors.black87),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Voice message'),
              ),
              const Icon(Icons.play_arrow),
            ],
          ),
        );
    }
  }
}