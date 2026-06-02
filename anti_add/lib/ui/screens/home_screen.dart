import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/chat_room_model.dart';
import 'chat_room_screen.dart';
import 'create_group_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwiftChat'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.grey[600],
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline_rounded), text: 'Chats'),
            Tab(icon: Icon(Icons.people_outline_rounded), text: 'Contacts'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsTab(),
          ContactsTab(),
          SettingsTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          // Only show floating action button on Chats tab
          return _tabController.index == 0
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                    );
                  },
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.group_add_outlined),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}

// ------------------- CHATS TAB -------------------
class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final currentUser = ref.watch(currentUserModelProvider).value;

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return chatRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No active conversations', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rooms.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return ChatRoomTile(room: room, currentUserId: currentUser.uid);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading chats: $err')),
    );
  }
}

class ChatRoomTile extends ConsumerWidget {
  final ChatRoomModel room;
  final String currentUserId;

  const ChatRoomTile({super.key, required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (room.isGroup) {
      // Group Room UI
      // Check if anyone else in group is typing
      final typingMembers = room.typingUsers.entries
          .where((e) => e.key != currentUserId && e.value)
          .map((e) => e.key)
          .toList();
      final isTyping = typingMembers.isNotEmpty;

      return ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
          backgroundImage: room.groupAvatarUrl != null ? NetworkImage(room.groupAvatarUrl!) : null,
          child: room.groupAvatarUrl == null
              ? Icon(Icons.group, color: theme.colorScheme.secondary)
              : null,
        ),
        title: Text(room.name ?? 'Group Chat', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: isTyping
            ? Text(
                'someone is typing...',
                style: TextStyle(color: theme.colorScheme.primary, fontStyle: FontStyle.italic),
              )
            : Text(
                '${room.recentSender.isNotEmpty ? "${room.recentSender}: " : ""}${room.recentMessage}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
        trailing: Text(
          DateFormat('h:mm a').format(room.recentTimestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        onTap: () {
          ref.read(chatControllerProvider.notifier).enterChat(room.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                roomId: room.id,
                roomName: room.name ?? 'Group Chat',
                isGroup: true,
              ),
            ),
          );
        },
      );
    } else {
      // 1-to-1 Chat Room UI
      // Locate the partner user ID
      final partnerId = room.members.firstWhere((id) => id != currentUserId);
      final partnerAsync = ref.watch(userDetailProvider(partnerId));

      return partnerAsync.when(
        data: (partner) {
          final isTyping = room.typingUsers[partnerId] == true;

          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: partner.photoUrl != null ? NetworkImage(partner.photoUrl!) : null,
                  child: partner.photoUrl == null
                      ? Text(
                          partner.displayName.isNotEmpty ? partner.displayName[0].toUpperCase() : '?',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 18),
                        )
                      : null,
                ),
                if (partner.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(partner.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: isTyping
                ? Text(
                    'typing...',
                    style: TextStyle(color: theme.colorScheme.primary, fontStyle: FontStyle.italic),
                  )
                : Text(
                    room.recentMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
            trailing: Text(
              DateFormat('h:mm a').format(room.recentTimestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            onTap: () {
              ref.read(chatControllerProvider.notifier).enterChat(room.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatRoomScreen(
                    roomId: room.id,
                    roomName: partner.displayName,
                    isGroup: false,
                    partnerId: partnerId,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const ListTile(title: Text('Loading...')),
        error: (err, stack) => const ListTile(title: Text('Failed to load user info')),
      );
    }
  }
}

// ------------------- CONTACTS TAB -------------------
class ContactsTab extends ConsumerWidget {
  const ContactsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final currentUser = ref.watch(currentUserModelProvider).value;

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return contactsAsync.when(
      data: (users) {
        // Exclude current user from list
        final filteredUsers = users.where((u) => u.uid != currentUser.uid).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Text('No contacts found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          );
        }

        final theme = Theme.of(context);
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredUsers.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null
                        ? Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                          )
                        : null,
                  ),
                  if (user.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(user.isOnline ? 'Online' : 'Offline', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              onTap: () async {
                // Initialize room Deterministically
                final chatController = ref.read(chatControllerProvider.notifier);
                final dbService = ref.read(databaseServiceProvider);
                
                final roomId = await dbService.getOrCreateOneToOneChat(currentUser.uid, user.uid);
                chatController.enterChat(roomId);

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        roomId: roomId,
                        roomName: user.displayName,
                        isGroup: false,
                        partnerId: user.uid,
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading contacts: $err')),
    );
  }
}

// ------------------- SETTINGS TAB -------------------
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final currentUser = ref.watch(currentUserModelProvider).value;

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // User Profile Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: currentUser.photoUrl != null ? NetworkImage(currentUser.photoUrl!) : null,
                  child: currentUser.photoUrl == null
                      ? Text(
                          currentUser.displayName.isNotEmpty ? currentUser.displayName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.displayName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditNameDialog(context, ref, currentUser.displayName),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Settings Toggles
        const Text(
          'Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: themeMode == ThemeMode.dark,
                onChanged: (val) {
                  ref.read(themeProvider.notifier).toggleTheme(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Session Actions
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () {
            ref.read(authControllerProvider.notifier).logout();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final user = ref.read(firebaseUserProvider);
                if (user != null) {
                  await user.updateDisplayName(controller.text.trim());
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'displayName': controller.text.trim()});
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
