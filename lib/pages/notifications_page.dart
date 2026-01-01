import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../repositories/clan_repository.dart';
import '../dashboard_page.dart';

class NotificationsPage extends StatefulWidget {
  final String clanId;
  final int initialIndex; // New parameter
  const NotificationsPage({super.key, required this.clanId, this.initialIndex = 0});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _myId = Supabase.instance.client.auth.currentUser!.id;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
  }

  Future<void> _checkOwner() async {
    // strict check or just try to fetch requests
    // For now, let's assume everyone can see the tab, but only admins see data or get empty list
    // Improve: Check if user is owner of the clan
    try {
      final clan = await Supabase.instance.client.from('clans').select('owner_id').eq('id', widget.clanId).single();
      setState(() {
        _isOwner = clan['owner_id'] == _myId;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông Báo & Yêu Cầu', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Về Trang Chủ',
            onPressed: () {
               Navigator.pushAndRemoveUntil(
                 context, 
                 MaterialPageRoute(builder: (_) => DashboardPage()), 
                 (route) => false
               );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red.shade900,
          tabs: const [
            Tab(text: 'Thông báo'),
            Tab(text: 'Yêu cầu duyệt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralNotificationsTab(userId: _myId),
          _JoinRequestsTab(clanId: widget.clanId, canAction: _isOwner),
        ],
      ),
    );
  }
}

class _GeneralNotificationsTab extends StatelessWidget {
  final String userId;
  const _GeneralNotificationsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final notifs = snapshot.data!;
        if (notifs.isEmpty) return const Center(child: Text('Không có thông báo mới.'));

        return ListView.separated(
          itemCount: notifs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final n = notifs[index];
            final time = DateTime.parse(n['created_at']);
            final isRead = n['is_read'] ?? false;

            return ListTile(
              tileColor: isRead ? Colors.white : Colors.blue.shade50,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                child: const Icon(Icons.notifications, color: Colors.white, size: 20),
              ),
              title: Text(n['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['body'] ?? ''),
                  Text(timeago.format(time, locale: 'vi'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              onTap: () async {
                // Mark as read
                if (!isRead) {
                   await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', n['id']);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _JoinRequestsTab extends StatefulWidget {
  final String clanId;
  final bool canAction;
  const _JoinRequestsTab({required this.clanId, required this.canAction});

  @override
  State<_JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends State<_JoinRequestsTab> {
  final _repo = ClanRepository();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final data = await _repo.fetchPendingRequests(widget.clanId);
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _action(String id, bool approve) async {
    setState(() => _isLoading = true);
    try {
      if (approve) await _repo.approveRequest(id);
      else await _repo.rejectRequest(id);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Đã duyệt' : 'Đã từ chối')));
      _fetchRequests();
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (!widget.canAction) return const Center(child: Text('Bạn không có quyền duyệt thành viên.'));
    if (_requests.isEmpty) return const Center(child: Text('Không có yêu cầu nào.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final profile = req['requester_profile'] as Map<String, dynamic>?;
        final name = profile?['full_name'] ?? 'Unknown';
        
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: Text(name),
            subtitle: const Text('Xin gia nhập dòng họ'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _action(req['id'], false)),
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _action(req['id'], true)),
              ],
            ),
          ),
        );
      },
    );
  }
}
