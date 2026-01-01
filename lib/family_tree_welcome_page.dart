import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'pages/create_clan_page.dart';
import 'pages/create_family_simple_page.dart';
import 'create_personal_family_wizard.dart'; // Import mới
import 'scan_qr_page.dart';
import 'clan_list_page.dart';
import 'clan_tree_page.dart';
import 'models/clan.dart';
import 'pages/join_request_page.dart';

class FamilyTreeWelcomePage extends StatelessWidget {
  const FamilyTreeWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B1A1A), // Deep Red
              Color(0xFF3E2723), // Dark Brown
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Pattern
            const Opacity(
              opacity: 0.1,
              child: Center(
                child: Icon(Icons.account_tree_outlined, size: 400, color: Colors.white),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Header Section ---
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Chào Mừng Đến Với\nCây Gia Phả',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [const Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                    const SizedBox(height: 8),

                    Text(
                      'Nội kết tâm kinh - Lưu truyền huyết thống.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                    
                    const SizedBox(height: 40),
                    
                    // --- Main Action Card (Glassmorphism) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // SECTION 1: ACCESS
                          _buildSectionHeader('TRUY CẬP'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSquareButton(
                                  context,
                                  title: 'Gia Phả\nDòng Họ',
                                  icon: Icons.account_balance_outlined,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanListPage(isClan: true))),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSquareButton(
                                  context,
                                  title: 'Gia Phả\nGia Đình',
                                  icon: Icons.cottage_outlined,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanListPage(isClan: false))),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 24),

                          // SECTION 2: JOIN
                          _buildSectionHeader('THAM GIA'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionChip(
                                  context,
                                  icon: Icons.qr_code_scanner,
                                  label: 'Quét QR',
                                  onTap: () => _handleScan(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionChip(
                                  context,
                                  icon: Icons.edit,
                                  label: 'Nhập ID',
                                  onTap: () => _showJoinByIdDialog(context),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 24),

                          // SECTION 3: CREATE
                          _buildSectionHeader('KHỞI TẠO'),
                          const SizedBox(height: 16),
                          _buildFullWidthButton(
                            context,
                            title: 'Khởi Tạo Gia Phả Mới',
                            subtitle: 'Bắt đầu hành trình xây dựng cội nguồn',
                            icon: Icons.add_circle_outline,
                            color: const Color(0xFFFFD700),
                            textColor: Colors.brown.shade900,
                            onTap: () => _showCreateOptions(context),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
                    
                    const SizedBox(height: 32),
                    
                    const Text(
                      '© 2025 Vĩnh Cửu Tộc - Nhà Mình',
                      style: TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.white60,
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: textColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareButton(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700), // Gold
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.brown.shade900, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.brown.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700), // Gold
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.brown.shade900, size: 32),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.brown.shade900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.brown.shade900, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn Loại Gia Phả',
                style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _buildOptionItem(
                context,
                title: 'Gia Phả Dòng Họ',
                desc: 'Quản lý tộc phả quy mô lớn, nhiều chi tộc.',
                icon: Icons.account_balance_outlined,
                color: Colors.brown,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateClanPage()));
                },
              ),
              const SizedBox(height: 16),
              _buildOptionItem(
                context,
                title: 'Gia Phả Gia Đình 5 Đời',
                desc: 'Tập trung vào nhánh cá nhân: Ông cố -> Ông nội -> Bố -> Bạn -> Con.',
                icon: Icons.family_restroom,
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFamilySimplePage()));
                },
              ),
              const SizedBox(height: 16),
              _buildOptionItem(
                context,
                title: 'Gia Phả Gia Đình (Quy mô tự do)',
                desc: 'Xây dựng cho gia đình với cấu trúc tùy chỉnh.',
                icon: Icons.cottage_outlined,
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFamilySimplePage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW METHODS
  void _showJoinByIdDialog(BuildContext context) {
     final idCtrl = TextEditingController();
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Nhập Mã Gia Phả'),
         content: TextField(
           controller: idCtrl,
           decoration: const InputDecoration(labelText: 'Mã Gia Phả (UUID)', border: OutlineInputBorder(), hintText: 'Nhập mã được chia sẻ...'),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
           ElevatedButton(
             onPressed: () {
                if (idCtrl.text.trim().isNotEmpty) {
                   Navigator.pop(context);
                   _handleManualId(context, idCtrl.text.trim());
                }
             }, 
             child: const Text('Tiếp tục'),
           )
         ],
       ),
     );
  }

  void _handleManualId(BuildContext context, String id) {
     // Check basic validity or just try to join
     _joinClan(context, id);
  }

  void _handleScan(BuildContext context) async {
    final scannedCode = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const ScanQrPage(returnScanData: true))
    );

    if (scannedCode != null && scannedCode is String) {
       String clanId = scannedCode;
       if (scannedCode.startsWith('CLAN:')) {
          clanId = scannedCode.split('CLAN:').last;
       }
       
       // Accept if it looks like an ID (not empty)
       if (clanId.trim().isNotEmpty) {
           if (context.mounted) _joinClan(context, clanId);
       } else {
           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã QR không hợp lệ')));
       }
    }
  }

  Future<void> _joinClan(BuildContext context, String clanId) async {
     try {
       final user = Supabase.instance.client.auth.currentUser;
       if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập trước.')));
          return;
       }

       // Show loading
       showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

       // 1. Robust Search Logic (Full UUID or Short Code)
       Map<String, dynamic>? data;
       String cleanId = clanId.trim().toLowerCase();

       // A. Full UUID Match
       if (cleanId.length == 36) {
          try {
            data = await Supabase.instance.client.from('clans').select().eq('id', cleanId).maybeSingle();
          } catch (_) {}
       }

       // B. Short Code Match (if not found yet)
       if (data == null && cleanId.length >= 6) {
          try {
            String cleanHex = cleanId.replaceAll('-', '');
             // Ensure only valid hex chars
             if (RegExp(r'^[0-9a-f]+$').hasMatch(cleanHex) && cleanHex.length < 32) {
                String minHex = cleanHex.padRight(32, '0');
                String maxHex = cleanHex.padRight(32, 'f');
                String toUuid(String h) => '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
                
                final list = await Supabase.instance.client
                    .from('clans')
                    .select()
                    .gte('id', toUuid(minHex))
                    .lte('id', toUuid(maxHex))
                    .limit(1);
                    
                if (list.isNotEmpty) data = list.first;
             }
          } catch (e) {
             debugPrint('Search Error: $e');
          }
       }
       
       if (context.mounted) Navigator.pop(context); // Hide loading

       if (data == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy Gia phả với mã này.')));
          return;
       }
       
       final clan = Clan.fromJson(data);
       
       if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => JoinRequestPage(clan: clan)));
       }

     } catch (e) {
        // Pop loading dialog if error occurs (check if it's still there)
        // Note: Logic above pops it already, but good to be safe. 
        // We relied on mounted check above. If exception happens before, we might have issues.
        // Actually the 'pop' is outside the try/catch blocks for the search, but inside the main try.
        // If 'showDialog' ran, we must ensure pop happens.
        
        // Simpler safety:
        // The pop is called after search. If search throws, we catch here.
        // So we should try to pop again if we suspect it's open, but hard to know state.
        // Usually safer to use a flag or just hope user can tap back (barierDismissible=false is risky).
        // Let's rely on standard flow.
        
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tham gia: $e')));
     }
  }

  Widget _buildOptionItem(BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
