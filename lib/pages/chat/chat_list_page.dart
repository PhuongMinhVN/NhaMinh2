import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chat_conversation.dart';
import '../../repositories/chat_repository.dart';
import 'chat_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _chatRepository = ChatRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tin Nhắn',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.brown.shade800,
      ),
      body: StreamBuilder<List<ChatConversation>>(
        stream: _chatRepository.getConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!;
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có cuộc trò chuyện nào',
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy vào Cây Phả Hệ và chọn người thân để nhắn tin',
                    style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: conversations.length,
            separatorBuilder: (c, i) => Divider(height: 1, indent: 72, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        conversationId: conv.id,
                        participantName: conv.participantName ?? 'Người thân',
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.brown.shade50,
                  backgroundImage: conv.participantAvatarUrl != null 
                      ? NetworkImage(conv.participantAvatarUrl!) 
                      : null,
                  child: conv.participantAvatarUrl == null
                      ? Text(
                          (conv.participantName ?? 'A').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.cinzel(color: Colors.brown, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(
                  conv.participantName ?? 'Người dùng không xác định',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        conv.lastMessageContent ?? 'Bắt đầu cuộc trò chuyện...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: (conv.isLastMessageRead ?? true) ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  conv.lastMessageAt != null 
                      ? timeago.format(conv.lastMessageAt!, locale: 'vi_short') 
                      : '',
                  style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                ),
              ).animate().fadeIn(delay: (50 * index).ms);
            },
          );
        },
      ),
    );
  }
}
