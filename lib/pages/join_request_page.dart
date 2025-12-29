import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/clan.dart'; 
import '../repositories/clan_repository.dart';
import 'package:intl/intl.dart';

class JoinRequestPage extends StatefulWidget {
  final Clan clan;
  const JoinRequestPage({super.key, required this.clan});

  @override
  State<JoinRequestPage> createState() => _JoinRequestPageState();
}

class _JoinRequestPageState extends State<JoinRequestPage> {
  final _repo = ClanRepository();
  final _searchCtrl = TextEditingController();
  
  // States
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showCreateForm = false;

  // Create Form Data
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _gender = 'male';
  DateTime? _birthDate;
  
  // Relationship Data
  String _relationType = 'child'; // child | spouse
  Map<String, dynamic>? _selectedRelative;
  Map<String, String>? _newParentData; // NEW
  final _relativeSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _relativeSearchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gia nhập ${widget.clan.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _showCreateForm ? _buildCreateForm() : _buildSearchStep(),
      ),
    );
  }

  Widget _buildSearchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bước 1: Tìm hồ sơ của bạn',
          style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Nhập tên của bạn để kiểm tra xem bạn đã có trong gia phả chưa.'),
        const SizedBox(height: 16),
        
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Họ và Tên',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _performSearch,
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _performSearch(),
        ),
        
        const SizedBox(height: 24),
        
        if (_isSearching)
          const Center(child: CircularProgressIndicator())
        else if (_searchResults.isNotEmpty)
          ...[
            const Text('Kết quả tìm kiếm:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final member = _searchResults[index];
                final isClaimed = member['profile_id'] != null;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: member['gender'] == 'male' ? Colors.blue.shade100 : Colors.pink.shade100,
                      child: Icon(member['gender'] == 'male' ? Icons.male : Icons.female),
                    ),
                    title: Text(member['full_name']),
                    subtitle: Text('Sinh: ${member['birth_date'] ?? '---'}'),
                    trailing: isClaimed 
                      ? const Chip(label: Text('Đã có chủ'), backgroundColor: Colors.grey)
                      : ElevatedButton(
                          onPressed: () => _confirmClaim(member),
                          child: const Text('Là tôi'),
                        ),
                  ),
                );
              },
            )
          ]
        else if (_searchCtrl.text.isNotEmpty)
           const Center(child: Text('Không tìm thấy kết quả nào.')),

        const SizedBox(height: 32),
        const Divider(),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showCreateForm = true;
                _nameCtrl.text = _searchCtrl.text; // Pre-fill name
              });
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Tôi chưa có trong danh sách -> Tạo mới'),
          ),
        )
      ],
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _showCreateForm = false),
          ),
          Text(
            'Bước 2: Yêu cầu tạo hồ sơ mới',
            style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Nam')),
                    DropdownMenuItem(value: 'female', child: Text('Nữ')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context, 
                      initialDate: DateTime(1990), 
                      firstDate: DateTime(1800), 
                      lastDate: DateTime.now()
                    );
                    if (d != null) setState(() => _birthDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày sinh', border: OutlineInputBorder()),
                    child: Text(_birthDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(_birthDate!)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text('Mối quan hệ với thành viên trong gia phả:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Row(
            children: [
              DropdownButton<String>(
                value: _relationType,
                items: const [
                  DropdownMenuItem(value: 'child', child: Text('Là Con của')),
                  DropdownMenuItem(value: 'spouse', child: Text('Là Vợ/Chồng của')),
                  DropdownMenuItem(value: 'sibling', child: Text('Là Anh/Chị/Em ruột của')),
                  DropdownMenuItem(value: 'grandchild', child: Text('Là Cháu (Nội/Ngoại) của')),
                ],
                onChanged: (v) => setState(() {
                   _relationType = v!;
                   _selectedRelative = null; // Reset selection on type change
                   _relativeSearchResults.clear();
                   _relativeSearchCtrl.clear();
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _selectedRelative == null 
                   ? (_newParentData == null 
                       ? const Text('Chưa chọn người thân', style: TextStyle(color: Colors.red))
                       : Text('Tạo Bố/Mẹ mới: ${_newParentData!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))
                   : Text(_selectedRelative!['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              )
            ],
          ),
          
          const SizedBox(height: 8),
          TextField(
            controller: _relativeSearchCtrl,
             decoration: InputDecoration(
              labelText: _getSearchLabel(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _performRelativeSearch),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _performRelativeSearch(),
          ),
          
          if (_relativeSearchResults.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: _relativeSearchResults.length + 1,
                itemBuilder: (context, index) {
                  if (index == _relativeSearchResults.length) {
                     return _buildCreateParentButton();
                  }
                  final m = _relativeSearchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(m['full_name']),
                    subtitle: Text(m['birth_date'] ?? ''),
                    trailing: const Icon(Icons.check_circle_outline),
                    onTap: () {
                      setState(() {
                         _selectedRelative = m;
                         _newParentData = null; 
                         _relativeSearchResults.clear(); 
                         _relativeSearchCtrl.clear();
                      });
                    },
                  );
                },
              ),
            )
          else 
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildCreateParentButton(),
            ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitCreateRequest,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSubmitting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text('Gửi Yêu Cầu Tạo Mới'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCreateParentButton() {
    if (_relationType != 'child') return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () {
         final nameCtrl = TextEditingController();
         String gender = 'male';
         showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, st) => AlertDialog(
           title: const Text('Tạo Bố/Mẹ mới'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Họ và tên')),
               const SizedBox(height: 16),
               Row(children: [
                 const Text('Giới tính: '),
                 ChoiceChip(label: const Text('Nam (Bố)'), selected: gender == 'male', onSelected: (v) => st(()=>gender='male')),
                 const SizedBox(width: 8),
                 ChoiceChip(label: const Text('Nữ (Mẹ)'), selected: gender == 'female', onSelected: (v) => st(()=>gender='female')),
               ])
             ],
           ),
           actions: [
             TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Huỷ')),
             ElevatedButton(onPressed: () {
               if(nameCtrl.text.isNotEmpty) {
                 setState(() {
                   _newParentData = {'name': nameCtrl.text, 'gender': gender};
                   _selectedRelative = null;
                   _relativeSearchResults.clear();
                 });
                 Navigator.pop(c);
               }
             }, child: const Text('Chọn'))
           ],
         )));
      },
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Không tìm thấy? Nhấn để tạo mới cha/mẹ'),
    );
  }

  void _performSearch() async {
    if (_searchCtrl.text.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await _repo.searchClanMembers(widget.clan.id, _searchCtrl.text.trim());
      setState(() => _searchResults = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _performRelativeSearch() async {
    if (_relativeSearchCtrl.text.isEmpty) return;
    try {
      final results = await _repo.searchClanMembers(widget.clan.id, _relativeSearchCtrl.text.trim());
      setState(() => _relativeSearchResults = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _confirmClaim(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Bạn có chắc chắn hồ sơ "${member['full_name']}" chính là bạn không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Không')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await _sendClaimRequest(member);
            },
            child: const Text('Đúng là tôi'),
          )
        ],
      ),
    );
  }

  Future<void> _sendClaimRequest(Map<String, dynamic> member) async {
    try {
      await _repo.sendDetailedJoinRequest(
        targetClanId: widget.clan.id,
        type: 'claim_existing',
        metadata: {'member_id': member['id']}
      );
      if (mounted) _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitCreateRequest() async {
     if (!_formKey.currentState!.validate()) return;
     if (_selectedRelative == null && _newParentData == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn hoặc tạo người thân (Vợ/Chồng hoặc Cha/Mẹ).')));
        return;
     }

     setState(() => _isSubmitting = true);

     try {
       Map<String, dynamic> meta = {
           'full_name': _nameCtrl.text.trim(),
           'gender': _gender,
           'birth_date': _birthDate?.toIso8601String(),
           'relation': _relationType, 
       };
       
       int? targetPid;
       
       if (_selectedRelative != null) {
          meta['relative_id'] = _selectedRelative!['id'];
          if (_relationType == 'child') targetPid = _selectedRelative!['id'];
       } else if (_newParentData != null) {
          meta['new_parent_name'] = _newParentData!['name'];
          meta['new_parent_gender'] = _newParentData!['gender'];
       }

       await _repo.sendDetailedJoinRequest(
         targetClanId: widget.clan.id,
         type: 'create_new',
         targetParentId: targetPid,
         metadata: meta
       );
       if (mounted) _showSuccess();
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
     } finally {
       if (mounted) setState(() => _isSubmitting = false);
     }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Đã gửi yêu cầu'),
        content: const Text('Yêu cầu của bạn đã được gửi đến quản trị viên dòng họ. Vui lòng chờ phê duyệt.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close alert
              Navigator.pop(context); // close page (back to dashboard)
            },
            child: const Text('Về trang chủ'),
          )
        ],
      ),
    );
  }

  String _getSearchLabel() {
    switch (_relationType) {
      case 'spouse': return 'Tìm Vợ/Chồng (Nhập tên)';
      case 'sibling': return 'Tìm Anh/Chị/Em ruột (Nhập tên)';
      case 'grandchild': return 'Tìm Ông/Bà (Nhập tên)';
      default: return 'Tìm Bố/Mẹ (Nhập tên)';
    }
  }
}
