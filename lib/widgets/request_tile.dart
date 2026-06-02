import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';

class RequestTile extends StatefulWidget {
  final UserModel user;
  final String requestId;
  final VoidCallback? onAccept;

  const RequestTile({
    Key? key,
    required this.user,
    required this.requestId,
    this.onAccept,
  }) : super(key: key);

  @override
  State<RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  final FriendService _friendService = FriendService();
  bool _isProcessing = false;

  Future<void> _acceptRequest() async {
    setState(() => _isProcessing = true);
    
    try {
      await _friendService.acceptRequest(widget.requestId, widget.user.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Call the onAccept callback to refresh
        widget.onAccept?.call();
        
        // Close the dialog/screen if needed
        // Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectRequest() async {
    setState(() => _isProcessing = true);
    
    try {
      await _friendService.rejectRequest(widget.requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
      ),
      subtitle: Text(
        widget.user.email,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
      trailing: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                  onPressed: _acceptRequest,
                  tooltip: 'Accept',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                  onPressed: _rejectRequest,
                  tooltip: 'Reject',
                ),
              ],
            ),
    );
  }
}