import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _userId = Supabase.instance.client.auth.currentUser?.id;
  late final Stream<List<Map<String, dynamic>>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    if (_userId != null) {
      _notificationsStream = Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .map((data) => List<Map<String, dynamic>>.from(data));
    } else {
       _notificationsStream = Stream.value([]);
    }
  }

  Future<void> _markAsRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId!)
        .eq('is_read', false); // Only update unread ones
        
    if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')));
    }
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông Báo', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _markAllAsRead,
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
                   const SizedBox(height: 16),
                   Text('Chưa có thông báo nào', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif['is_read'] as bool? ?? false;
              final type = notif['type'] as String? ?? 'general';

              IconData icon;
              Color iconColor;
              switch (type) {
                case 'event_new':
                  icon = Icons.event;
                  iconColor = Colors.orange;
                  break;
                case 'event_reminder':
                  icon = Icons.alarm;
                  iconColor = Colors.red;
                  break;
                default:
                  icon = Icons.info;
                  iconColor = Colors.blue;
              }

              return ListTile(
                tileColor: isRead ? null : Colors.blue.withOpacity(0.05),
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  child: Icon(icon, color: iconColor),
                ),
                title: Text(
                  notif['title'] ?? 'Thông báo',
                  style: isRead 
                      ? const TextStyle(fontWeight: FontWeight.normal)
                      : const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notif['created_at']),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                onTap: () {
                   if (!isRead) {
                      _markAsRead(notif['id'].toString());
                   }
                   // Future enhancement: Navigate to related_id
                },
              ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
            },
          );
        },
      ),
    );
  }
}
