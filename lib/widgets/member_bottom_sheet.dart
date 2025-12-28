import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';
import 'package:intl/intl.dart';

class MemberBottomSheet extends StatefulWidget {
  final String clanId;
  final List<FamilyMember> existingMembers;
  final bool isOwner;
  final FamilyMember? memberToEdit;

  const MemberBottomSheet({
    super.key, 
    required this.clanId, 
    required this.existingMembers,
    this.isOwner = false,
    this.memberToEdit,
  });

  @override
  State<MemberBottomSheet> createState() => _MemberBottomSheetState();
}

class _MemberBottomSheetState extends State<MemberBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = 'male';
  bool _isAlive = true;
  String? _title;
  DateTime? _birthDate;
  bool _isMaternal = false;

  int? _selectedRelatedMemberId;
  String _relationType = 'child'; // To be deprecated/synced with mode
  String _relationshipMode = 'child'; // child, sibling, spouse, parent 
  int? _birthOrder; 
  bool _isLoading = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    if (widget.memberToEdit != null) {
      final m = widget.memberToEdit!;
      _nameController.text = m.fullName;
      _addressController.text = m.address ?? '';
      _gender = m.gender ?? 'male';
      _isAlive = m.isAlive;
      _title = m.title;
      _birthDate = m.birthDate;
      _isMaternal = m.isMaternal;
      _birthOrder = m.birthOrder;
      _isMe = m.profileId == Supabase.instance.client.auth.currentUser?.id;

      if (m.fatherId != null) {
        _selectedRelatedMemberId = m.fatherId;
        _relationType = 'child';
      } else if (m.motherId != null) {
        _selectedRelatedMemberId = m.motherId;
        _relationType = 'child';
      } else if (m.spouseId != null) {
        _selectedRelatedMemberId = m.spouseId;
        _relationType = 'spouse';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1980),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.memberToEdit != null;
    bool hasAccount = widget.memberToEdit?.profileId != null;
    bool isRootInit = widget.existingMembers.isEmpty;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16, left: 16, right: 16
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.person_add_alt_1, color: const Color(0xFF8B1A1A)),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Sửa thông tin' : 'Thêm thành viên mới', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và Tên', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập tên' : null,
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
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12),
                       decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                       child: CheckboxListTile(
                         value: _isAlive,
                         title: const Text('Còn sống'),
                         contentPadding: EdgeInsets.zero,
                         onChanged: (v) => setState(() => _isAlive = v!),
                       ),
                     ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CheckboxListTile(
                 value: _isMaternal,
                 title: const Text('Thuộc bên ngoại (Gia đình vợ/mẹ)', style: TextStyle(fontWeight: FontWeight.w500)),
                 contentPadding: EdgeInsets.zero,
                 activeColor: Colors.purple,
                 onChanged: (v) => setState(() => _isMaternal = v!),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _isAlive ? 'Ngày sinh (Bắt buộc)' : 'Ngày sinh (Tùy chọn cho người đã mất)', 
                    border: const OutlineInputBorder(), 
                    prefixIcon: const Icon(Icons.calendar_today, size: 20)
                  ),
                  child: Text(
                    _birthDate == null ? 'Chưa chọn' : DateFormat('dd/MM/yyyy').format(_birthDate!),
                    style: TextStyle(color: (_birthDate == null && _isAlive) ? Colors.red : Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (!hasAccount) ...[
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Nơi ở (Địa chỉ)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on, size: 20)),
                ),
                const SizedBox(height: 12),
              ],
              
              if (widget.isOwner) ...[
                 DropdownButtonFormField<String>(
                   value: _title,
                   decoration: const InputDecoration(labelText: 'Chức danh (Vai trò)', border: OutlineInputBorder()),
                   items: [
                      const DropdownMenuItem(value: null, child: Text('Không có (Thành viên)')),
                      ...['Trưởng họ', 'Đích tôn', 'Phó họ', 'Chi trưởng', 'Chi phó', 'Trưởng Nhà', 'Phó Nhà']
                         .map((t) => DropdownMenuItem(value: t, child: Text(t))),
                      // Common Birth Order Titles
                      ...['Con Cả', 'Trưởng Nữ', 'Con thứ 2', 'Con thứ 3', 'Con thứ 4', 'Con thứ 5']
                         .map((t) => DropdownMenuItem(value: t, child: Text(t))),
                      // If current title is weird/custom (e.g. "Con thứ 13"), add it
                      if (_title != null && 
                          !['Trưởng họ', 'Đích tôn', 'Phó họ', 'Chi trưởng', 'Chi phó', 'Trưởng Nhà', 'Phó Nhà', 
                            'Con Cả', 'Trưởng Nữ', 'Con thứ 2', 'Con thứ 3', 'Con thứ 4', 'Con thứ 5'].contains(_title))
                        DropdownMenuItem(value: _title, child: Text(_title!)),
                   ],
                   onChanged: (v) {
                     setState(() {
                       _title = v;
                       if (v == 'Trưởng họ') _isMe = true;
                     });
                   },
                  ),
                  CheckboxListTile(
                    title: const Text('Đây là tôi (Liên kết với tài khoản này)'),
                    value: _isMe,
                    onChanged: (v) => setState(() => _isMe = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                 const SizedBox(height: 16),
              ],

              if (!isRootInit) ...[
                const Text('Mối quan hệ (Bắt buộc)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // 1. Relationship Mode Selector
                DropdownButtonFormField<String>(
                  value: _relationshipMode,
                  decoration: const InputDecoration(labelText: 'Thêm thành viên này là gì?', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'child', child: Text('Là Con của...')),
                    DropdownMenuItem(value: 'sibling', child: Text('Là Anh/Chị/Em của...')),
                    DropdownMenuItem(value: 'spouse', child: Text('Là Vợ/Chồng của...')),
                    DropdownMenuItem(value: 'parent', child: Text('Là Cha/Mẹ của...')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _relationshipMode = v!;
                      _selectedRelatedMemberId = null; // Reset selection on mode change
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // 2. Member Selector (Filtered)
                DropdownButtonFormField<int>(
                  value: _selectedRelatedMemberId,
                  decoration: InputDecoration(
                    labelText: _getMemberSelectorLabel(), 
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_search),
                  ),
                  isExpanded: true,
                  items: _getFilteredMembers().map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.fullName} - ${m.title ?? "Thành viên"} (${m.gender == "male" ? "Nam" : "Nữ"})'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedRelatedMemberId = v),
                  validator: (v) => v == null ? 'Vui lòng chọn người liên kết' : null,
                ),

              
                // 3. Birth Order Selector (Only for Child/Sibling modes)
                if (_relationshipMode == 'child' || _relationshipMode == 'sibling') ...[
                   const SizedBox(height: 12),
                   DropdownButtonFormField<int>(
                     value: _birthOrder,
                     decoration: const InputDecoration(labelText: 'Thứ bậc trong gia đình (Con thứ mấy)', border: OutlineInputBorder()),
                     items: List.generate(20, (index) => index + 1).map((i) => DropdownMenuItem(
                       value: i,
                       child: Text('Con thứ $i ${i == 1 ? "(Cả/Trưởng)" : ""}'),
                     )).toList(),
                     onChanged: (v) {
                       setState(() {
                         _birthOrder = v;
                         // Auto-set Title
                         if (v == 1) _title = (_gender == 'male') ? 'Con Cả' : 'Trưởng Nữ';
                         else if (v == 2) _title = 'Con thứ 2';
                         else if (v == 3) _title = 'Con thứ 3';
                         else _title = 'Con thứ $v';
                       });
                     },
                   ),
                ],
              ],
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? 'Lưu thay đổi' : 'Lưu thành viên'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Custom Validation
    // Removed mandatory birth date check as per user request
    if (_relationshipMode == 'sibling' && _selectedRelatedMemberId == null) {
       // Should be caught by validator but double check
    }
    
    if (widget.existingMembers.isNotEmpty && _selectedRelatedMemberId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn mối quan hệ với thành viên khác')));
       return;
    }

    setState(() => _isLoading = true);
    
    try {
      final Map<String, dynamic> data = {
        'clan_id': widget.clanId,
        'full_name': _nameController.text.trim(),
        'gender': _gender,
        'is_alive': _isAlive,
        'title': _title,
        'birth_date': _birthDate?.toIso8601String(),
        'address': _addressController.text.trim(),

        'is_maternal': _isMaternal,
        'birth_order': _birthOrder,
        'profile_id': _isMe ? Supabase.instance.client.auth.currentUser?.id : (widget.memberToEdit?.profileId == Supabase.instance.client.auth.currentUser?.id ? null : widget.memberToEdit?.profileId),
      };

      if (_selectedRelatedMemberId != null) {
          final related = widget.existingMembers.firstWhere((m) => m.id == _selectedRelatedMemberId);
          
          if (_relationshipMode == 'child') { 
             if (related.gender == 'male') {
               data['father_id'] = related.id;
               data['mother_id'] = related.spouseId; // Try to link mother if known
             } else {
               data['mother_id'] = related.id;
               data['father_id'] = related.spouseId;
             }
          } else if (_relationshipMode == 'sibling') {
             // Sibling Mode: Inherit parents
             data['father_id'] = related.fatherId;
             data['mother_id'] = related.motherId;
          } else if (_relationshipMode == 'spouse') {
             // Spouse Mode: Set spouse_id (if column exists)
             // We will also update the Other person later
             data['spouse_id'] = related.id;
          }
      }
      
      if (widget.memberToEdit != null) {
        await Supabase.instance.client
            .from('family_members')
            .update(data)
            .eq('id', widget.memberToEdit!.id);
            
        // Post-update: If we set them as PARENT of selected member
        if (_selectedRelatedMemberId != null && _relationshipMode == 'parent') {
            final updateData = _gender == 'male' ? {'father_id': widget.memberToEdit!.id} : {'mother_id': widget.memberToEdit!.id};
            await Supabase.instance.client.from('family_members').update(updateData).eq('id', _selectedRelatedMemberId!);
        }
      } else {
        final res = await Supabase.instance.client.from('family_members').insert(data).select().single();
        final newMemberId = res['id'];

        if (_selectedRelatedMemberId != null) {
           if (_relationshipMode == 'spouse') {
              // Update the spouse to point back
              await Supabase.instance.client.from('family_members').update({'spouse_id': newMemberId}).eq('id', _selectedRelatedMemberId!);
           } else if (_relationshipMode == 'parent') {
              // Update the child to point to this new parent
              final updateData = _gender == 'male' ? {'father_id': newMemberId} : {'mother_id': newMemberId};
              await Supabase.instance.client.from('family_members').update(updateData).eq('id', _selectedRelatedMemberId!);
           }
        }
      }
      
      if (mounted) {
         Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getMemberSelectorLabel() {
    switch (_relationshipMode) {
      case 'child': return 'Chọn Cha/Mẹ';
      case 'sibling': return 'Chọn Anh/Chị/Em ruột';
      case 'spouse': return 'Chọn Vợ/Chồng';
      case 'parent': return 'Chọn Con cái';
      default: return 'Chọn thành viên liên kết';
    }
  }

  List<FamilyMember> _getFilteredMembers() {
    // Return all members initially, can filter by gender if needed for nuances
    return widget.existingMembers.where((m) => m.id != widget.memberToEdit?.id).toList();
  }
}
