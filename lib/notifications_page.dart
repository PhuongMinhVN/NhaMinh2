import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'repositories/clan_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _userId = Supabase.instance.client.auth.currentUser?.id;
  late final Stream<List<Map<String, dynamic>>> _notificationsStream;
  
  // Requests Tab Data
  final _clanRepo = ClanRepository();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Setup Notification Stream
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

    // Fetch Requests
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final requests = await _clanRepo.fetchAllMyClanRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoadingRequests = false);
         debugPrint('Error fetching requests: $e');
      }
    }
  }

  Future<void> _handleRequestAction(String id, bool isApprove) async {
    try {
       // Show local loading if needed, or just update UI optimistically
       // For now, simple await
       if (isApprove) {
         await _clanRepo.approveRequest(id);
       } else {
         await _clanRepo.rejectRequest(id);
       }
       
       await _fetchRequests(); // Refresh list
       
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isApprove ? 'Đã duyệt yêu cầu' : 'Đã từ chối yêu cầu'), 
            backgroundColor: isApprove ? Colors.green : Colors.red
          ));
       }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _markAsRead(String id) async {
    await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId!)
        .eq('is_read', false);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trung tâm Thông báo', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Thông báo'),
            Tab(text: 'Yêu cầu'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
               // Refresh both
               setState(() {}); 
               _fetchRequests();
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(),
          _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final notifications = snapshot.data!;
          if (notifications.isEmpty) return _buildEmptyState('Chưa có thông báo nào', Icons.notifications_off_outlined);

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
                case 'event_new': icon = Icons.event; iconColor = Colors.orange; break;
                case 'event_reminder': icon = Icons.alarm; iconColor = Colors.red; break;
                default: icon = Icons.info; iconColor = Colors.blue;
              }

              return ListTile(
                tileColor: isRead ? null : Colors.blue.withOpacity(0.05),
                leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
                title: Text(notif['title'] ?? 'Thông báo', style: isRead ? null : const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(notif['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                     Text(_formatTime(notif['created_at']), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                   ],
                ),
                onTap: () {
                   if (!isRead) _markAsRead(notif['id'].toString());
                },
              ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
            },
          );
        },
    );
  }

  Widget _buildRequestsList() {
    if (_isLoadingRequests) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) return _buildEmptyState('Không có yêu cầu nào', Icons.mark_email_read_outlined);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final profile = req['requester_profile'] as Map<String, dynamic>?;
        final name = profile?['full_name'] ?? 'Unknown';
        final email = profile?['email'] ?? '';
        final meta = req['metadata'] as Map<String, dynamic>? ?? {};
        final type = req['type'] ?? 'claim_existing';
        
        // Clan Name logic: try to get from join, else unknown
        final clanName = (req['clans'] as Map<String, dynamic>?)?['name'] ?? 'Dòng họ';

        String title = '$name ($email)';
        String subtitle = 'Gửi tới: $clanName\n';

        if (type == 'claim_existing') {
           subtitle += 'Muốn nhận hồ sơ ID: ${meta['member_id']}';
        } else if (type == 'create_new') {
           final relation = meta['relation'] == 'child' ? 'Con' : 'Vợ/Chồng';
           subtitle += 'Tạo mới: ${meta['full_name']}\nLà $relation của ID ${meta['relative_id']}';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _handleRequestAction(req['id'], false),
                      child: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _handleRequestAction(req['id'], true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Phê duyệt'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ).animate().slideX();
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(icon, size: 60, color: Colors.grey.shade400),
           const SizedBox(height: 16),
           Text(text, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }
}
