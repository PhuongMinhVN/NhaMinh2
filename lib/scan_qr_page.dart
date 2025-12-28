import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../repositories/clan_repository.dart';
import '../models/clan.dart';

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
      final clan = await _repo.getClanByQrCode(code);
      if (!mounted) return;

      if (clan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã QR không hợp lệ hoặc không tìm thấy dòng họ.'))
        );
        _resumeScanning();
        return;
      }

      _showJoinDialog(clan);

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
         _resumeScanning();
      }
    }
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    _controller.start();
  }

  void _showJoinDialog(Clan clan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tìm thấy Dòng họ'),
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
            const Text('Bạn có muốn gửi yêu cầu gia nhập dòng họ này không?'),
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
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _sendRequest(clan);
            },
            child: const Text('Gửi yêu cầu'),
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
      appBar: AppBar(title: const Text('Quét mã QR Dòng Họ')),
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
