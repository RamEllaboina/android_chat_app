import 'package:flutter/material.dart';
import '../../../services/friend_service.dart';
import '../../../services/firestore_service.dart';
import '../../../models/user_model.dart';
import '../../../widgets/request_tile.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final FriendService _friendService = FriendService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, UserModel> _usersCache = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friend Requests'),
          backgroundColor: const Color(0xFF4CAF50),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Received requests
            StreamBuilder(
              stream: _friendService.getIncomingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  );
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No pending requests'),
                      ],
                    ),
                  );
                }

                return FutureBuilder(
                  future: _getUsersForRequests(requests),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final sender = _usersCache[request.senderId];
                        
                        if (sender == null) return const SizedBox.shrink();
                        
                        return RequestTile(
                          user: sender,
                          requestId: request.id,
                          onAccept: () {
                            // Refresh after accept
                            setState(() {});
                            // Refresh the friends list in home screen
                            _refreshHomeScreen();
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            
            // Sent requests (same as before)
            StreamBuilder(
              stream: _friendService.getOutgoingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  );
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No sent requests'),
                      ],
                    ),
                  );
                }

                return FutureBuilder(
                  future: _getUsersForRequests(requests),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final receiver = _usersCache[request.receiverId];
                        
                        if (receiver == null) return const SizedBox.shrink();
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: receiver.profilePic.isNotEmpty
                                ? NetworkImage(receiver.profilePic)
                                : null,
                            child: receiver.profilePic.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(receiver.name),
                          subtitle: Text(receiver.email),
                          trailing: const Chip(
                            label: Text('Pending'),
                            backgroundColor: Colors.orange,
                            labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refreshHomeScreen() {
    // Force refresh the home screen friends list
    // This will trigger a rebuild of the home screen
  }

  Future<void> _getUsersForRequests(List requests) async {
    for (var request in requests) {
      final senderId = request.senderId;
      final receiverId = request.receiverId;
      
      if (!_usersCache.containsKey(senderId)) {
        final user = await _firestoreService.getUserById(senderId);
        if (user != null) {
          _usersCache[senderId] = user;
        }
      }
      
      if (!_usersCache.containsKey(receiverId)) {
        final user = await _firestoreService.getUserById(receiverId);
        if (user != null) {
          _usersCache[receiverId] = user;
        }
      }
    }
  }
}