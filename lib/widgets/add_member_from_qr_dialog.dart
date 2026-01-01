import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';
import '../repositories/clan_repository.dart';

class AddMemberFromQrDialog extends StatefulWidget {
  final Map<String, dynamic> scannedProfile;
  final String currentClanId;

  const AddMemberFromQrDialog({
    super.key,
    required this.scannedProfile,
    required this.currentClanId,
  });

  @override
  State<AddMemberFromQrDialog> createState() => _AddMemberFromQrDialogState();
}

class _AddMemberFromQrDialogState extends State<AddMemberFromQrDialog> {
  final ClanRepository _repo = ClanRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<FamilyMember> _members = [];
  List<FamilyMember> _filteredMembers = [];
  
  FamilyMember? _selectedTargetMember;
  String _relationship = 'child'; // 'child', 'spouse', 'parent'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClanMembers();
  }

  Future<void> _fetchClanMembers() async {
    try {
      // We can use a direct query here as we are in a widget, or use repo if available.
      // Using direct query for simplicity to get full FamilyMember objects
      final res = await Supabase.instance.client
          .from('family_members')
          .select()
          .eq('clan_id', widget.currentClanId)
          .order('birth_date', ascending: true);
          
      final list = (res as List).map((j) => FamilyMember.fromJson(j)).toList();
      
      setState(() {
        _members = list;
        _filteredMembers = list;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
    }
  }

  void _filterMembers(String query) {
    setState(() {
      _filteredMembers = _members.where((m) => 
        m.fullName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  Future<void> _addMember() async {
    if (_selectedTargetMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn người thân để liên kết')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final profile = widget.scannedProfile;
      final target = _selectedTargetMember!;
      
      // Prepare new member data
      // We are adding the SCANNED PERSON as a relative of TARGET
      Map<String, dynamic> newMemberData = {
        'clan_id': widget.currentClanId,
        'full_name': profile['full_name'] ?? 'Thành viên mới',
        'profile_id': profile['id'], // Link to the scanned user account
        'is_alive': true, // Default true for active users
        'gender': 'male', // Default, maybe ask? Or infer? Let's leave as male for now or ask in UI?
                          // Ideally we should ask Gender if not in profile.
                          // Assuming profile might not have gender.
                          // Let's default to male.
      };

      // Determine Relationships
      if (_relationship == 'child') {
        // Scanned is CHILD of Target
        if (target.gender == 'male') {
          newMemberData['father_id'] = target.id;
          newMemberData['mother_id'] = target.spouseId; // Guess spouse?
        } else {
          newMemberData['mother_id'] = target.id;
          newMemberData['father_id'] = target.spouseId;
        }
        newMemberData['generation_level'] = (target.generationLevel ?? 1) + 1;
      } 
      else if (_relationship == 'spouse') {
        // Scanned is SPOUSE of Target
        newMemberData['spouse_id'] = target.id;
        newMemberData['generation_level'] = target.generationLevel;
        // Also need to update Target's spouse_id later if reciprocal
      }
      else if (_relationship == 'parent') {
        // Scanned is PARENT of Target
        // Complex: Target needs update.
        newMemberData['generation_level'] = (target.generationLevel ?? 1) - 1;
      }

      // 1. Insert New Member
      final res = await Supabase.instance.client.from('family_members').insert(newMemberData).select().single();
      final newMemberId = res['id'];

      // 2. Update Reciprocal Links (if needed)
      if (_relationship == 'spouse') {
         await Supabase.instance.client.from('family_members').update({'spouse_id': newMemberId}).eq('id', target.id);
      }
      else if (_relationship == 'parent') {
         // Determine if Father or Mother based on scanned user gender (which we assumed male/default)
         // To be safe, we should probably ask Gender in this dialog.
         // For now, let's assume we update 'father_id' of target.
         await Supabase.instance.client.from('family_members').update({'father_id': newMemberId}).eq('id', target.id);
      }

      if (mounted) {
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm Thành Viên từ QR'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Tìm thấy: ${widget.scannedProfile['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             Text('SĐT: ${widget.scannedProfile['phone'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
             const SizedBox(height: 16),
             
             const Text('Liên kết với ai trong gia phả?', style: TextStyle(fontWeight: FontWeight.bold)),
             TextField(
               controller: _searchController,
               decoration: const InputDecoration(
                 hintText: 'Tìm người thân...',
                 prefixIcon: Icon(Icons.search),
               ),
               onChanged: _filterMembers,
             ),
             
             const SizedBox(height: 8),
             Container(
               height: 150,
               decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
               child: ListView.builder(
                 itemCount: _filteredMembers.length,
                 itemBuilder: (context, index) {
                   final m = _filteredMembers[index];
                   final isSelected = _selectedTargetMember?.id == m.id;
                   return ListTile(
                     title: Text(m.fullName),
                     dense: true,
                     selected: isSelected,
                     selectedTileColor: Colors.blue.shade50,
                     onTap: () => setState(() => _selectedTargetMember = m),
                     trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                   );
                 },
               ),
             ),
             
             if (_selectedTargetMember != null) ...[
               const SizedBox(height: 16),
               const Text('Mối quan hệ:', style: TextStyle(fontWeight: FontWeight.bold)),
               DropdownButton<String>(
                 value: _relationship,
                 isExpanded: true,
                 items: const [
                   DropdownMenuItem(value: 'child', child: Text('Là CON của người này')),
                   DropdownMenuItem(value: 'spouse', child: Text('Là VỢ/CHỒNG của người này')),
                   DropdownMenuItem(value: 'parent', child: Text('Là CHA/MẸ của người này')),
                 ],
                 onChanged: (v) => setState(() => _relationship = v!),
               )
             ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isLoading ? null : _addMember, 
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Thêm ngay'),
        ),
      ],
    );
  }
}
