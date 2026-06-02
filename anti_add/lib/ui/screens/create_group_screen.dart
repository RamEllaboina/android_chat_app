import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import 'chat_room_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<String> _selectedMemberIds = [];
  
  File? _avatarFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );
      if (pickedFile != null) {
        setState(() {
          _avatarFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 member'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      final chatController = ref.read(chatControllerProvider.notifier);
      
      final roomId = await chatController.createGroupChat(
        name: _nameController.text.trim(),
        memberIds: _selectedMemberIds,
        avatarFile: _avatarFile,
      );

      if (mounted) {
        // Go back and replace/push into the ChatRoom
        Navigator.pop(context); // close create group screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              roomId: roomId,
              roomName: _nameController.text.trim(),
              isGroup: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final isCreating = ref.watch(chatControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          IconButton(
            icon: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Icon(Icons.done),
            onPressed: isCreating ? null : _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Group Info Config
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.grey[200],
                      backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                      child: _avatarFile == null
                          ? Icon(Icons.camera_alt_outlined, color: isDark ? Colors.white60 : Colors.grey[600])
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Subject',
                        hintText: 'Enter group subject...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a group subject';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Sub-header for contacts list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SELECT MEMBERS (${_selectedMemberIds.length})',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),

            // Contacts List selection
            Expanded(
              child: contactsAsync.when(
                data: (users) {
                  // Exclude me
                  final me = ref.watch(firebaseUserProvider);
                  final filteredUsers = users.where((u) => u.uid != me?.uid).toList();

                  if (filteredUsers.isEmpty) {
                    return const Center(child: Text('No contacts found'));
                  }

                  return ListView.separated(
                    itemCount: filteredUsers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _selectedMemberIds.contains(user.uid);

                      return CheckboxListTile(
                        value: isSelected,
                        secondary: CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                              : null,
                        ),
                        title: Text(user.displayName),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedMemberIds.add(user.uid);
                            } else {
                              _selectedMemberIds.remove(user.uid);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Failed to load contacts: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
