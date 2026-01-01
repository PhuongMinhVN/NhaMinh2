
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gal/gal.dart'; // Mobile Image Saver
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart'; // Added
import 'pages/notifications_page.dart';
import 'models/family_member.dart';
import 'scan_qr_page.dart';
import 'widgets/member_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
// For Web saving
import 'utils/stub_html.dart' if (dart.library.html) 'dart:html' as html; 
import 'utils/relationship_calculator.dart';
import 'widgets/merge_clan_wizard.dart';
import 'pages/requests_list_page.dart';
import 'widgets/graph_tree_view.dart';
import 'pages/member_chat_page.dart'; // Updated to use new Chat Page
import 'widgets/family_calendar.dart'; // Added Calendar Widget


class ClanTreePage extends StatefulWidget {
  final String clanId;
  final String clanName;
  final String ownerId;
  final String? clanType;

  const ClanTreePage({
    super.key, 
    required this.clanId, 
    required this.clanName, 
    required this.ownerId,
    this.clanType,
  });

  @override
  State<ClanTreePage> createState() => _ClanTreePageState();
}

class _ClanTreePageState extends State<ClanTreePage> with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  late TabController _tabController;

  List<FamilyMember> _members = [];
  bool _isLoading = true;
  String? _currentUserTitle;
  bool _isOwner = false;
  String? _currentUserId;

  bool _isGraphView = false; // State for View Mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await Supabase.instance.client
          .from('family_members')
          .select()
          .eq('clan_id', widget.clanId)
          .order('birth_date', ascending: true);

      setState(() {
        _members = (res as List).map((json) => FamilyMember.fromJson(json)).toList();
        
        _currentUserId = Supabase.instance.client.auth.currentUser?.id;
        _isOwner = _currentUserId == widget.ownerId;
        
        final myMemberRecord = _members.firstWhere(
            (m) => m.profileId == _currentUserId, 
            orElse: () => FamilyMember(id: -1, fullName: '', isAlive: true)
        );
        if (myMemberRecord.id != -1) {
           _currentUserTitle = myMemberRecord.title;
        }

        // Calculate Generations and Sort
        _calculateGenerationsAndSort();
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateGenerationsAndSort() {
        final Map<int, FamilyMember> idMap = {for (var m in _members) m.id: m};
        
        int getGen(int id) {
           final m = idMap[id];
           if (m == null) return 1;
           if (m.generationLevel != null) return m.generationLevel!;
           
           int parentGen = 0;
           if (m.fatherId != null) {
              parentGen = getGen(m.fatherId!);
           } else if (m.motherId != null) {
              parentGen = getGen(m.motherId!);
           } else {
              m.generationLevel = 1;
              return 1;
           }
           
           m.generationLevel = parentGen + 1;
           return m.generationLevel!;
        }

        for (var m in _members) {
           if (m.generationLevel == null) getGen(m.id);
        }

        _members.sort((a, b) {
          final genA = a.generationLevel ?? 99;
          final genB = b.generationLevel ?? 99;
          if (genA != genB) return genA.compareTo(genB);

          int rankA = RelationshipCalculator.getRank(a.title);
          int rankB = RelationshipCalculator.getRank(b.title);
          if (rankA != rankB) return rankA.compareTo(rankB);
          
          if (a.birthOrder != null && b.birthOrder != null) {
             return a.birthOrder!.compareTo(b.birthOrder!);
          }

          if (a.birthDate != null && b.birthDate != null) {
            return a.birthDate!.compareTo(b.birthDate!);
          }
          
          return a.id.compareTo(b.id);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clanName),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 4,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
          unselectedLabelStyle: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'SỰ KIỆN & LỊCH', icon: Icon(Icons.calendar_month, size: 28)),
            Tab(text: 'THÀNH VIÊN', icon: Icon(Icons.people, size: 28)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGraphView ? Icons.list : Icons.account_tree),
            tooltip: _isGraphView ? 'Xem danh sách' : 'Xem sơ đồ',
            onPressed: () => setState(() => _isGraphView = !_isGraphView),
          ),
          IconButton(
             icon: const Icon(Icons.notifications_outlined),
             tooltip: 'Thông báo',
             onPressed: () {
                // Show Notifications Page
               Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(clanId: widget.clanId)));
             },
          ),
          PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'merge') _showMergeDialog();
                if (v == 'qr') _showClanQr(context);
                if (v == 'leave') _leaveClan();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'qr', child: Text('Mã QR Gia Phả')),
                if (_isOwner) const PopupMenuItem(value: 'merge', child: Text('Gộp Dòng Họ')),
                if (!_isOwner) const PopupMenuItem(value: 'leave', child: Text('Rời Gia Phả', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: EVENTS (Now First)
                FamilyCalendar(clanId: widget.clanId),

                // TAB 2: MEMBERS (Now Second)
                _buildMembersTab(),
              ],
            ),
       floatingActionButton: _tabController.index == 1 && !_isGraphView 
           ? FloatingActionButton(
                heroTag: 'add_member',
                onPressed: () => _showAddMemberSheet(context),
                backgroundColor: const Color(0xFF8B1A1A),
                tooltip: 'Thêm thành viên',
                child: const Icon(Icons.person_add_alt_1, color: Colors.white),
              )
           : null,
    );
  }

  Widget _buildMembersTab() {
    if (_members.isEmpty) return _buildEmptyState();
    
    if (_isGraphView) {
      return GraphTreeView(
         members: _members, 
         onMemberTap: _showMemberDetails,
         isClan: widget.clanType == 'clan',
      );
    }
    
    return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: _members.length,
       itemBuilder: (context, index) => _buildMemberCard(_members[index]),
    );
  }

  void _showAddMemberSheet(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => MemberBottomSheet(
        clanId: widget.clanId,
        existingMembers: _members,
        isOwner: _isOwner,
      ),
    );

    if (result == true) {
      _fetchMembers();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thành viên mới!'), backgroundColor: Colors.green));
    }
  }

  void _showClanQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mã QR Gia phả', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200, height: 200,
              child: QrImageView(data: 'CLAN:${widget.clanId}', version: QrVersions.auto),
            ),
            const SizedBox(height: 16),
            SelectableText(widget.clanId, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ElevatedButton(onPressed: _saveQrCode, child: const Text('Lưu ảnh')),
        ],
      ),
    );
  }

  Future<void> _saveQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "QR_${widget.clanName}.png")
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tải mã QR xuống!')));
      } else {
        // MOBILE SAVING
        try {
          // Check/Request permission
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
             await Gal.requestAccess();
          }

          // Save
          await Gal.putImageBytes(pngBytes, name: "QR_${widget.clanName}_${DateTime.now().millisecondsSinceEpoch}");
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu mã QR vào Thư viện ảnh!'), backgroundColor: Colors.green));
          }
        } catch (e) {
          if (mounted) {
            if (e is GalException && e.type == GalExceptionType.accessDenied) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng cấp quyền truy cập Thư viện ảnh.')));
            } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu ảnh: $e')));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Save QR Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
    }
  }

  void _handleQrScan() async {
    final scannedCode = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const ScanQrPage(returnScanData: true))
    );

    if (scannedCode != null && scannedCode is String) {
       _processInvite(scannedCode);
    }
  }

  Future<void> _processInvite(String qrCode) async {
     setState(() => _isLoading = true);
     try {
       final profile = await Supabase.instance.client
           .from('profiles')
           .select()
           .eq('id', qrCode)
           .maybeSingle();
           
       if (profile == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy người dùng với mã này.')));
          setState(() => _isLoading = false);
          return;
       }

       if (!mounted) return;
       final confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('Mời thành viên'),
           content: Text('Bạn có muốn thêm "${profile['full_name']}" vào gia phả không?'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
             ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
           ],
         ),
       );

       if (confirm == true) {
          await Supabase.instance.client.from('family_members').insert({
            'clan_id': widget.clanId,
            'full_name': profile['full_name'],
            'profile_id': profile['id'],
            'is_alive': true,
            'gender': 'male', 
          });
          
          _fetchMembers();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thành viên thành công!'), backgroundColor: Colors.green));
       }

     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi mời: $e')));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Chưa có thành viên nào.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    final canEdit = _canEdit(member);
    final hasLinkedAccount = member.profileId != null;

    // Calculate Relationship
    String? relationLabel;
    if (_currentUserId != null && _members.isNotEmpty) {
      try {
        final viewer = _members.firstWhere((m) => m.profileId == _currentUserId);
        relationLabel = RelationshipCalculator.getTitle(member, viewer, _members);
      } catch (_) {}
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: member.isMaternal ? const BorderSide(color: Colors.purple, width: 0.5) : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
           backgroundColor: member.gender == 'male' ? Colors.blue.shade50 : Colors.pink.shade50,
           child: Icon(member.gender == 'male' ? Icons.male : Icons.female, color: member.gender == 'male' ? Colors.blue : Colors.pink),
        ),
        title: Row(
          children: [
            Expanded(child: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (member.profileId != null)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.indigo),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(
                     builder: (_) => MemberChatPage(
                       otherMemberId: member.profileId!, 
                       otherMemberName: member.fullName
                     )
                   ));
                },
                tooltip: member.profileId == _currentUserId ? 'Ghi chú cá nhân' : 'Nhắn tin',
              )
            else
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade300),
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thành viên này chưa liên kết tài khoản.')));
                },
                tooltip: 'Chưa liên kết tài khoản',
              ),
          ],
        ),
        subtitle: Text(relationLabel ?? (member.title ?? 'Thành viên')),
        trailing: hasLinkedAccount 
            ? const Icon(Icons.verified, color: Colors.green, size: 16) 
            : null,
        onTap: () => _showMemberDetails(member),
      ),
    ).animate().fadeIn();
  }

  bool _canEdit(FamilyMember member) {
    if (_isOwner) return true;
    return false;
  }

  void _updateMember(FamilyMember member) async {
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => MemberBottomSheet(
          clanId: widget.clanId,
          existingMembers: _members,
          isOwner: _isOwner,
          memberToEdit: member,
        ),
      );

      if (result == true) {
        _fetchMembers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin thành viên.'), backgroundColor: Colors.green));
      }
  }

  void _confirmDeleteMember(FamilyMember member) async {
      final confirm = await showDialog<bool>(
         context: context,
         builder: (c) => AlertDialog(
           title: const Text('Xoá thành viên?'),
           content: Text('Bạn có chắc chắn muốn xoá "${member.fullName}"?'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
             ElevatedButton(
               onPressed: () => Navigator.pop(c, true), 
               style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
               child: const Text('Xoá'),
             ),
           ],
         ),
      );

      if (confirm == true) {
         await Supabase.instance.client.from('family_members').delete().eq('id', member.id);
         _fetchMembers();
      }
  }

  void _showMergeDialog() {
    if (_currentUserId == null) return;
    showDialog(
      context: context,
      builder: (context) => MergeClanWizard(
        sourceClanId: widget.clanId, 
        sourceClanName: widget.clanName,
        currentUserId: _currentUserId!,
      ),
    );
  }

  Future<void> _leaveClan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời Gia Phả'),
        content: const Text('Bạn có chắc muốn rời khỏi gia phả này không? Thông tin của bạn trong cây gia phả vẫn sẽ được giữ lại, nhưng tài khoản của bạn sẽ không còn liên kết nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Rời đi'),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUserId != null) {
       try {
         await Supabase.instance.client
             .from('family_members')
             .update({'profile_id': null})
             .eq('clan_id', widget.clanId)
             .eq('profile_id', _currentUserId!);
             
         if (mounted) {
            Navigator.pop(context); // Exit tree page
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã rời khỏi gia phả.')));
         }
       } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
       }
    }
  }

  void _showMemberDetails(FamilyMember member) {
     showModalBottomSheet(
       context: context,
       builder: (context) => Container(
         padding: const EdgeInsets.all(24),
         decoration: const BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text(member.fullName, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
             Text(member.title ?? (member.gender == 'male' ? 'Nam' : 'Nữ'), style: const TextStyle(color: Colors.grey)),
             const SizedBox(height: 24),
             if (member.profileId != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                       Navigator.pop(context);
                       Navigator.push(context, MaterialPageRoute(
                         builder: (_) => MemberChatPage(
                           otherMemberId: member.profileId!, 
                           otherMemberName: member.fullName
                         )
                       ));
                    },
                    icon: const Icon(Icons.chat_bubble),
                    label: Text(member.profileId == _currentUserId ? 'Ghi chú cá nhân' : 'Nhắn tin'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                )
             else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chưa liên kết tài khoản'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.grey),
                  ),
                ),
             // Add Edit/Delete buttons if needed here
           ],
         ),
       ),
     );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}
