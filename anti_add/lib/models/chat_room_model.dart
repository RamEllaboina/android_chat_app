import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String? name;
  final bool isGroup;
  final List<String> members;
  final String recentMessage;
  final String recentSender;
  final DateTime recentTimestamp;
  final Map<String, bool> typingUsers;
  final String? groupAvatarUrl;

  ChatRoomModel({
    required this.id,
    this.name,
    required this.isGroup,
    required this.members,
    required this.recentMessage,
    required this.recentSender,
    required this.recentTimestamp,
    required this.typingUsers,
    this.groupAvatarUrl,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map) {
    // Safely parse dynamic map to Map<String, bool>
    final dynamic typingRaw = map['typingUsers'];
    final Map<String, bool> typingParsed = {};
    if (typingRaw is Map) {
      typingRaw.forEach((key, value) {
        typingParsed[key.toString()] = value == true;
      });
    }

    return ChatRoomModel(
      id: map['id'] ?? '',
      name: map['name'],
      isGroup: map['isGroup'] ?? false,
      members: List<String>.from(map['members'] ?? []),
      recentMessage: map['recentMessage'] ?? '',
      recentSender: map['recentSender'] ?? '',
      recentTimestamp: map['recentTimestamp'] != null
          ? (map['recentTimestamp'] as Timestamp).toDate()
          : DateTime.now(),
      typingUsers: typingParsed,
      groupAvatarUrl: map['groupAvatarUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isGroup': isGroup,
      'members': members,
      'recentMessage': recentMessage,
      'recentSender': recentSender,
      'recentTimestamp': Timestamp.fromDate(recentTimestamp),
      'typingUsers': typingUsers,
      'groupAvatarUrl': groupAvatarUrl,
    };
  }

  ChatRoomModel copyWith({
    String? id,
    String? name,
    bool? isGroup,
    List<String>? members,
    String? recentMessage,
    String? recentSender,
    DateTime? recentTimestamp,
    Map<String, bool>? typingUsers,
    String? groupAvatarUrl,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      members: members ?? this.members,
      recentMessage: recentMessage ?? this.recentMessage,
      recentSender: recentSender ?? this.recentSender,
      recentTimestamp: recentTimestamp ?? this.recentTimestamp,
      typingUsers: typingUsers ?? this.typingUsers,
      groupAvatarUrl: groupAvatarUrl ?? this.groupAvatarUrl,
    );
  }
}
