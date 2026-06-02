import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/friend_service.dart';
import '../chat/chat_screen.dart';
import '../call/call_screen.dart';

class FriendProfileScreen extends StatelessWidget {
  final UserModel friend;
  final UserModel currentUser;

  const FriendProfileScreen({
    Key? key,
    required this.friend,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(friend.name),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // Profile Image
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundImage: friend.profilePic.isNotEmpty
                  ? NetworkImage(friend.profilePic)
                  : null,
              child: friend.profilePic.isEmpty
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            friend.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Email
          Text(
            friend.email,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          // Online Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: friend.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                friend.isOnline ? 'Online' : 'Offline',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Chat Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverUser: friend,
                          currentUser: currentUser,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Send Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Video Call Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CallScreen(
                          receiverId: friend.uid,
                          receiverName: friend.name,
                          receiverImage: friend.profilePic,
                          callType: 'video',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Audio Call Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CallScreen(
                          receiverId: friend.uid,
                          receiverName: friend.name,
                          receiverImage: friend.profilePic,
                          callType: 'audio',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Audio Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Remove Friend Button
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _showRemoveFriendDialog(context),
                    icon: const Icon(Icons.person_remove, color: Colors.red),
                    label: const Text(
                      'Remove Friend',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove ${friend.name} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final friendService = FriendService();
              await friendService.removeFriend(friend.uid);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Friend removed'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}