import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

class MemberChatPage extends StatefulWidget {
  final String otherMemberId; // Profile ID
  final String otherMemberName;

  const MemberChatPage({super.key, required this.otherMemberId, required this.otherMemberName});

  @override
  State<MemberChatPage> createState() => _MemberChatPageState();
}

class _MemberChatPageState extends State<MemberChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _conversationId;
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  final String _myId = Supabase.instance.client.auth.currentUser!.id;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      // 1. Get or Create Conversation
      final res = await Supabase.instance.client
          .rpc('get_or_create_conversation', params: {'target_user_id': widget.otherMemberId});
      
      _conversationId = res.toString();

      // 2. Setup Stream
      _messagesStream = Supabase.instance.client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', _conversationId!)
          .order('created_at')
          .map((maps) => maps);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi kết nối: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _inputController.clear();
    
    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'conversation_id': _conversationId,
        'sender_id': _myId,
        // Ensure content is stored as string
        'content': text.toString(),
      });
      
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 50,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gửi tin: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(widget.otherMemberName.isNotEmpty ? widget.otherMemberName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherMemberName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                  const Text('Tin nhắn riêng tư', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Bắt đầu cuộc trò chuyện với ${widget.otherMemberName}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          // Robust parsing to avoid "int is not subtype of String"
                          final senderId = (msg['sender_id'] ?? '').toString();
                          final isMe = senderId == _myId;
                          final content = (msg['content'] ?? '').toString();
                          
                          DateTime time;
                          try {
                            time = DateTime.parse(msg['created_at'].toString());
                          } catch (_) {
                            time = DateTime.now();
                          }
                          
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF8B1A1A).withOpacity(0.1) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20).copyWith(
                                  bottomRight: isMe ? Radius.zero : null,
                                  bottomLeft: isMe ? null : Radius.zero,
                                ),
                                border: Border.all(color: isMe ? const Color(0xFF8B1A1A).withOpacity(0.2) : Colors.grey.shade300),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content, 
                                    style: TextStyle(
                                      fontSize: 15, 
                                      color: Colors.black87,
                                      fontWeight: isMe ? FontWeight.w500 : FontWeight.normal
                                    )
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(time, locale: 'vi'),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: InputBorder.none,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF8B1A1A), // Match theme
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
