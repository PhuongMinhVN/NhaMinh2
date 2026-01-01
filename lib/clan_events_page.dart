import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClanEventsPage extends StatefulWidget {
  const ClanEventsPage({super.key});

  @override
  State<ClanEventsPage> createState() => _ClanEventsPageState();
}

class _ClanEventsPageState extends State<ClanEventsPage> {
  final _service = EventService();
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _service.getEvents();
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showAddEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    // Local variables for dialog state
    DateTime selectedDate = DateTime.now();
    bool isLunar = true; 
    RecurrenceType recurrence = RecurrenceType.YEARLY; // Default annual
    EventScope scope = EventScope.CLAN; // Default Clan

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Thêm sự kiện'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Tên sự kiện (Vd: Giỗ Tổ)')),
                  const SizedBox(height: 12),
                  
                  // Date Picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ngày: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Chọn ngày'),
                      )
                    ],
                  ),
                  
                  // Lunar Toggle
                  SwitchListTile(
                    title: const Text('Sử dụng Lịch Âm'),
                    subtitle: isLunar ? const Text('Sẽ tự động quy đổi sang Dương lịch') : null,
                    value: isLunar,
                    onChanged: (val) => setStateDialog(() => isLunar = val),
                  ),

                  // Recurrence Dropdown
                  DropdownButtonFormField<RecurrenceType>(
                    value: recurrence,
                    decoration: const InputDecoration(labelText: 'Lặp lại'),
                    items: const [
                       DropdownMenuItem(value: RecurrenceType.YEARLY, child: Text('Hàng năm (Giỗ chạp)')),
                       DropdownMenuItem(value: RecurrenceType.NONE, child: Text('Một lần (Họp mặt)')),
                    ],
                    onChanged: (val) => setStateDialog(() => recurrence = val!),
                  ),
                  
                  // Scope Dropdown
                  DropdownButtonFormField<EventScope>(
                    value: scope,
                    decoration: const InputDecoration(labelText: 'Phạm vi'),
                    items: const [
                       DropdownMenuItem(value: EventScope.CLAN, child: Text('Dòng Họ')),
                       DropdownMenuItem(value: EventScope.FAMILY, child: Text('Gia Đình')),
                    ],
                    onChanged: (val) => setStateDialog(() => scope = val!),
                  ),

                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả/Địa điểm'), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  if (_currentUser == null) return;
                  
                  try {
                    // Re-instantiate clearly
                    await _service.createEvent(Event(
                      id: '', 
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      scope: scope,
                      isLunar: isLunar,
                      day: selectedDate.day,
                      month: selectedDate.month,
                      year: selectedDate.year, // Important for one-time events
                      recurrenceType: recurrence,
                      createdBy: _currentUser!.id,
                      createdAt: DateTime.now(),
                    ));

                    Navigator.pop(context);
                    _loadEvents(); // Reload
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                  }
                },
                child: const Text('Lưu'),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sự Kiện & Giỗ Chạp', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _showAddEventDialog, icon: const Icon(Icons.add_circle_outline))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _events.isEmpty
          ? const Center(child: Text('Chưa có sự kiện nào sắp tới.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return _buildEventCard(event);
              },
            ),
    );
  }

  Widget _buildEventCard(Event event) {
    // Format Display Date
    final date = event.nextOccurrenceSolar ?? DateTime.now();
    String dateDisplay = DateFormat('dd/MM/yyyy').format(date);
    String lunarInfo = '';
    
    if (event.isLunar) {
      lunarInfo = '(Âm lịch: ${event.day}/${event.month})';
    }

    final diff = date.difference(DateTime.now()).inDays;
    final isUrgent = diff <= 7 && diff >= 0;
    
    String timeStatus;
    Color statusColor;
    Color bgColor;

    if (diff < 0) {
      timeStatus = 'Đã qua';
      statusColor = Colors.grey;
      bgColor = Colors.grey.shade100;
    } else if (diff == 0) {
      timeStatus = 'Hôm nay';
      statusColor = Colors.red;
      bgColor = Colors.red.shade50;
    } else {
      timeStatus = 'Còn $diff ngày';
      statusColor = isUrgent ? Colors.orange : Colors.green;
      bgColor = isUrgent ? Colors.orange.shade50 : Colors.green.shade50;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.scope == EventScope.CLAN ? Colors.purple.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: event.scope == EventScope.CLAN ? Colors.purple.shade200 : Colors.blue.shade200)
                          ),
                          child: Text(
                            event.scope == EventScope.CLAN ? 'Dòng Họ' : 'Gia Đình',
                            style: TextStyle(fontSize: 10, color: event.scope == EventScope.CLAN ? Colors.purple : Colors.blue, fontWeight: FontWeight.bold),
                          ),
                       ),
                       const SizedBox(height: 4),
                       Text(
                         event.title, 
                         style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown.shade900)
                       ),
                     ],
                   ),
                 ),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: bgColor,
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: Text(
                     timeStatus,
                     style: TextStyle(
                       color: statusColor,
                       fontWeight: FontWeight.bold,
                       fontSize: 12
                     ),
                   ),
                 )
               ],
             ),
             const SizedBox(height: 8),
             Row(
               children: [
                 Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                 const SizedBox(width: 8),
                 Text(
                   '$dateDisplay $lunarInfo',
                   style: const TextStyle(fontWeight: FontWeight.w600),
                 ),
               ],
             ),
             if (event.description != null && event.description!.isNotEmpty) ...[
               const Divider(height: 24),
               Text(event.description!, style: TextStyle(color: Colors.grey.shade800)),
             ]
          ],
        ),
      ),
    );
  }
}
