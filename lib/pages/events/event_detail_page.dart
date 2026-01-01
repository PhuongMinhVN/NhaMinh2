import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For auth check
import 'package:flutter/services.dart'; // For Clipboard
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'add_event_page.dart'; // Added import
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

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    
    // Get latest participants
    final participants = await _participantsFuture;
    final dateStr = widget.event.nextOccurrenceSolar != null 
        ? DateFormat('dd/MM/yyyy').format(widget.event.nextOccurrenceSolar!) 
        : 'Chưa xác định';

    // Font support for Vietnamese is tricky in PDF. 
    // Usually need to load a custom font. For simplicity in this demo, 
    // we assume standard font or try to load one. 
    // Printing package standard fonts might miss specific VN chars.
    // Ideally we load a font asset.
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('CHI TIẾT SỰ KIỆN', style: pw.TextStyle(font: fontBold, fontSize: 24)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Tiêu đề: ${widget.event.title}', style: pw.TextStyle(font: font, fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Text('Thời gian: $dateStr ${widget.event.isLunar ? "(Dương lịch) - [${widget.event.day}/${widget.event.month} Âm]" : ""}', style: pw.TextStyle(font: font, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text('Phạm vi: ${widget.event.scope == EventScope.FAMILY ? "Gia Đình" : "Dòng Họ"}', style: pw.TextStyle(font: font, fontSize: 14)),
              if (widget.event.description != null) ...[
                pw.SizedBox(height: 10),
                pw.Text('Mô tả: ${widget.event.description}', style: pw.TextStyle(font: font, fontSize: 14)),
              ],
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('DANH SÁCH THAM GIA', style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(font: fontBold),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: <String>['STT', 'Tên thành viên', 'Vai trò', 'Trạng thái'],
                data: List<List<String>>.generate(
                  participants.length,
                  (index) {
                    final p = participants[index];
                    String status = 'Chờ xác nhận';
                    if (p.status == ParticipantStatus.ACCEPTED) status = 'Tham gia';
                    if (p.status == ParticipantStatus.REJECTED) status = 'Từ chối';
                    
                    String role = 'Tham dự';
                    if (p.role == ParticipantRole.ASSIGNEE) role = 'Được giao việc';

                    return [
                      (index + 1).toString(),
                      p.userFullName ?? 'Ẩn danh',
                      role,
                      status
                    ];
                  },
                ),
              ),
              if (participants.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text('Chưa có thành viên nào đăng ký.', style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic)),
                )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'SuKien_${widget.event.title}.pdf',
    );
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
          // Edit button for creator
          if (widget.event.createdBy == _userId)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Chỉnh sửa sự kiện',
              onPressed: () async {
                 // Convert existing event to AddEventPage for editing
                 
                 // Import AddEventPage first if not present
                 // Assuming it's in '../../pages/events/add_event_page.dart' which is same dir relative to detail page which is deeper? No, detail is in pages/events too.
                 
                 final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEventPage(event: widget.event)),
                 );
                 
                 if (result == true) {
                    // Refresh details?
                    // Ideally we should reload the event. 
                    // But EventDetailPage receives 'Event' in constructor. 
                    // We might need to fetch updated event or just pop back to list to refresh.
                    // For now, let's pop with result true so list refreshes.
                    if (mounted) Navigator.pop(context, true);
                 }
              },
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Xuất PDF',
            onPressed: _exportPdf,
          ),
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
            _buildInfoRow(
              Icons.calendar_today, 
              'Thời gian', 
              widget.event.isLunar 
                  ? '$dateStr (Dương lịch)\nNgày gốc: ${widget.event.day}/${widget.event.month} (Âm lịch)'
                  : '$dateStr'
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.description, 'Mô tả', widget.event.description ?? "Không có mô tả chi tiết."),
             const SizedBox(height: 16),
            _buildInfoRow(Icons.loop, 'Lặp lại', widget.event.recurrenceType == RecurrenceType.YEARLY ? "Hàng năm" : "Một lần"),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Participants Section
            // Always show attendance for all events as requested
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
