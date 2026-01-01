class ChatConversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type; // 'private', 'group'
  final DateTime? lastMessageAt;
  
  // UI helper: to show name/avatar of the "other" person
  // in a private chat, or group name.
  final String? participantName;
  final String? participantAvatarUrl;
  final String? lastMessageContent;
  final bool? isLastMessageRead;
  final String? lastMessageSenderId;

  ChatConversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.type = 'private',
    this.lastMessageAt,
    this.participantName,
    this.participantAvatarUrl,
    this.lastMessageContent,
    this.isLastMessageRead,
    this.lastMessageSenderId,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      type: json['type'] ?? 'private',
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.parse(json['last_message_at']) 
          : null,
      // Provide defaults or parsing if these fields come from a joined query
      participantName: json['participant_name'],
      participantAvatarUrl: json['participant_avatar_url'],
      lastMessageContent: json['last_message_content'],
      isLastMessageRead: json['is_last_message_read'],
      lastMessageSenderId: json['last_message_sender_id'],

    );
  }
}
