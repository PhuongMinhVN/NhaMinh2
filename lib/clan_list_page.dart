import 'package:flutter/material.dart';
// Refreshed file content
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import '../repositories/clan_repository.dart'; // Added Import
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'clan_tree_page.dart';
import 'widgets/merge_clan_wizard.dart';
import 'scan_qr_page.dart';
import 'pages/notifications_page.dart';

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

  // Helper to open scanner
  void _openScanner() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const ScanQrPage())
    );
    // Refresh list in case user joined a clan
    _fetchClans();
  }

  void _showQrDialog(BuildContext context, String clanId, String clanName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mã QR: $clanName', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: 'CLAN:$clanId',
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Người khác có thể quét mã này để tham gia gia phả.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
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
          if (widget.isClan) ...[
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Quét mã QR',
              onPressed: _openScanner,
            ),
            IconButton(
              icon: const Icon(Icons.savings_rounded),
              tooltip: 'Quỹ Dòng Họ',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng Quỹ đang phát triển')));
              },
            ),
          ],
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
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
                                        
                                        if (!isHidden)
                                          InkWell(
                                            onTap: () {
                                               Clipboard.setData(ClipboardData(text: clan['id'].toString().substring(0, 6).toUpperCase()));
                                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép Mã Gộp')));
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
                                                      const SizedBox(width: 8),
                                                      const Icon(Icons.copy, size: 14, color: Colors.blue),
                                                      const SizedBox(width: 12),
                                                      Container(width: 1, height: 12, color: Colors.grey.shade300),
                                                      const SizedBox(width: 12),
                                                      InkWell(
                                                        onTap: () => _showQrDialog(context, clan['id'], clan['name'] ?? 'Gia phả'),
                                                        child: const Icon(Icons.qr_code_2, size: 18, color: Colors.black87),
                                                      ),
                                                   ],
                                                 )
                                            ),
                                          ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                       if (v == 'hide') _toggleHideClan(clan['id']);
                                       if (v == 'rename') _showRenameDialog(clan);
                                       if (v == 'merge') _showMergeDialog(clan);
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
                                       if (isOwner)
                                         PopupMenuItem(
                                           value: 'rename',
                                           child: Row(
                                             children: [
                                               Icon(Icons.edit, size: 20, color: Colors.blue),
                                               const SizedBox(width: 8),
                                               Text('Đổi tên ${widget.isClan ? 'Dòng họ' : 'Gia đình'}', style: TextStyle(color: Colors.blue)),
                                             ],
                                           ),
                                         ),
                                       if (isOwner)
                                         const PopupMenuItem(
                                           value: 'merge',
                                           child: Row(
                                             children: [
                                               Icon(Icons.merge_type, size: 20, color: Colors.blueGrey),
                                               SizedBox(width: 8),
                                               Text('Gộp vào Dòng họ khác', style: TextStyle(color: Colors.blueGrey)),
                                             ],
                                           ),
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.notifications_outlined, size: 20),
                                        label: const Text('Thông báo'),
                                        onPressed: () {
                                           Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => NotificationsPage(
                                                clanId: clan['id'],
                                                initialIndex: 0,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (isOwner) ...[
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                          label: const Text('Duyệt thành viên'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: widget.isClan ? Colors.brown : Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => NotificationsPage(
                                                  clanId: clan['id'],
                                                  initialIndex: 1, // Open Requests tab
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // Footer Large Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ]
            ),
            child: ElevatedButton.icon(
              onPressed: _openScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: Text(
                widget.isClan ? 'QUÉT MÃ THAM GIA DÒNG HỌ' : 'QUÉT MÃ THAM GIA GIA ĐÌNH',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          )
        ],
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

  void _showMergeDialog(dynamic clan) {
    if (clan['owner_id'] == null) return;
    
    // We need current user id to identify root
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => MergeClanWizard(
        sourceClanId: clan['id'], 
        sourceClanName: clan['name'],
        currentUserId: currentUserId,
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
      final client = Supabase.instance.client;

      // 1. Fetch all members to find potential links
      final membersRes = await client.from('family_members').select('id').eq('clan_id', clanId);
      final memberIds = (membersRes as List).map((m) => m['id']).toList();

      // 2. Delete Requests referencing this Clan directly
      await client.from('clan_join_requests').delete().eq('target_clan_id', clanId);

      // 3. Delete Requests referencing Members of this Clan (as parents)
      if (memberIds.isNotEmpty) {
        await client.from('clan_join_requests').delete().filter('target_parent_id', 'in', memberIds);
      }

      // 4. Delete Family Members
      await client.from('family_members').delete().eq('clan_id', clanId);

      // 5. Delete Clan
      await client.from('clans').delete().eq('id', clanId);

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

  void _showRenameDialog(dynamic clan) {
    final TextEditingController nameController = TextEditingController(text: clan['name']);
    final TextEditingController descController = TextEditingController(text: clan['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên ${widget.isClan ? 'Dòng Họ' : 'Gia Đình'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên mới', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _renameClan(clan['id'], nameController.text.trim(), descController.text.trim());
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameClan(String clanId, String newName, String newDesc) async {
    if (newName.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await ClanRepository().updateClan(clanId: clanId, name: newName, description: newDesc);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
        _fetchClans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}
