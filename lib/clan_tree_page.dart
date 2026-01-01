
import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Added import
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
  String? _currentUserAvatar; // Add this

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
          .select('*, profiles(avatar_url)')
          .eq('clan_id', widget.clanId)
          .order('birth_date', ascending: true);

      // Fetch current user details including avatar
      // Fetch current user details including avatar
      _currentUserId = Supabase.instance.client.auth.currentUser?.id;
      
      Map<String, dynamic>? userProfile;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        userProfile = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', _currentUserId!)
            .maybeSingle();
      }

      String? myAvatarUrl;
      if (userProfile != null) {
          myAvatarUrl = userProfile['avatar_url'];
      }

      setState(() {
        _members = (res as List).map((json) => FamilyMember.fromJson(json)).toList();
        
        _currentUserId = Supabase.instance.client.auth.currentUser?.id;
        _isOwner = _currentUserId == widget.ownerId;
        _currentUserAvatar = myAvatarUrl; // New state variable
        
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Quét mã để thêm thành viên',
            onPressed: _handleQrScan,
          ),
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
                onPressed: _handleQrScan, // Changed to QR Scan
                backgroundColor: const Color(0xFF8B1A1A),
                tooltip: 'Quét mã thêm thành viên',
                child: const Icon(Icons.qr_code_scanner, color: Colors.white), // Changed Icon
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

       // Dialog to Select Relationship
       FamilyMember? selectedRelative;
     String relationType = 'child'; // child, spouse, independent
     String childType = 'biological'; // Default

     await showDialog(
       context: context,
       barrierDismissible: false,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setStateDialog) => AlertDialog(
         title: const Text('Thêm thành viên'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Tìm thấy: ${profile['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             const SizedBox(height: 16),
             const Text('Chọn mối quan hệ:'),
             DropdownButton<String>(
               isExpanded: true,
               value: relationType,
               items: const [
                 DropdownMenuItem(value: 'child', child: Text('Là Con của...')),
                 DropdownMenuItem(value: 'spouse', child: Text('Là Vợ/Chồng của...')),
                 DropdownMenuItem(value: 'independent', child: Text('Thành viên độc lập (Gốc)')),
               ],
               onChanged: (v) => setStateDialog(() {
                  relationType = v!;
                  selectedRelative = null;
               }),
             ),
             
             // Child Type Selection
             if (relationType == 'child') ...[
                const SizedBox(height: 8),
                const Text('Loại quan hệ:'),
                DropdownButton<String>(
                  isExpanded: true,
                  value: childType,
                  items: const [
                    DropdownMenuItem(value: 'biological', child: Text('Con Ruột')),
                    DropdownMenuItem(value: 'adopted', child: Text('Con Nuôi')),
                    DropdownMenuItem(value: 'step', child: Text('Con Riêng (Vợ/Chồng)')),
                    DropdownMenuItem(value: 'grandchild', child: Text('Là Cháu (Cháu nội/ngoại)')),
                  ],
                  onChanged: (v) => setStateDialog(() => childType = v!),
                ),
             ],

             if (relationType != 'independent') ...[
               const SizedBox(height: 8),
               Text(relationType == 'child' ? 'Chọn Bố/Mẹ:' : 'Chọn Vợ/Chồng:'),
               DropdownButton<FamilyMember>(
                 isExpanded: true,
                 hint: const Text('Chọn người thân'),
                 value: selectedRelative,
                 items: _members.map((m) => DropdownMenuItem(
                   value: m,
                   child: Text('${m.fullName} (${m.gender == 'male' ? 'Nam' : 'Nữ'})'),
                 )).toList(),
                 onChanged: (v) => setStateDialog(() => selectedRelative = v),
               ),
             ]
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
           ElevatedButton(
             onPressed: () {
               if (relationType != 'independent' && selectedRelative == null) {
                  return; // Must select relative
               }
               Navigator.pop(ctx, true);
             },
             child: const Text('Thêm'),
           ),
         ],
       ),
       ),
     ).then((confirm) async {
        if (confirm == true) {
            final Map<String, dynamic> insertData = {
              'clan_id': widget.clanId,
              'full_name': profile['full_name'],
              'profile_id': profile['id'],
              'is_alive': true,
              'gender': profile['gender'] ?? 'male', 
              'child_type': relationType == 'child' ? childType : null, // Add child_type
            };

            if (relationType == 'child' && selectedRelative != null) {
               if (selectedRelative!.gender == 'male') {
                  insertData['father_id'] = selectedRelative!.id;
               } else {
                  insertData['mother_id'] = selectedRelative!.id;
               }
               // Try to guess generation
               if (selectedRelative!.generationLevel != null) {
                  insertData['generation_level'] = selectedRelative!.generationLevel! + 1;
               }
            } else if (relationType == 'spouse' && selectedRelative != null) {
               insertData['spouse_id'] = selectedRelative!.id;
               if (selectedRelative!.generationLevel != null) {
                  insertData['generation_level'] = selectedRelative!.generationLevel;
               }
            } else {
               insertData['is_root'] = true;
               insertData['generation_level'] = 1;
            }

            await Supabase.instance.client.from('family_members').insert(insertData);
            
            _fetchMembers();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thành viên thành công!'), backgroundColor: Colors.green));
        }
     });

     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi thêm: $e')));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isOwner && _currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(_currentUserAvatar!),
            )
          else
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          if (_isOwner)
             Text('Chưa có thành viên nào.\nHãy thêm thành viên đầu tiên!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))
          else
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
           radius: 24, // Slightly larger
           backgroundColor: member.gender == 'male' ? Colors.blue.shade50 : Colors.pink.shade50,
           backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) 
               ? NetworkImage(member.avatarUrl!) 
               : null,
           child: (member.avatarUrl == null || member.avatarUrl!.isEmpty) 
               ? Icon(member.gender == 'male' ? Icons.male : Icons.female, color: member.gender == 'male' ? Colors.blue : Colors.pink)
               : null,
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
             
             // CONTEXTUAL ADD BUTTON
             // Allow Owner or Admin to add relatives
             if (_canEdit(member))
               IconButton(
                 icon: const Icon(Icons.person_add_alt, size: 20, color: Colors.brown),
                 onPressed: () => _showAddRelativeDialog(member),
                 tooltip: 'Thêm người thân',
               ),
          ],
        ),
        subtitle: Row(
          children: [
            if (member.clanRole == 'owner')
               Container(
                 margin: const EdgeInsets.only(right: 8),
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                 child: const Text('Chủ Nhà', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
               ),
            if (member.clanRole == 'admin')
               Container(
                 margin: const EdgeInsets.only(right: 8),
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                 child: const Text('Phó Nhà', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
               ),
            Text(relationLabel ?? (member.title ?? 'Thành viên')),
          ],
        ),
        trailing: hasLinkedAccount 
            ? const Icon(Icons.verified, color: Colors.green, size: 16) 
            : null,
        onTap: () => _showMemberDetails(member),
      ),
    ).animate().fadeIn();
  }

  bool _canEdit(FamilyMember member) {
    if (_isOwner) return true; // Owner can edit all
    
    // Check if current user is Admin
    try {
       final me = _members.firstWhere((m) => m.profileId == _currentUserId);
       if (me.clanRole == 'admin') {
          // Admin can delete/edit normal members, but not other Admins or Owner
          if (member.clanRole == 'member') return true;
       }
    } catch (_) {}
    
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
          content: Text('Bạn có chắc xoá ${member.fullName} không?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Xoá')
            ),
          ],
         ),
      );

      if (confirm == true) {
         await Supabase.instance.client.from('family_members').delete().eq('id', member.id);
         _fetchMembers();
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xoá thành viên.')));
      }
  }

  void _showEnterIdDialog() {
      final idCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nhập ID thành viên'),
          content: TextField(
            controller: idCtrl,
            decoration: const InputDecoration(
              labelText: 'ID / Mã hồ sơ (UUID)',
              hintText: 'Nhập mã ID...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            ElevatedButton(
              onPressed: () {
                 if (idCtrl.text.trim().isEmpty) return;
                 Navigator.pop(ctx);
                 _processInvite(idCtrl.text.trim());
              },
              child: const Text('Tìm kiếm'),
            ),
          ],
        ),
      );
  }

  void _showAddRelativeDialog(FamilyMember baseMember) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
             padding: const EdgeInsets.all(24),
             child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Thêm người thân cho ${baseMember.fullName}', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   ListTile(
                   leading: const Icon(Icons.qr_code_scanner, color: Colors.black87),
                   title: const Text('Quét mã QR'),
                   subtitle: const Text('Quét mã từ hồ sơ người dùng'),
                   onTap: () {
                      Navigator.pop(ctx);
                      _handleQrScan();
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.edit_note, color: Colors.indigo),
                   title: const Text('Nhập ID thành viên'),
                   subtitle: const Text('Nhập mã ID thủ công'),
                   onTap: () {
                      Navigator.pop(ctx);
                      _showEnterIdDialog();
                   },
                 ),
                ],
             ),
          ),
        ),
      );
  }

  // Simplified Manual Add for Contextual Action
  void _showManualAddSheet({required FamilyMember baseMember, required String relation}) {
      final nameCtrl = TextEditingController();
      String gender = 'male';
      String childType = 'biological'; // Default
      bool isAlive = true;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setSheetState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(relation == 'child' ? 'Thêm Con của ${baseMember.fullName}' : 'Thêm Vợ/Chồng của ${baseMember.fullName}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Họ và Tên', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  
                  // Relationship Type (Only for Child)
                  if (relation == 'child') ...[
                    const Text('Loại quan hệ:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: 'biological',
                      items: const [
                        DropdownMenuItem(value: 'biological', child: Text('Con Ruột')),
                        DropdownMenuItem(value: 'adopted', child: Text('Con Nuôi')),
                        DropdownMenuItem(value: 'step', child: Text('Con Riêng (Vợ/Chồng)')),
                        DropdownMenuItem(value: 'grandchild', child: Text('Là Cháu (Cháu nội/ngoại)')),
                      ],
                      onChanged: (v) {
                         if (v != null) setSheetState(() => childType = v);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                      onSaved: (v) {}, 
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      const Text('Giới tính: '),
                      Radio<String>(value: 'male', groupValue: gender, onChanged: (v) => setSheetState(() => gender = v!)),
                      const Text('Nam'),
                      Radio<String>(value: 'female', groupValue: gender, onChanged: (v) => setSheetState(() => gender = v!)),
                      const Text('Nữ'),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text('Còn sống?'),
                    value: isAlive, 
                    onChanged: (v) => setSheetState(() => isAlive = v!),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                         if (nameCtrl.text.isEmpty) return;
                         
                         final Map<String, dynamic> data = {
                           'clan_id': widget.clanId,
                           'full_name': nameCtrl.text.trim(),
                           'gender': gender,
                           'is_alive': isAlive,
                           'generation_level': (baseMember.generationLevel ?? 1) + (relation == 'child' ? 1 : 0),
                           // Add new fields
                           'child_type': relation == 'child' ? childType : null,
                           // 'role_label': roleLabelCtrl.text.isNotEmpty ? roleLabelCtrl.text.trim() : null,
                         };
                         
                         if (relation == 'child') {
                            if (baseMember.gender == 'male') {
                               data['father_id'] = baseMember.id;
                            } else {
                               data['mother_id'] = baseMember.id;
                            }
                         } else {
                            data['spouse_id'] = baseMember.id;
                         }

                         try {
                            await Supabase.instance.client.from('family_members').insert(data);
                            Navigator.pop(ctx);
                            _fetchMembers();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thành viên!'), backgroundColor: Colors.green));
                         } catch (e) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                         }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
                      child: const Text('Lưu thành viên'),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      );
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
             
             const SizedBox(height: 16),
             
             // OWNER ACTIONS: Manage Roles
             if (_isOwner && member.profileId != _currentUserId && member.clanRole != 'owner')
               ListTile(
                 leading: const Icon(Icons.security, color: Colors.orange),
                 title: const Text('Phân quyền (Phó Nhà)'),
                 onTap: () {
                    Navigator.pop(context);
                    _showRoleDialog(member);
                 },
               ),

             if (_canEdit(member)) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Chỉnh sửa thông tin'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateMember(member);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Xoá thành viên'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteMember(member);
                  },
                ),
             ],
           ],
         ),
       ),
     );
  }

  void _showRoleDialog(FamilyMember member) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Phân quyền cho ${member.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               ListTile(
                 title: const Text('Thành viên'),
                 leading: Radio<String>(
                   value: 'member', 
                   groupValue: member.clanRole, 
                   onChanged: (v) => _updateRole(member, v!, ctx)
                 ),
               ),
               ListTile(
                 title: const Text('Phó Nhà (Admin)'),
                 subtitle: const Text('Có quyền thêm/sửa/xoá thành viên'),
                 leading: Radio<String>(
                   value: 'admin', 
                   groupValue: member.clanRole, 
                   activeColor: Colors.orange,
                   onChanged: (v) => _updateRole(member, v!, ctx)
                 ),
               ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      );
  }

  void _updateRole(FamilyMember member, String newRole, BuildContext dialogContext) async {
     try {
        await Supabase.instance.client
            .from('family_members')
            .update({'clan_role': newRole})
            .eq('id', member.id);
            
        Navigator.pop(dialogContext); // Close dialog
        _fetchMembers(); // Refresh
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cập nhật vai trò: ${newRole == 'admin' ? 'Phó Nhà' : 'Thành viên'}')));
     } catch (e) {
        Navigator.pop(dialogContext);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
     }
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
