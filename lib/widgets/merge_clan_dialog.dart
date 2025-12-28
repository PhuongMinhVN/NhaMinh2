import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/merge_service.dart';
import '../scan_qr_page.dart';

class MergeClanDialog extends StatefulWidget {
  final String sourceClanId;
  final String sourceClanName;

  const MergeClanDialog({super.key, required this.sourceClanId, required this.sourceClanName});

  @override
  State<MergeClanDialog> createState() => _MergeClanDialogState();
}

class _MergeClanDialogState extends State<MergeClanDialog> {
  final TextEditingController _targetIdController = TextEditingController();
  final MergeService _mergeService = MergeService();
  
  bool _isLoading = false;
  String? _analysisStatus;
  
  Map<String, dynamic>? _targetClanInfo;

  void _scanQr() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const ScanQrPage())
    );
    if (result != null && result is String) {
      setState(() {
        _targetIdController.text = result;
      });
      _fetchTargetInfo(result);
    }
  }

  void _fetchTargetInfo(String id) async {
    id = id.trim();
    if (id.isEmpty) return;
    
    try {
      // 1. Try Exact Match (Only if it looks like a full UUID)
      var res;
      if (id.length == 36) {
         try {
           res = await Supabase.instance.client
            .from('clans')
            .select()
            .eq('id', id)
            .maybeSingle();
         } catch (_) {}
      }
      
      // 2. If not found and len >= 6, try Prefix Match (Short ID)
      if (res == null && id.length >= 6) {
         try {
           // Construct valid UUID range for prefix
           // UUID format: 8-4-4-4-12 (32 hex digits + 4 hyphens = 36)
           // If user enters '1451E9' (6 digits)
           // Min: 1451E900-0000-0000-0000-000000000000
           // Max: 1451E9ff-ffff-ffff-ffff-ffffffffffff
           
           String cleanHex = id.replaceAll('-', '');
           if (cleanHex.length < 32) {
              String minHex = cleanHex.padRight(32, '0');
              String maxHex = cleanHex.padRight(32, 'f');
              
              String toUuid(String h) => '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
              
              String minUuid = toUuid(minHex);
              String maxUuid = toUuid(maxHex);
              
              final list = await Supabase.instance.client
                .from('clans')
                .select()
                .gte('id', minUuid)
                .lte('id', maxUuid)
                .limit(1);
              if (list.isNotEmpty) res = list.first;
           }
         } catch (e) {
            debugPrint('Prefix search error: $e');
         }
      }
      
      if (res != null) {
        setState(() {
          _targetClanInfo = res;
          // If it was a short ID match, might want to update the controller to full ID relative to user expectation?
          // But keep it simple. We store the FULL ID for merge.
          // IMPORTANT: Update local var, but _performMerge needs the FULL ID.
          // Store it in a hidden way or just use _targetClanInfo['id']
        });
      } else {
        setState(() => _targetClanInfo = null);
        // Only show error if explicitly checking?
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _performMerge() async {
    if (_targetClanInfo == null) return;
    final targetId = _targetClanInfo!['id'] as String;
    
    if (targetId == widget.sourceClanId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gộp vào chính nó')));
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisStatus = 'Đang phân tích và gộp dữ liệu...';
    });

    try {
      final result = await _mergeService.mergeClans(
        sourceClanId: widget.sourceClanId,
        targetClanId: targetId,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); // Close dialog
        
        // Show Success Dialog
        showDialog(
          context: context, 
          builder: (c) => AlertDialog(
            title: const Text('Gộp thành công!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã thêm mới: ${result.addedCount} thành viên'),
                Text('Đã liên kết (trùng): ${result.skippedCount} thành viên'),
                Text('Đã cập nhật quan hệ: ${result.linkedCount} thành viên'),
                if (result.errors.isNotEmpty) ...[
                   const SizedBox(height: 8),
                   const Text('Lỗi:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                   ...result.errors.map((e) => Text('- $e', style: const TextStyle(fontSize: 12))),
                ]
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng'))
            ],
          )
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _analysisStatus = 'Lỗi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gộp vào Dòng họ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn đang gộp dữ liệu từ: ${widget.sourceClanName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Nhập Mã hoặc QR Dòng họ đích:'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID Dòng họ đích',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                       if (v.length > 5) _fetchTargetInfo(v);
                    },
                  ),
                ),
                IconButton(onPressed: _scanQr, icon: const Icon(Icons.qr_code_scanner)),
              ],
            ),
            if (_targetClanInfo != null) ...[
               const SizedBox(height: 12),
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                 child: Row(
                   children: [
                     const Icon(Icons.check_circle, color: Colors.green),
                     const SizedBox(width: 8),
                     Expanded(child: Text('Đích: ${_targetClanInfo!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                   ],
                 ),
               ),
            ],
            if (_analysisStatus != null) ...[
               const SizedBox(height: 16),
               Text(_analysisStatus!, style: TextStyle(color: _analysisStatus!.startsWith('Lỗi') ? Colors.red : Colors.blue)),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(
          onPressed: (_isLoading || _targetClanInfo == null) ? null : _performMerge,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Tiến hành Gộp'),
        ),
      ],
    );
  }
}
