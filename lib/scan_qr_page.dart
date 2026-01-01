import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/clan_repository.dart';
import '../models/clan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/join_request_page.dart';
import 'widgets/add_member_from_qr_dialog.dart';

class ScanQrPage extends StatefulWidget {
  final bool returnScanData; 

  const ScanQrPage({super.key, this.returnScanData = false});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController();
  final _repo = ClanRepository();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        _controller.stop(); // Pause scanning
        
        await _handleQrCode(barcode.rawValue!);
        break; 
      }
    }
  }

  Future<void> _handleQrCode(String code) async {
    if (widget.returnScanData) {
      if (!mounted) return;
      Navigator.pop(context, code);
      return;
    }

    try {
      // 1. Check for CLAN Code "CLAN:xxx" or legacy QrCode col
      Clan? clan;
      if (code.startsWith('CLAN:')) {
        final clanId = code.substring(5);
        clan = await _repo.getClanById(clanId);
      } else {
        // Could be a Clan Code OR a User UUID
        // Try as Clan Code first
        clan = await _repo.getClanByQrCode(code);
      }
      
      if (clan != null) {
         // --- FOUND CLAN ---
         if (!mounted) return;
         _showJoinDialog(clan, isClan: clan.type == 'clan');
         return;
      }

      // 2. Not a Clan? Check if it is a User UUID (36 chars)
      // Basic UUID regex or length check
      if (code.length == 36) { // Simple check
         await _handleUserQr(code);
         return;
      }
      
      // If nothing found
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã QR không hợp lệ hoặc không tìm thấy.'))
      );
      _resumeScanning();

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
         _resumeScanning();
      }
    }
  }

  Future<void> _handleUserQr(String userId) async {
     // Fetch profile
     final profile = await Supabase.instance.client
         .from('profiles')
         .select()
         .eq('id', userId)
         .maybeSingle();

     if (!mounted) return;

     if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy người dùng này.')));
        _resumeScanning();
        return;
     }

     // Use dialog to Add Member
     // Need to know WHICH clan we are adding to.
     // Ideally, we should be in a context of a clan.
     // However, Scan page is global.
     // So we must fetch the user's current clans and ask which one to add to?
     // OR: Just assume the user has one clan for now. 
     // Let's fetch my clans.
     
     final myClans = await _repo.fetchMyClans(); // Need to implement/expose this fetch
     
     if (myClans.isEmpty) {
        // I don't have a clan to add them to!
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chưa có gia phả nào để thêm thành viên.')));
        _resumeScanning();
        return;
     }
     
     // If multiple clans, maybe pick first or ask? 
     // For MPV, let's pick the first one owned by me.
     final targetClan = myClans.first; // Simplified
     
     // Show Add Dialog
     final result = await showDialog(
       context: context, 
       builder: (_) => AddMemberFromQrDialog(
          scannedProfile: profile, 
          currentClanId: targetClan.id
       )
     );
     
     if (result == true) {
        if (mounted) Navigator.pop(context); // Close Scan Page on success
     } else {
        _resumeScanning();
     }
  }
  
  // Imported AddMemberFromQrDialog needs to be added to top imports


  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) {
      _resumeScanning();
      return;
    }
    
    // Analyze image for QR
    // MobileScanner 3.x+ supports analyzeImage
    try {
      final barcodes = await _controller.analyzeImage(image.path);
      if (barcodes != null && barcodes.barcodes.isNotEmpty) {
          final code = barcodes.barcodes.first.rawValue;
          if (code != null) {
             _handleQrCode(code);
             return;
          }
      }
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy mã QR trong ảnh.')));
         _resumeScanning();
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi quét ảnh: $e')));
         _resumeScanning();
      }
    }
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    _controller.start();
  }

  void _showJoinDialog(Clan clan, {required bool isClan}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isClan ? 'Tìm thấy Dòng họ' : 'Tìm thấy Gia đình'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tên: ${clan.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (clan.description != null) ...[
              const SizedBox(height: 8),
              Text('Mô tả: ${clan.description}'),
            ],
            const SizedBox(height: 16),
            const Text('Vui lòng xác thực danh tính của bạn trong gia phả để tiếp tục.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to Join Request Page
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => JoinRequestPage(clan: clan))
              ).then((_) {
                 // When returning, resume scanning if needed? Usually we pop back to dashboard from there.
                 // But if they back out:
                 // _resumeScanning(); // Maybe?
              });
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(Clan clan) async {
    try {
      await _repo.requestJoinClan(clan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi yêu cầu đến dòng họ ${clan.name}. Vui lòng chờ phê duyệt.'))
        );
        Navigator.pop(context); // Go back to FamilyTreePage
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        _resumeScanning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
      width: 250,
      height: 250,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR Dòng Họ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Chọn ảnh từ thư viện',
            onPressed: () {
               _controller.stop();
               _pickImageFromGallery();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            scanWindow: scanWindow,
          ),
          // Scanner Overlay (The "QR Box")
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  _buildCorner(0, 0, top_: true, left_: true),
                  _buildCorner(0, null, top_: true, right: true),
                  _buildCorner(null, 0, bottom: true, left_: true),
                  _buildCorner(null, null, bottom: true, right: true),
                ],
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Text('Di chuyển mã QR vào giữa khung hình', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(double? top, double? left, {bool top_ = false, bool left_ = false, bool right = false, bool bottom = false}) {
     // Simplifying corner building
     return Positioned(
       top: top_ ? 0 : null,
       bottom: bottom ? 0 : null,
       left: left_ ? 0 : null,
       right: right ? 0 : null,
       child: Container(
         width: 20,
         height: 20,
         decoration: BoxDecoration(
           border: Border(
             top: top_ ? const BorderSide(color: Colors.red, width: 4) : BorderSide.none,
             bottom: bottom ? const BorderSide(color: Colors.red, width: 4) : BorderSide.none,
             left: left_ ? const BorderSide(color: Colors.red, width: 4) : BorderSide.none,
             right: right ? const BorderSide(color: Colors.red, width: 4) : BorderSide.none,
           ),
         ),
       ),
     );
  }
}
