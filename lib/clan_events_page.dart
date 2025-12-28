import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../models/clan_event.dart';
import '../repositories/event_repository.dart';

class ClanEventsPage extends StatefulWidget {
  const ClanEventsPage({super.key});

  @override
  State<ClanEventsPage> createState() => _ClanEventsPageState();
}

class _ClanEventsPageState extends State<ClanEventsPage> {
  final _repo = EventRepository();
  List<ClanEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _repo.fetchUpcomingEvents();
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
    final locationCtrl = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    bool isLunar = true; // Mặc định là Âm lịch cho giỗ chạp
    String type = 'annual'; // Mặc định là hàng năm

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Thêm sự kiện dòng họ'),
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
                    subtitle: isLunar ? const Text('Sẽ tự động quy đổi sang Dương lịch hàng năm') : null,
                    value: isLunar,
                    onChanged: (val) => setStateDialog(() => isLunar = val),
                  ),

                  // Type Dropdown
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Loại sự kiện'),
                    items: const [
                       DropdownMenuItem(value: 'annual', child: Text('Hàng năm (Giỗ chạp)')),
                       DropdownMenuItem(value: 'one_time', child: Text('Một lần (Họp mặt)')),
                    ],
                    onChanged: (val) => setStateDialog(() => type = val!),
                  ),
                  
                  TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Địa điểm')),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  try {
                    await _repo.addEvent(
                      titleCtrl.text,
                      selectedDate,
                      isLunar,
                      type,
                      descCtrl.text,
                      locationCtrl.text
                    );
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
        title: Text('Việc Dòng Họ', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
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

  Widget _buildEventCard(ClanEvent event) {
    // Format Display Date
    String dateDisplay = DateFormat('dd/MM/yyyy').format(event.upcomingDate!);
    String lunarInfo = '';
    
    if (event.isLunar) {
      // Show original lunar date
      // Convert stored date to Lunar to show day/month
      final lunar = Lunar.fromDate(event.eventDate); // Assuming stored is lunar-like
      // Or better, just show the day/month from stored date if we treat it as lunar
      lunarInfo = '(Âm lịch: ${event.eventDate.day}/${event.eventDate.month})';
    }

    final isUrgent = event.daysUntil! <= 7;

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
                   child: Text(
                     event.title, 
                     style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown.shade900)
                   ),
                 ),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: isUrgent ? Colors.red.shade100 : Colors.green.shade100,
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: Text(
                     event.daysUntil == 0 ? 'Hôm nay' : 'Còn ${event.daysUntil} ngày',
                     style: TextStyle(
                       color: isUrgent ? Colors.red.shade800 : Colors.green.shade800,
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
             if (event.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(event.location!),
                  ],
                ),
             ],
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
