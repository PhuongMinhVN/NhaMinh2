import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';

class AddEventPage extends StatefulWidget {
  final Event? event; // Optional event for editing
  
  const AddEventPage({super.key, this.event});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  // Default values
  EventScope _scope = EventScope.CLAN; // Default per request
  EventCategory _category = EventCategory.OTHER;
  bool _isLunar = true;
  bool _isRecurring = true;
  bool _requiresAttendance = false;
  bool _isImportant = false;
  
  // Date Selection
  int _day = DateTime.now().day;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  bool _isLoading = false;
  final _eventService = EventService();
  
  List<Map<String, dynamic>> _clanOptions = []; // List of clans type='cla'
  List<Map<String, dynamic>> _familyOptions = []; // List of clans type='family'
  String? _selectedEntityId; // Selected ID (either clan or family)

  @override
  void initState() {
    super.initState();
    _fetchEntities();
    
    if (widget.event != null) {
      // Populate fields for editing
      _titleController.text = widget.event!.title;
      _descController.text = widget.event!.description ?? '';
      _scope = widget.event!.scope;
      _category = widget.event!.category;
      _isLunar = widget.event!.isLunar;
      _isRecurring = widget.event!.recurrenceType == RecurrenceType.YEARLY;
      _requiresAttendance = widget.event!.requiresAttendance;
      _isImportant = widget.event!.isImportant;
      _day = widget.event!.day;
      _month = widget.event!.month;
      _year = widget.event!.year ?? DateTime.now().year;
      _selectedEntityId = widget.event!.clanId;
    }
  }

  Future<void> _fetchEntities() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Fetch all clans/families the user belongs to
        final res = await Supabase.instance.client
            .from('family_members')
            .select('clan_id, clans(id, name, type)')
            .eq('profile_id', user.id);
            
        final List<Map<String, dynamic>> clans = [];
        final List<Map<String, dynamic>> families = [];
        
        for (var item in res as List) {
           if (item['clan_id'] != null && item['clans'] != null) {
              final data = item['clans'];
              final entity = {
                   'id': data['id'],
                   'name': data['name']
              };
              
              if (data['type'] == 'family') {
                  if (!families.any((f) => f['id'] == entity['id'])) families.add(entity);
              } else {
                  if (!clans.any((c) => c['id'] == entity['id'])) clans.add(entity);
              }
           }
        }

