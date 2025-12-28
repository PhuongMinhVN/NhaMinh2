import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'clan_tree_page.dart';

import 'package:flutter/services.dart';

class ClanListPage extends StatefulWidget {
  final bool isClan; // true for Dòng họ, false for Gia đình

  const ClanListPage({super.key, required this.isClan});

  @override
  State<ClanListPage> createState() => _ClanListPageState();
}

class _ClanListPageState extends State<ClanListPage> {
  bool _isLoading = true;
  List<dynamic> _clans = [];

  @override
  void initState() {
    super.initState();
    _fetchClans();
  }

  Future<void> _fetchClans() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final ownedRes = await Supabase.instance.client
          .from('clans')
          .select()
          .eq('owner_id', user.id)
          .eq('type', widget.isClan ? 'clan' : 'family')
          .order('created_at', ascending: false);
      
      final joinedRes = await Supabase.instance.client
          .from('family_members')
          .select('clan_id, clans(*)')
          .eq('profile_id', user.id);
      
      List<dynamic> joinedClans = [];
      for (var item in joinedRes) {
        if (item['clans'] != null && item['clans']['type'] == (widget.isClan ? 'clan' : 'family')) {
             joinedClans.add(item['clans']);
        }
      }

      final Map<String, dynamic> merged = {};
      for (var c in ownedRes) merged[c['id']] = c;
      for (var c in joinedClans) merged[c['id']] ??= c;

      setState(() {
        _clans = merged.values.toList();
        _clans.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isClan ? 'Danh Sách Dòng Họ' : 'Danh Sách Gia Đình'),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clans.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clans.length,
                  itemBuilder: (context, index) {
                    final clan = _clans[index];
                    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                    final isOwner = clan['owner_id'] == currentUserId;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: widget.isClan ? Colors.brown.shade100 : Colors.green.shade100,
                          child: Icon(
                            widget.isClan ? Icons.account_balance : Icons.cottage,
                            color: widget.isClan ? Colors.brown : Colors.green,
                          ),
                        ),
                        title: Text(
                          clan['name'] ?? 'Chưa đặt tên', 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clan['description'] ?? 'Không có mô tả'),
                            if (isOwner) 
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text('Trưởng tộc / Admin', style: TextStyle(fontSize: 10, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text('Thành viên', style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                              ),
                              
                              if (widget.isClan)
                                InkWell(
                                  onTap: () {
                                     Clipboard.setData(ClipboardData(text: clan['id'].toString().substring(0, 6).toUpperCase()));
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép Mã Dòng họ')));
                                  },
                                  child: Container(
                                       margin: const EdgeInsets.only(top: 6),
                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.grey.shade100,
                                         borderRadius: BorderRadius.circular(4),
                                         border: Border.all(color: Colors.grey.shade300),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                            Text(
                                              'Mã gộp: ${clan['id'].toString().substring(0, 6).toUpperCase()}',
                                              style: TextStyle(fontSize: 11, fontFamily: GoogleFonts.sourceCodePro().fontFamily, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.copy, size: 12, color: Colors.blue),
                                         ],
                                       )
                                  ),
                                ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(clan),
                                tooltip: 'Xoá gia phả',
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                                onPressed: () => _confirmLeave(clan),
                                tooltip: 'Rời gia phả',
                              ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClanTreePage(
                                clanId: clan['id'],
                                clanName: clan['name'],
                                ownerId: clan['owner_id'],
                                clanType: clan['type'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.isClan ? Icons.account_balance_outlined : Icons.cottage_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            widget.isClan ? 'Bạn chưa tạo dòng họ nào.' : 'Bạn chưa tạo gia đình nào.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại để tạo mới'),
          )
        ],
      ),
    );
  }

  void _confirmLeave(dynamic clan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời gia phả'),
        content: Text('Bạn có chắc chắn muốn rời khỏi "${clan['name']}" không? Bạn sẽ không còn quyền truy cập vào thông tin của gia phả này nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveClan(clan['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Rời đi'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveClan(String clanId) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      await Supabase.instance.client
          .from('family_members')
          .update({'profile_id': null})
          .eq('clan_id', clanId)
          .eq('profile_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã rời gia phả thành công.'), backgroundColor: Colors.green),
        );
        _fetchClans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi rời: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDelete(dynamic clan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text('Bạn có chắc chắn muốn xoá "${clan['name']}" không? Hành động này sẽ xoá toàn bộ thành viên trong gia phả này và không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClan(clan['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClan(String clanId) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('family_members')
          .delete()
          .eq('clan_id', clanId);

      await Supabase.instance.client
          .from('clans')
          .delete()
          .eq('id', clanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá gia phả thành công.'), backgroundColor: Colors.green),
        );
        _fetchClans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xoá: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}
