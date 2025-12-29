import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'create_genealogy_wizard.dart';
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8B1A1A), // Deep Red
              const Color(0xFF3E2723), // Dark Brown
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Pattern
            Opacity(
              opacity: 0.1,
              child: Center(
                child: Icon(Icons.account_tree_outlined, size: 400, color: Colors.white),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration / Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 40),
                    
                    // Text Content
                    Text(
                      'Chào Mừng Đến Với\nCây Gia Phả',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Nội kết tâm kinh - Lưu truyền huyết thống.\nHãy bắt đầu hành trình tìm về nguồn cội.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                    
                    const SizedBox(height: 64),
                    
                    // Action Row (50:50)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSquareButton(
                            context,
                            title: 'Gia Phả\nDòng Họ',
                            icon: Icons.account_balance_outlined,
                            onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanListPage(isClan: true)));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSquareButton(
                            context,
                            title: 'Gia Phả\nGia Đình',
                            icon: Icons.cottage_outlined,
                            onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanListPage(isClan: false)));
                            },
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),
                    
                    const SizedBox(height: 16),
                    
                  // Join Options Row (50:50)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _handleScan(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                                const SizedBox(height: 8),
                                Text('Quét QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showJoinByIdDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 28),
                                const SizedBox(height: 8),
                                Text('Nhập ID', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
                    const SizedBox(height: 16),
                    
                    // CLAN FUNDS BUTTON (Moved from Dashboard)
                    _buildSecondaryButton(
                      context,
                      title: 'Quỹ Dòng Họ',
                      subtitle: 'Đóng góp và chi tiêu',
                      icon: Icons.savings_rounded,
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển')));
                      },
                    ).animate().fadeIn(delay: 850.ms).slideY(begin: 0.3),

                    const SizedBox(height: 16),
                    
                    // Khởi tạo gia phả (Replacing Join button)
                    _buildSecondaryButton(
                      context,
                      title: 'Khởi Tạo Gia Phả Mới',
                      subtitle: 'Xây dựng từ Cửu Tộc (9 đời)',
                      icon: Icons.create_new_folder_outlined,
                      onTap: () {
                         _showCreateOptions(context);
                      },
                    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3),
                    
                    const SizedBox(height: 32),
                    
                    Text(
                      '© 2025 Vĩnh Cửu Tộc - Nhà Mình',
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGenealogyWizard(isClan: true)));
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePersonalFamilyWizard()));
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGenealogyWizard(isClan: false)));
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

       // 1. Fetch Clan
       final data = await Supabase.instance.client.from('clans').select().eq('id', clanId).maybeSingle();
       
       if (context.mounted) Navigator.pop(context); // Hide loading

       if (data == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy Gia phả này.')));
          return;
       }
       
       final clan = Clan.fromJson(data);
       
       if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => JoinRequestPage(clan: clan)));
       }

     } catch (e) {
        // Pop loading dialog if error occurs
        if (context.mounted) Navigator.pop(context); 
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
