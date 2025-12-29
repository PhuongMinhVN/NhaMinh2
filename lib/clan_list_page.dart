import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import
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
  List<dynamic> _allClans = []; // Store raw data
  List<dynamic> _visibleClans = [];
  Set<String> _hiddenClanIds = {};
  bool _showHidden = false; // Toggle state

  @override
  void initState() {
    super.initState();
    _loadHiddenClans();
  }

  Future<void> _loadHiddenClans() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hiddenClanIds = (prefs.getStringList('hidden_clans') ?? []).toSet();
    });
    // Fetch clans after loading prefs to Apply filter immediately
    _fetchClans();
  }

  Future<void> _toggleHideClan(String clanId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_hiddenClanIds.contains(clanId)) {
        _hiddenClanIds.remove(clanId);
      } else {
        _hiddenClanIds.add(clanId);
      }
      _applyFilter();
    });
    await prefs.setStringList('hidden_clans', _hiddenClanIds.toList());
  }

  void _applyFilter() {
    setState(() {
      if (_showHidden) {
        _visibleClans = List.from(_allClans);
      } else {
        _visibleClans = _allClans.where((c) => !_hiddenClanIds.contains(c['id'])).toList();
      }
    });
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
        _allClans = merged.values.toList();
        _allClans.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
         // Optionally suppress error if just offline?
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
        actions: [
          IconButton(
            icon: Icon(_showHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: _showHidden ? 'Ẩn các gia phả đã ẩn' : 'Hiện các gia phả đã ẩn',
            onPressed: () {
              setState(() {
                _showHidden = !_showHidden;
                _applyFilter();
              });
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visibleClans.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _visibleClans.length,
                  itemBuilder: (context, index) {
                    final clan = _visibleClans[index];
                    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                    final isOwner = clan['owner_id'] == currentUserId;
                    final isHidden = _hiddenClanIds.contains(clan['id']);

                    return Opacity(
                      opacity: isHidden ? 0.6 : 1.0,
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isHidden ? Colors.grey.shade200 : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.isClan ? Colors.brown.shade100 : Colors.green.shade100,
                            child: Icon(
                              isHidden ? Icons.visibility_off : (widget.isClan ? Icons.account_balance : Icons.cottage),
                              color: isHidden ? Colors.grey : (widget.isClan ? Colors.brown : Colors.green),
                            ),
                          ),
                          title: Text(
                            clan['name'] ?? 'Chưa đặt tên', 
                            style: TextStyle(fontWeight: FontWeight.bold, decoration: isHidden ? TextDecoration.lineThrough : null, color: isHidden ? Colors.grey : null)
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
                                
                                if (widget.isClan && !isHidden)
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
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                               if (v == 'hide') _toggleHideClan(clan['id']);
                               if (v == 'delete') _confirmDelete(clan);
                               if (v == 'leave') _confirmLeave(clan);
                            },
                            itemBuilder: (context) => [
                               PopupMenuItem(
                                 value: 'hide', 
                                 child: Row(
                                    children: [
                                      Icon(isHidden ? Icons.visibility : Icons.visibility_off, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(isHidden ? 'Hiện gia phả' : 'Ẩn gia phả'),
                                    ],
                                 )
                               ),
                               if (isOwner && !widget.isClan) // Only allow deleting Families, not Clans
                                 const PopupMenuItem(
                                   value: 'delete',
                                   child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Xoá gia phả', style: TextStyle(color: Colors.red))])
                                 )
                               else if (!isOwner)
                                 const PopupMenuItem(
                                   value: 'leave',
                                   child: Row(children: [Icon(Icons.exit_to_app, size: 20, color: Colors.orange), SizedBox(width: 8), Text('Rời gia phả', style: TextStyle(color: Colors.orange))])
                                 )
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
          if (_showHidden && _allClans.isNotEmpty)
             const Text('(Đang hiển thị cả gia phả bị ẩn)', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          
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
      // 1. Delete Join Requests first (referencing Foreign Key)
      await Supabase.instance.client
          .from('clan_join_requests')
          .delete()
          .eq('target_clan_id', clanId);

      // 2. Delete Family Members
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