        if (mounted) {
          setState(() {
            _clanOptions = clans;
            _familyOptions = families;
            _updateSelection();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching entities: $e');
    }
  }
  
  void _updateSelection() {
      // Auto-select first item based on current scope
      if (_scope == EventScope.CLAN && _clanOptions.isNotEmpty) {
          _selectedEntityId = _clanOptions.first['id'];
      } else if (_scope == EventScope.FAMILY && _familyOptions.isNotEmpty) {
          _selectedEntityId = _familyOptions.first['id'];
      } else {
          _selectedEntityId = null;
      }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate selection
    if (_selectedEntityId == null) {
       String msg = _scope == EventScope.CLAN 
           ? 'Bạn chưa chọn Dòng họ. (Nếu chưa có, hãy tạo Dòng họ trước)' 
           : 'Bạn chưa chọn Gia đình. (Nếu chưa có, hãy tạo Gia phả trước)';
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
       return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Bạn chưa đăng nhập');

      // --- PERMISSION CHECK CHO SỰ KIỆN DÒNG HỌ ---
      if (_scope == EventScope.CLAN) {
         // 1. Check if user is the Owner of this Clan
         final clanRes = await Supabase.instance.client
             .from('clans')
             .select('owner_id')
             .eq('id', _selectedEntityId!)
             .maybeSingle();
             
         bool isOwner = (clanRes != null && clanRes['owner_id'] == user.id);
         
         // 2. Check if user has 'toc_truong' role in profile
         final profileRes = await Supabase.instance.client
             .from('profiles')
             .select('role')
             .eq('id', user.id)
             .maybeSingle();
             
         bool isTocTruong = (profileRes != null && profileRes['role'] == 'toc_truong');
         
         // Nếu KHÔNG PHẢI Owner VÀ KHÔNG PHẢI Tộc trưởng -> CHẶN
         if (!isOwner && !isTocTruong) {
            throw Exception('Chỉ có Trưởng họ hoặc người tạo Dòng họ mới được tạo sự kiện chung.');
         }
      }
      // --------------------------------------------

      final eventId = widget.event?.id ?? ''; // Use existing ID if editing
       
      final newEvent = Event(
        id: eventId,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        scope: _scope,
        clanId: _selectedEntityId, // Use the selected ID for both cases
        category: _category,
        isLunar: _isLunar,
        day: _day,
        month: _month,
        year: _isRecurring ? null : _year,
        recurrenceType: _isRecurring ? RecurrenceType.YEARLY : RecurrenceType.NONE,
        createdBy: user.id, // Ensure this is not null
        requiresAttendance: _requiresAttendance,
        isImportant: _isImportant,
        createdAt: DateTime.now(),
      );

      if (widget.event == null) {
        await _eventService.createEvent(newEvent);
      } else {
        await _eventService.updateEvent(newEvent);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(widget.event == null ? 'Tạo sự kiện thành công!' : 'Cập nhật thành công!')),
        );
        Navigator.pop(context, true); // Return true to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Thêm Sự Kiện Mới' : 'Cập Nhật Sự Kiện')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Basic Info
              Text('Thông tin cơ bản', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tên sự kiện',
                  hintText: 'VD: Giỗ Tổ, Sinh Nhật, Họp Mặt...',
                  prefixIcon: Icon(Icons.event_note),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên sự kiện' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chi tiết',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 2. Settings (Scope, Type)
              _buildSectionTitle('Phân loại & Phạm vi'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<EventScope>(
                       value: _scope,
                       decoration: const InputDecoration(labelText: 'Phạm vi'),
                       items: [EventScope.CLAN, EventScope.FAMILY].map((s) => DropdownMenuItem( // Order: Clan first
                         value: s,
                         child: Text(s == EventScope.FAMILY ? 'Gia Đình' : 'Dòng Họ'),
                       )).toList(),
                       onChanged: (v) {
                         setState(() {
                           _scope = v!;
                           _updateSelection(); // Reset selection when scope changes
                         });
                       },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<EventCategory>(
                       value: _category,
                       decoration: const InputDecoration(labelText: 'Loại'),
                       items: EventCategory.values.map((s) => DropdownMenuItem(
                         value: s,
                         child: Text(s.name), 
                       )).toList(),
                       onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ],
              ),
              
              // Entity Selection (Dynamic Label based on Scope)
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_scope), // Force rebuild when scope changes
                value: _selectedEntityId,
                decoration: InputDecoration(
                  labelText: _scope == EventScope.CLAN ? 'Chọn Dòng Họ' : 'Chọn Gia Phả (Gia Đình)',
                  prefixIcon: Icon(_scope == EventScope.CLAN ? Icons.account_balance : Icons.cottage),
                ),
                items: (_scope == EventScope.CLAN ? _clanOptions : _familyOptions).map((e) => DropdownMenuItem(
                  value: e['id'].toString(),
                  child: Text(e['name'] ?? 'Không tên'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedEntityId = v),
                validator: (v) => v == null ? 'Vui lòng chọn ${_scope == EventScope.CLAN ? "dòng họ" : "gia đình"}' : null,
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Thời gian'),
              
              // Date Picker inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _day.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ngày'),
                      onChanged: (v) => setState(() => _day = int.tryParse(v) ?? 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _month.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tháng'),
                      onChanged: (v) => setState(() => _month = int.tryParse(v) ?? 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _year.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Năm bắt đầu'),
                      // enabled: true, // Always allow editing year
                      onChanged: (v) => setState(() => _year = int.tryParse(v) ?? DateTime.now().year),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Switches
              SwitchListTile(
                title: const Text('Lịch Âm'),
                subtitle: const Text('Sự kiện tính theo ngày Âm lịch'),
                value: _isLunar,
                onChanged: (v) => setState(() => _isLunar = v),
              ),
               CheckboxListTile(
                 title: const Text('Lặp lại hàng năm'),
                 subtitle: const Text('Tự động tạo sự kiện cho các năm sau'),
                 value: _isRecurring,
                 onChanged: (v) => setState(() => _isRecurring = v ?? false),
                 controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
                 activeColor: Theme.of(context).primaryColor,
               ),
              SwitchListTile(
                title: const Text('Yêu cầu điểm danh'),
                subtitle: const Text('Thành viên cần xác nhận tham gia'),
                value: _requiresAttendance,
                onChanged: (v) => setState(() => _requiresAttendance = v),
              ),
              SwitchListTile(
                title: const Text('Sự kiện quan trọng'),
                subtitle: const Text('Đánh dấu nổi bật trên màn hình chính'),
                value: _isImportant,
                activeColor: Colors.red,
                onChanged: (v) => setState(() => _isImportant = v),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                   minimumSize: const Size.fromHeight(60), // Bigger height
                   backgroundColor: Theme.of(context).primaryColor,
                   foregroundColor: Colors.white,
                   elevation: 4, // Add shadow
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(16), // Rounder corners
                   ),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(
                        widget.event == null ? 'TẠO SỰ KIỆN' : 'CẬP NHẬT',
                        style: const TextStyle(
                          fontSize: 20,  
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }
}
