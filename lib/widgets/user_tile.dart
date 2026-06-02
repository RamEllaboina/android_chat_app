import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import '../screens/call/call_screen.dart';

class UserTile extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onTap;
  final bool showFriendButton;
  final String currentUserId;
  final String currentUserName;

  const UserTile({
    Key? key,
    required this.user,
    this.onTap,
    this.showFriendButton = true,
    required this.currentUserId,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  final FriendService _friendService = FriendService();
  String _requestStatus = 'checking';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
  }

  Future<void> _checkRequestStatus() async {
    final status = await _friendService.getFriendRequestStatus(widget.user.uid);
    if (mounted) {
      setState(() {
        _requestStatus = status ?? 'not_friends';
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() => _isLoading = true);
    try {
      await _friendService.sendFriendRequest(widget.user.uid);
      if (mounted) {
        setState(() {
          _requestStatus = 'request_sent';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCall(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          receiverId: widget.user.uid,
          receiverName: widget.user.name,
          receiverImage: widget.user.profilePic,
          callType: type,
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildFriendButton() {
    if (!widget.showFriendButton) return const SizedBox.shrink();
    
    switch (_requestStatus) {
      case 'friends':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Friends ✓',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      
      case 'request_sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Pending ⌛',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      
      case 'request_received':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Respond 📨',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      
      default:
        return SizedBox(
          width: 70,
          height: 32,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendFriendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Add +',
                    style: TextStyle(fontSize: 12),
                  ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: widget.user.profilePic.isNotEmpty
            ? NetworkImage(widget.user.profilePic)
            : null,
        child: widget.user.profilePic.isEmpty
            ? const Icon(Icons.person, size: 28)
            : null,
      ),
      title: Text(
        widget.user.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.user.email,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Call buttons (only show for friends)
          if (_requestStatus == 'friends') ...[
            // Video Call Button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.videocam, color: Color(0xFF4CAF50), size: 20),
                onPressed: () => _startCall('video'),
                tooltip: 'Video Call',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Audio Call Button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.call, color: Color(0xFF4CAF50), size: 20),
                onPressed: () => _startCall('audio'),
                tooltip: 'Audio Call',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Online status indicator
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.user.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              if (!widget.user.isOnline)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatLastSeen(widget.user.lastSeen),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Friend button
          _buildFriendButton(),
        ],
      ),
      onTap: widget.onTap,
    );
  }
}