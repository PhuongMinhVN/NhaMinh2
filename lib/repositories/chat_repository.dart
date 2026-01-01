import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Get or Create Private Conversation
  Future<String> getOrCreateConversation(String targetUserId) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_conversation',
        params: {'target_user_id': targetUserId},
      );
      return response as String;
    } catch (e) {
      throw Exception('Failed to get/create conversation: $e');
    }
  }

  // 2. Fetch Conversations (List)
  // This is a bit tricky because we need to join to get the "other" participant's info.
  // For now, we will fetch conversations and then maybe fetch profiles?
  // Or utilize a view. Given Supabase complexity, let's fetch raw conversations then manually enrich if needed,
  // OR better: use a complex select.
  // We'll try to fetch conversations and the *other* participant.
  
  // Actually, to make UI fast, let's fetch conversations ordered by updated_at.
  // Then for each, we need the display name.
  // We can do this with a chained select if we had a view, but standard table permissions might be strict.
  // Let's rely on client-side mapping for MVP or a simple query.
  
  Stream<List<ChatConversation>> getConversationsStream() {
    final myUserId = _supabase.auth.currentUser!.id;

    // Stream conversations table
    // But this doesn't give us the other user's name easily without complex joins unsupported in stream.
    // Standard approach: Stream 'chat_conversations' where I am a participant.
    // BUT RLS policy says "users can view their conversations", so simple select() works.
    
    return _supabase
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .asyncMap((data) async {
          // Enrich data with the other participant's info
          List<ChatConversation> conversations = [];
          
          for (var item in data) {
             final convId = item['id'];
             
             // Fetch the OTHER participant for this conversation
             final participants = await _supabase
                 .from('chat_participants')
                 .select('user_id')
                 .eq('conversation_id', convId)
                 .neq('user_id', myUserId) // Get the other guy
                 .limit(1);
                 
             String? partName = 'Unknown';
             String? partAvatar;
             
             if (participants.isNotEmpty) {
               final otherId = participants[0]['user_id'];
               // Fetch their profile/name. 
               // Depending on your schema, auth.users metadata or a 'profiles' table.
               // Assuming you store metadata in auth or have a profiles table.
               // Let's try fetching from public 'profiles' or FamilyMember? 
               // FamilyMember is complex because same user logic.
               // Let's assume we can get metadata from a fetch to 'profiles' if it exists, or just use a placeholder for now.
               // NOTE: In `RegisterPage`, we saw `full_name` stored in metadata.
               
               // We can't easily query auth.users from client. 
               // We need a public profiles table. 
               // IF NOT EXISTS, we might have trouble showing names unless we query FamilyMembers by profileId.
               
               // Strategy: Query 'family_members' where profile_id = otherId limit 1.
               final memberRes = await _supabase
                   .from('family_members')
                   .select('full_name, avatar_url')
                   .eq('profile_id', otherId)
                   .limit(1)
                   .maybeSingle();
                   
               if (memberRes != null) {
                 partName = memberRes['full_name'];
                 partAvatar = memberRes['avatar_url'];
               }
             }

             // Fetch last message
             final lastMsgRes = await _supabase
                 .from('chat_messages')
                 .select('content, sender_id, is_read')
                 .eq('conversation_id', convId)
                 .order('created_at', ascending: false)
                 .limit(1)
                 .maybeSingle();

             conversations.add(ChatConversation(
               id: item['id'],
               createdAt: DateTime.parse(item['created_at']),
               updatedAt: DateTime.parse(item['updated_at']),
               type: item['type'],
               lastMessageAt: item['last_message_at'] != null ? DateTime.parse(item['last_message_at']) : null,
               participantName: partName,
               participantAvatarUrl: partAvatar,
               lastMessageContent: lastMsgRes?['content'],
               lastMessageSenderId: lastMsgRes?['sender_id'],
               isLastMessageRead: lastMsgRes?['is_read'],
             ));
          }
          return conversations;
        });
  }

  // 3. Fetch Messages for a Conversation
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true) // Oldest top, newest bottom
        .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
  }

  // 4. Send Message
  Future<void> sendMessage(String conversationId, String content) async {
    final myUserId = _supabase.auth.currentUser!.id;
    await _supabase.from('chat_messages').insert({
      'conversation_id': conversationId,
      'sender_id': myUserId,
      'content': content,
    });
  }
}
