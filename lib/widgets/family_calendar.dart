import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class FamilyCalendar extends StatefulWidget {
  final String clanId;
  const FamilyCalendar({super.key, required this.clanId});

  @override
  State<FamilyCalendar> createState() => _FamilyCalendarState();
}

class _FamilyCalendarState extends State<FamilyCalendar> {
  final _service = EventService();
  final String _myId = Supabase.instance.client.auth.currentUser!.id;
  Future<List<Event>>? _eventsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _eventsFuture = _service.getEventsByClan(widget.clanId);
    });
  }

  Future<void> _createEvent(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    EventCategory category = EventCategory.ANNIVERSARY;
    RecurrenceType recurrence = RecurrenceType.YEARLY;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tạo sự kiện gia đình'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Tên sự kiện (VD: Giỗ cụ Tổ)'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Chi tiết (Địa điểm, ghi chú)'),
                  maxLines: 2,
                ),
                DropdownButtonFormField<EventCategory>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: EventCategory.ANNIVERSARY, child: Text('Giỗ Chạp')),
                    DropdownMenuItem(value: EventCategory.WEDDING, child: Text('Hỷ (Cưới hỏi)')),
                    DropdownMenuItem(value: EventCategory.FUNERAL, child: Text('Hiếu (Tang lễ)')),
                    DropdownMenuItem(value: EventCategory.OTHER, child: Text('Khác')),
                  ],
                  onChanged: (v) => setStateDialog(() => category = v!),
                  decoration: const InputDecoration(labelText: 'Loại sự kiện'),
                ),
                
                DropdownButtonFormField<RecurrenceType>(
                   value: recurrence,
                   items: const [
                     DropdownMenuItem(value: RecurrenceType.YEARLY, child: Text('Hàng Năm')),
                     DropdownMenuItem(value: RecurrenceType.NONE, child: Text('Một Lần')),
                   ],
                   onChanged: (v) => setStateDialog(() => recurrence = v!),
                   decoration: const InputDecoration(labelText: 'Lặp lại'),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Ngày dự kiến: '),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setStateDialog(() => selectedDate = d);
                        }
                      },
                      child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                try {
                  await _service.createEvent(Event(
                    id: '',
                    title: titleController.text,
                    description: descController.text,
                    scope: EventScope.CLAN,
                    clanId: widget.clanId,
                    category: category,
                    recurrenceType: recurrence,
                    day: selectedDate.day,
                    month: selectedDate.month,
                    year: selectedDate.year,
                    isLunar: false, // Simple MVP default, could add toggle
                    createdBy: _myId,
                    createdAt: DateTime.now(),
                  ));

                  if (mounted) Navigator.pop(ctx);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo sự kiện')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              },
              child: const Text('Tạo Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetail(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EventDetailSheet(event: event, clanId: widget.clanId, currentUserId: _myId),
    );
  }

  Color _getEventColor(EventCategory cat) {
    switch (cat) {
      case EventCategory.ANNIVERSARY: return Colors.amber.shade900;
      case EventCategory.WEDDING: return Colors.red;
      case EventCategory.FUNERAL: return Colors.grey.shade800;
      default: return Colors.blue;
    }
  }

  IconData _getEventIcon(EventCategory cat) {
    switch (cat) {
      case EventCategory.ANNIVERSARY: return Icons.local_fire_department;
      case EventCategory.WEDDING: return Icons.favorite;
      case EventCategory.FUNERAL: return Icons.spa;
      default: return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lịch Gia Đình', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                onPressed: () => _createEvent(context),
                tooltip: 'Thêm sự kiện',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Event>>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return Center(child: Text('Chưa có sự kiện nào.', style: GoogleFonts.playfairDisplay(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final e = events[index];
                  final date = e.nextOccurrenceSolar ?? DateTime.now();
                  
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _getEventColor(e.category).withOpacity(0.3))),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getEventColor(e.category).withOpacity(0.1),
                        child: Icon(_getEventIcon(e.category), color: _getEventColor(e.category)),
                      ),
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(date)),
                          if (e.description != null) Text(e.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => _showEventDetail(e),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventDetailSheet extends StatefulWidget {
  final Event event;
  final String clanId;
  final String currentUserId;

  const _EventDetailSheet({required this.event, required this.clanId, required this.currentUserId});

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  final _service = EventService();
  bool _isJoined = false;
  // Participants logic can be added later or reuse same table if migrated
  // For MVP, we use the new `event_participants` table if EventService has support,
  // Or simply hide participants if table `clan_events` migration dropped it data.
  // Assuming `event_participants` is linked to `events` table (Yes, foreign key to event_id).
  
  List<dynamic> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    try {
      final parts = await _service.getParticipants(widget.event.id);
      
      setState(() {
        _participants = parts.map((p) => {
          'profiles': {'full_name': p.userFullName ?? 'Ẩn danh'},
          // joined_at is not in the model, using pending concept or now
          'joined_at': DateTime.now().toIso8601String(), 
          'user_id': p.userId
        }).toList();
        
        _isJoined = parts.any((p) => p.userId == widget.currentUserId);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleJoin() async {
    // Implement using EventService
    // For now, this is visual only as EventService addParticipant logic is basic
  }

  Future<void> _exportPdf() async {
    // ... Copy PDF logic from previous or simplify
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = widget.event.nextOccurrenceSolar ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(child: Text(widget.event.title, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold))),
               IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Ngày: ${DateFormat('dd/MM/yyyy').format(displayDate)}', style: const TextStyle(fontSize: 16)),
          if (widget.event.description != null) ...[
             const SizedBox(height: 12),
             Text(widget.event.description!, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          ],
          const Spacer(),
          SizedBox(
             width: double.infinity,
             child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          )
        ],
      ),
    );
  }
}
