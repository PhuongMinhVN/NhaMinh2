import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _ClanTreePageState extends State<ClanTreePage> {
  final GlobalKey _qrKey = GlobalKey();
  List<FamilyMember> _members = [];
  bool _isLoading = true;
  String? _currentUserTitle;
  bool _isOwner = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
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

        // Calculate Generations
        // 1. Map ID to Member
        final Map<int, FamilyMember> idMap = {for (var m in _members) m.id: m};
        
        // 2. Recursive Generation Calculation
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
              // No parents in tree -> Root (Gen 1)
              m.generationLevel = 1;
              return 1;
           }
           
           m.generationLevel = parentGen + 1;
           return m.generationLevel!;
        }

        // 3. Compute for all
        for (var m in _members) {
           if (m.generationLevel == null) getGen(m.id);
        }

        // Sort priority: Generation -> Rank (Title) -> Birth Order -> ID
        _members.sort((a, b) {
          // 1. Generation (Ascending: Ancestor -> Descendant)
          final genA = a.generationLevel ?? 99;
          final genB = b.generationLevel ?? 99;
          if (genA != genB) return genA.compareTo(genB);

          // 2. Title Rank
          int rankA = RelationshipCalculator.getRank(a.title);
          int rankB = RelationshipCalculator.getRank(b.title);
          if (rankA != rankB) return rankA.compareTo(rankB);
          
          // 3. Birth Order
          if (a.birthOrder != null && b.birthOrder != null) {
             return a.birthOrder!.compareTo(b.birthOrder!);
          }

          // 4. DOB
          if (a.birthDate != null && b.birthDate != null) {
            return a.birthDate!.compareTo(b.birthDate!);
          }
          
          // 5. Fallback: Insertion Order
          return a.id.compareTo(b.id);
        });

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clanName),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => _showClanQr(context),
            tooltip: 'Mã QR Dòng họ',
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'merge') _showMergeDialog();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'merge',
                  child: Row(
                    children: [
                      Icon(Icons.merge_type, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Gộp vào Dòng họ khác'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
               ? _buildEmptyState()
               : ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: _members.length,
                   itemBuilder: (context, index) {
                     final member = _members[index];
                     return _buildMemberCard(member);
                   },
                 ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end, // Align right
        children: [
          // 1. Join Clan Button (Only for Family Owners)
          if (widget.clanType?.toLowerCase() == 'family' && _isOwner) ...[
             FloatingActionButton.extended(
              heroTag: 'join_clan',
              onPressed: _showMergeDialog, 
              label: const Text('Gia nhập Dòng họ'),
              icon: const Icon(Icons.group_add),
              backgroundColor: const Color(0xFF8B1A1A),
            ),
            const SizedBox(height: 12),
          ],
          
          // 2. Scan QR
          FloatingActionButton.small(
            heroTag: 'scan_invite',
            onPressed: _handleQrScan,
            backgroundColor: Colors.white,
            tooltip: 'Quét QR mời thành viên',
            child: const Icon(Icons.qr_code_scanner, color: Color(0xFF8B1A1A)),
          ),
          const SizedBox(height: 12),

          // 3. Add Member
          FloatingActionButton(
            heroTag: 'add_member',
            onPressed: () => _showAddMemberSheet(context),
            backgroundColor: const Color(0xFF8B1A1A),
            tooltip: 'Thêm thành viên thủ công',
            child: const Icon(Icons.person_add_alt_1, color: Colors.white),
          ),
        ],
      ),
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
            const Text('Người khác quét mã này để yêu cầu tham gia vào gia phả này.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              width: 232, 
              height: 232,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: RepaintBoundary(
                key: _qrKey,
                child: QrImageView(
                  data: 'CLAN:${widget.clanId}',
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.clanName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ElevatedButton.icon(
            onPressed: _saveQrCode, 
            icon: const Icon(Icons.download), 
            label: const Text('Lưu mã QR'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
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
        // For mobile, we'd need a plugin like 'gal' or 'image_gallery_saver'.
        // For now, let's at least show it worked or tell user to screenshot.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng lưu ảnh trên Mobile đang được cập nhật. Vui lòng chụp màn hình.')));
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
          const Text('Chưa có thành viên nào trong gia phả này.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }



  Widget _buildMemberCard(FamilyMember member) {
    final canEdit = _canEdit(member);
    final canDelete = _isOwner;
    final hasLinkedAccount = member.profileId != null;

    // 1. Calculate Relationship
    String? relationLabel;
    if (_currentUserId != null && _members.isNotEmpty) {
      try {
        // Find 'Viewer' (Current User's Member Record)
        final viewer = _members.firstWhere(
           (m) => m.profileId == _currentUserId, 
           orElse: () => FamilyMember(id: -1, fullName: '', isAlive: true)
        );
        
        if (viewer.id != -1) {
           // Utils: Calculate Title
           relationLabel = RelationshipCalculator.getTitle(member, viewer, _members);
        }
      } catch (_) {}
    }

    return Card(
      key: ValueKey(member.id),
      margin: const EdgeInsets.only(bottom: 12),
      color: member.isMaternal ? Colors.purple.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasLinkedAccount 
            ? const BorderSide(color: Colors.green, width: 1.5) 
            : member.isMaternal 
                ? BorderSide(color: Colors.purple.shade200, width: 1)
                : BorderSide.none,
      ),
      elevation: 2,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: member.gender == 'male' ? Colors.blue.shade100 : Colors.pink.shade100,
              child: Icon(
                member.gender == 'male' ? Icons.male : Icons.female,
                color: member.gender == 'male' ? Colors.blue.shade800 : Colors.pink.shade800,
              ),
            ),
            if (hasLinkedAccount)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (member.title != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text(member.title!, style: TextStyle(fontSize: 10, color: Colors.amber.shade900)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (relationLabel != null)
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 2.0),
                 child: Text(
                   relationLabel, 
                   style: const TextStyle(color: Color(0xFF8B1A1A), fontWeight: FontWeight.bold, fontSize: 13)
                 ),
               ),

          if (member.gender == 'female')
             // Find Spouse Name if possible
             Builder(builder: (c) {
               String? spouseName;
               if (member.spouseId != null) {
                  try { spouseName = _members.firstWhere((m) => m.id == member.spouseId).fullName; } catch(_) {}
               } else {
                  try { spouseName = _members.firstWhere((m) => m.spouseId == member.id).fullName; } catch(_) {}
               }
               
               if (spouseName != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text('Vợ của $spouseName', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                  );
               }
               return const SizedBox.shrink();
             }),
          Text(
            member.isAlive ? 'Còn sống' : 'Đã mất',
            style: TextStyle(color: member.isAlive ? Colors.green : Colors.grey, fontSize: 12),
          ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
               IconButton(
                 icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                 onPressed: () => _updateMember(member),
               ),
            if (canDelete)
               IconButton(
                 icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                 onPressed: () => _confirmDeleteMember(member),
               ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _showMemberDetails(member),
      ),
    ).animate().fadeIn(delay: 100.ms).slideX();
  }

  bool _canEdit(FamilyMember member) {
    if (_isOwner) return true;
    const allowedTitles = ['Trưởng họ', 'Phó họ', 'Chi trưởng', 'Chi phó'];
    if (_currentUserTitle != null && allowedTitles.contains(_currentUserTitle)) {
      return true;
    }
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

  void _showMemberDetails(FamilyMember member) {
     String fatherName = 'Chưa rõ';
     String motherName = 'Chưa rõ';
     String spouseName = 'Chưa rõ';
     
     if (member.fatherId != null) {
       try {
         fatherName = _members.firstWhere((m) => m.id == member.fatherId).fullName;
       } catch(_) {}
     }
     if (member.motherId != null) {
       try {
         motherName = _members.firstWhere((m) => m.id == member.motherId).fullName;
       } catch(_) {}
     }
     
     // Find Spouse
     if (member.spouseId != null) {
       try {
         spouseName = _members.firstWhere((m) => m.id == member.spouseId).fullName;
       } catch(_) {}
     } else {
       // Search for anyone who has this member as their spouse
       try {
         spouseName = _members.firstWhere((m) => m.spouseId == member.id).fullName;
       } catch(_) {}
     }

     showModalBottomSheet(
       context: context,
       builder: (context) => Container(
         padding: const EdgeInsets.all(24),
         decoration: const BoxDecoration(
           color: Color(0xFFFFF8E1),
           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(member.fullName, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8B1A1A))),
             const Divider(color: Color(0xFF8B1A1A), thickness: 1),
             const SizedBox(height: 8),
             _detailRow(Icons.cake, 'Ngày sinh', member.birthDate?.toString().split(' ')[0] ?? 'Chưa rõ'),
             _detailRow(Icons.info_outline, 'Giới tính', member.gender == 'male' ? 'Nam' : 'Nữ'),
             const SizedBox(height: 8),
             const Text('Quan hệ gia đình:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
             _detailRow(Icons.family_restroom, 'Cha', fatherName),
             _detailRow(Icons.person_outline, 'Mẹ', motherName),
             _detailRow(Icons.favorite, member.gender == 'male' ? 'Vợ' : 'Chồng', spouseName),
             if (member.profileId != null) 
               _detailRow(Icons.verified_user, 'Tài khoản', 'Đã liên kết'),
             const SizedBox(height: 24),
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
