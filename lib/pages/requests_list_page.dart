import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/clan_repository.dart';

class RequestsListPage extends StatefulWidget {
  final String clanId;
  const RequestsListPage({super.key, required this.clanId});

  @override
  State<RequestsListPage> createState() => _RequestsListPageState();
}

class _RequestsListPageState extends State<RequestsListPage> {
  final _repo = ClanRepository();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final data = await _repo.fetchPendingRequests(widget.clanId);
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleApprove(String id) async {
    await _performAction(id, true);
  }

  Future<void> _handleReject(String id) async {
    await _performAction(id, false);
  }

  Future<void> _performAction(String id, bool isApprove) async {
    try {
       setState(() => _isLoading = true);
       if (isApprove) {
         await _repo.approveRequest(id);
       } else {
         await _repo.rejectRequest(id);
       }
       await _fetchRequests();
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isApprove ? 'Đã duyệt yêu cầu' : 'Đã từ chối yêu cầu'), 
            backgroundColor: isApprove ? Colors.green : Colors.red
          ));
       }
    } catch (e) {
       if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yêu Cầu Gia Nhập', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
         ? const Center(child: CircularProgressIndicator())
         : _requests.isEmpty 
              ? const Center(child: Text('Không có yêu cầu nào chờ duyệt.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final profile = req['requester_profile'] as Map<String, dynamic>?;
                    final name = profile?['full_name'] ?? 'Unknown';
                    final email = profile?['email'] ?? '';
                    final meta = req['metadata'] as Map<String, dynamic>? ?? {};
                    final type = req['type'] ?? 'claim_existing';
                    
                    String title = 'Yêu cầu từ $name';
                    if (email.isNotEmpty) title += ' ($email)';
                    String subtitle = '';

                    if (type == 'claim_existing') {
                       subtitle = 'Muốn nhận hồ sơ ID: ${meta['member_id']} là chính mình.';
                    } else if (type == 'create_new') {
                       final relation = meta['relation'] == 'child' ? 'Con' : 'Vợ/Chồng';
                       subtitle = 'Muốn tạo hồ sơ mới:\nTên: ${meta['full_name']}\nQuan hệ: $relation của ID ${meta['relative_id']}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _handleReject(req['id']),
                                  child: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _handleApprove(req['id']),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  child: const Text('Phê duyệt'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
