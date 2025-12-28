import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For auth check
import 'package:flutter/services.dart'; // For Clipboard
import '../../models/event_model.dart';
import '../../models/event_participant_model.dart';
import '../../services/event_service.dart';

class EventDetailPage extends StatefulWidget {
  final Event event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventService = EventService();
  final _userId = Supabase.instance.client.auth.currentUser?.id;
  
  // Future state
  late Future<List<EventParticipant>> _participantsFuture;
  
  @override
  void initState() {
    super.initState();
    _participantsFuture = _eventService.getParticipants(widget.event.id);
  }

  void _copyToClipboard() {
    // Generate text summary
    final date = widget.event.nextOccurrenceSolar != null 
        ? DateFormat('dd/MM/yyyy').format(widget.event.nextOccurrenceSolar!) 
        : 'Chưa xác định';
        
    final text = '''
=== THÔNG BÁO SỰ KIỆN ===
Tiêu đề: ${widget.event.title}
Phân loại: ${widget.event.scope == EventScope.FAMILY ? "Việc Gia Đình" : "Việc Dòng Họ"}
Thời gian: $date (${widget.event.isLunar ? "Âm lịch" : "Dương lịch"})
Địa điểm/Mô tả: ${widget.event.description ?? "Không có mô tả"}

Vui lòng xác nhận tham gia trên ứng dụng "Việc Họ".
=========================
    ''';
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung sự kiện vào bộ nhớ tạm!')),
    );
  }

  Future<void> _joinEvent() async {
    if (_userId == null) return;
    try {
      await _eventService.addParticipant(widget.event.id, _userId!, ParticipantRole.ATTENDEE);
      // Refresh
      setState(() {
        _participantsFuture = _eventService.getParticipants(widget.event.id);
      });
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng ký tham gia!')));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display Date
    final dateStr = widget.event.nextOccurrenceSolar != null 
      ? DateFormat('dd/MM/yyyy').format(widget.event.nextOccurrenceSolar!) 
      : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Sự Kiện'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép nội dung',
            onPressed: _copyToClipboard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event, size: 32, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                       Chip(
                          label: Text(widget.event.scope == EventScope.FAMILY ? "Gia Đình" : "Dòng Họ"),
                          backgroundColor: widget.event.scope == EventScope.FAMILY ? Colors.blue[50] : Colors.purple[50],
                          labelStyle: TextStyle(color: widget.event.scope == EventScope.FAMILY ? Colors.blue : Colors.purple),
                        ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // Info Cards
            _buildInfoRow(Icons.calendar_today, 'Thời gian', '$dateStr ${widget.event.isLunar ? "(Âm lịch)" : ""}'),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.description, 'Mô tả', widget.event.description ?? "Không có mô tả chi tiết."),
             const SizedBox(height: 16),
            _buildInfoRow(Icons.loop, 'Lặp lại', widget.event.recurrenceType == RecurrenceType.YEARLY ? "Hàng năm" : "Một lần"),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Participants Section
            if (widget.event.requiresAttendance) ...[
              Text(
                'Danh sách tham gia',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<EventParticipant>>(
                future: _participantsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final parts = snapshot.data ?? [];
                  
                  // Check if current user joined
                  final isJoined = parts.any((p) => p.userId == _userId);
                  
                  return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       if (!isJoined)
                         Padding(
                           padding: const EdgeInsets.only(bottom: 16),
                           child: ElevatedButton.icon(
                             onPressed: _joinEvent,
                             icon: const Icon(Icons.check),
                             label: const Text('Xác nhận tham gia'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white
                             ),
                           ),
                         ),
                       
                       if (parts.isEmpty) 
                         const Text('Chưa có ai đăng ký tham gia.', style: TextStyle(fontStyle: FontStyle.italic)),
                         
                       ...parts.map((p) => ListTile(
                         leading: CircleAvatar(
                           backgroundImage: p.userAvatarUrl != null ? NetworkImage(p.userAvatarUrl!) : null,
                           child: p.userAvatarUrl == null ? const Icon(Icons.person) : null,
                         ),
                         title: Text(p.userFullName ?? 'Thành viên'),
                         subtitle: Text(p.role == ParticipantRole.ASSIGNEE ? 'Được giao việc' : 'Tham dự'),
                         trailing: p.status == ParticipantStatus.ACCEPTED 
                             ? const Icon(Icons.check_circle, color: Colors.green)
                             : const Icon(Icons.hourglass_empty, color: Colors.orange),
                       )).toList(),
                     ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
