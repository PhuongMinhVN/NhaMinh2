import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/merge_service.dart';
import '../scan_qr_page.dart';
import '../models/family_member.dart';

class MergeClanWizard extends StatefulWidget {
  final String sourceClanId;
  final String sourceClanName;
  final String currentUserId;

  const MergeClanWizard({
    super.key, 
    required this.sourceClanId, 
    required this.sourceClanName,
    required this.currentUserId,
  });

  @override
  State<MergeClanWizard> createState() => _MergeClanWizardState();
}

class _MergeClanWizardState extends State<MergeClanWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  
  // Step 1: Target Selection
  final TextEditingController _targetIdController = TextEditingController();
  Map<String, dynamic>? _targetClanInfo;
  
  // Step 2 (New): Identity Selection
  bool _isNewMember = true;
  FamilyMember? _targetSelfMember; // If I exist in target
  
  // Step 3 (Old Step 2): Parent (Anchor) Selection (Only if _isNewMember)
  List<FamilyMember> _targetMembers = [];
  FamilyMember? _selectedParent;
  final TextEditingController _searchParentController = TextEditingController();
  
  // Step 4 (Old Step 3): Branch Info (Only if _isNewMember)
  bool _isMainBranch = true;
  int _birthOrder = 1;

  final MergeService _mergeService = MergeService();

  @override
  void dispose() {
    _pageController.dispose();
    _targetIdController.dispose();
    _searchParentController.dispose();
    super.dispose();
  }
  
  // --- Logic Step 1 ---
  void _fetchTargetInfo(String id) async {
    id = id.trim().toLowerCase(); 
    if (id.isEmpty) return;
    
    try {
      var res;
      // 1. Full UUID Match
      if (id.length == 36) {
         try {
           res = await Supabase.instance.client.from('clans').select().eq('id', id).maybeSingle();
         } catch (_) {}
      }
      
      // 2. Short Code Match (Prefix Search)
      if (res == null && id.length >= 6) {
         try {
           String cleanHex = id.replaceAll('-', '');
           if (RegExp(r'^[0-9a-f]+$').hasMatch(cleanHex) && cleanHex.length < 32) {
              String minHex = cleanHex.padRight(32, '0');
              String maxHex = cleanHex.padRight(32, 'f');
              String toUuid(String h) => '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
              
              final list = await Supabase.instance.client
                  .from('clans')
                  .select()
                  .gte('id', toUuid(minHex))
                  .lte('id', toUuid(maxHex))
                  .limit(1); 
              if (list.isNotEmpty) res = list.first;
           }
         } catch (e) {
            debugPrint('Merge Search Error: $e');
         }
      }
      
      if (res != null) {
        setState(() => _targetClanInfo = res);
        _fetchTargetMembers(res['id']);
      } else {
        setState(() => _targetClanInfo = null);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _fetchTargetMembers(String clanId) async {
    try {
      final res = await Supabase.instance.client
          .from('family_members')
          .select()
          .eq('clan_id', clanId)
          .order('birth_date', ascending: true);
      setState(() {
        _targetMembers = (res as List).map((j) => FamilyMember.fromJson(j)).toList();
      });
    } catch (_) {}
  }

  void _scanQr() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanQrPage()));
    if (result != null && result is String) {
      setState(() => _targetIdController.text = result);
      _fetchTargetInfo(result);
    }
  }

  // --- Logic Step 2 (Add Parent) ---
  void _showAddParentDialog() {
    final nameController = TextEditingController();
    String selectedGender = 'male';

    showDialog(
      context: context, 
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Thêm Cha/Mẹ vào Dòng họ đích'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nếu cha/mẹ của bạn chưa có trong danh sách, hãy tạo mới để kết nối.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Họ và Tên', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Vai trò: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Cha (Ông)'),
                    selected: selectedGender == 'male',
                    onSelected: (v) => setState(() => selectedGender = 'male'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Mẹ (Bà)'),
                    selected: selectedGender == 'female',
                    onSelected: (v) => setState(() => selectedGender = 'female'),
                  ),
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Huỷ')),
            ElevatedButton(
              onPressed: () async {
                 if (nameController.text.isEmpty) return;
                 Navigator.pop(c);
                 await _createAnchorParent(nameController.text, selectedGender);
              },
              child: const Text('Tạo mới'),
            )
          ],
        ),
      )
    );
  }

  Future<void> _createAnchorParent(String name, String gender) async {
    if (_targetClanInfo == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('family_members').insert({
        'clan_id': _targetClanInfo!['id'],
        'full_name': name,
        'gender': gender,
        'is_alive': false,
        'title': gender == 'male' ? 'Ông' : 'Bà',
        'is_maternal': false, 
      }).select().single();
      
      final newMember = FamilyMember.fromJson(res);
      setState(() {
        _targetMembers.add(newMember);
        _selectedParent = newMember;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo và chọn ${gender == 'male' ? 'Cha' : 'Mẹ'} mới')));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tạo: $e')));
    }
  }

  // --- Logic Step 3 (Execution) ---
  void _performMerge() async {
    if (_targetClanInfo == null) return;
    
    // Find Source Root ID 
    int? sourceRootId;
    try {
       final meRes = await Supabase.instance.client
           .from('family_members')
           .select()
           .eq('clan_id', widget.sourceClanId)
           .eq('profile_id', widget.currentUserId)
           .maybeSingle();
       if (meRes != null) sourceRootId = meRes['id'];
    } catch (_) {}

    setState(() => _isLoading = true);
    
    try {
      final result = await _mergeService.mergeClans(
        sourceClanId: widget.sourceClanId, 
        targetClanId: _targetClanInfo!['id'],
        anchorParent: _isNewMember ? _selectedParent : null,
        sourceRootMemberId: sourceRootId,
        rootBirthOrder: _isNewMember ? (_isMainBranch ? 1 : _birthOrder) : null,
        targetSelfMemberId: !_isNewMember ? _targetSelfMember?.id : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); // Close wizard
        _showResultDialog(result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showResultDialog(MergeResult result) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gộp thành công!'),
        content: Text('Thêm mới: ${result.addedCount}\nLiên kết: ${result.linkedCount}'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng'))],
      )
    );
  }

  // -- Logic Step 2 (Identity) --
  // Reuse _targetMembers for selection.

  bool _currPageValid() {
    if (_currentStep == 0) return _targetClanInfo != null;
    if (_currentStep == 1) {
       // Step 2: Identity
       if (!_isNewMember && _targetSelfMember == null) return false;
       return true;
    }
    if (_currentStep == 2) {
       // Step 3: Parent Selection - ONLY if New Member
       if (!_isNewMember) return true; // Skip validation if not new
       return _selectedParent != null;
    }
    return true;
  }
  
  void _nextPage() {
    if (_currPageValid()) {
      // If Step 2 is "Existing Member", skip Step 3 (Parent) & 4 (Branch) -> Go to Final?
      // Actually, if "Existing Member", we can skip directly to Confirm/Merge.
      if (_currentStep == 1 && !_isNewMember) {
         // Jump to Merge Confirmation? Or just change button to "Merge".
         // Let's just setState to a special "Final" step or handle in UI.
         _performMerge(); // Early merge?
         // Better: Show confirmation dialog then merge.
         return;
      }
      
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: 550, 
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Gộp Phả Nâng Cao', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Progress Indicator
            Row(
              children: List.generate(4, (index) => Expanded( // 4 Steps now
                child: Container(
                  height: 4, 
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: index <= _currentStep ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
                ),
              )),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                   _buildStep1Target(),
                   _buildStep2Identity(),     // NEW
                   _buildStep3Parent(),       
                   _buildStep4Branch(),       
                ],
              ),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(onPressed: () {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    setState(() => _currentStep--);
                  }, child: const Text('Quay lại')),
                  
                if (_currentStep == 1 && !_isNewMember)
                   ElevatedButton(
                     onPressed: _isLoading ? null : _performMerge,
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
                     child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Gộp Ngay'),
                   )
                else if (_currentStep < 3)
                  ElevatedButton(
                     onPressed: _currPageValid() ? _nextPage : null,
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
                     child: const Text('Tiếp theo'),
                  )
                else
                  ElevatedButton(
                     onPressed: _isLoading ? null : _performMerge,
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
                     child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Hoàn tất Gộp'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Target() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bước 1: Chọn Dòng họ Đích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        const Text('Nhập Mã hoặc Quét QR của dòng họ bạn muốn gia nhập:'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _targetIdController,
                decoration: const InputDecoration(labelText: 'Mã Dòng họ (6 ký tự đầu)', border: OutlineInputBorder()),
                onChanged: (v) { if(v.length >= 6) _fetchTargetInfo(v); },
              ),
            ),
            IconButton(onPressed: _scanQr, icon: const Icon(Icons.qr_code_scanner)),
          ],
        ),
        if (_targetClanInfo != null) ...[
          const SizedBox(height: 16),
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
             child: Row(
               children: [
                 const Icon(Icons.check_circle, color: Colors.green),
                 const SizedBox(width: 12),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(_targetClanInfo!['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                     Text('ID: ${_targetClanInfo!['id'].toString().substring(0,6)}...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                     Text(
                        _targetClanInfo!['type'] == 'clan' ? 'Loại: Dòng Họ' : 'Loại: Gia Đình', 
                        style: TextStyle(
                           fontSize: 12, 
                           fontWeight: FontWeight.bold,
                           color: _targetClanInfo!['type'] == 'clan' ? Colors.brown : Colors.green
                        )
                     ),
                   ],
                 )
               ],
             ),
          ),
          if (_targetClanInfo!['type'] != 'clan')
             Container(
               margin: const EdgeInsets.only(top: 8),
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
               child: Row(
                 children: const [
                   Icon(Icons.warning_amber_rounded, color: Colors.orange),
                   SizedBox(width: 8),
                   Expanded(child: Text('Lưu ý: Bạn đang chọn gộp vào một Gia Đình nhỏ, không phải Dòng Họ.', style: TextStyle(color: Colors.orange, fontSize: 13))),
                 ],
               ),
             )
        ]
      ],
    );
  }
  
  Widget _buildStep2Identity() {
    // Filter for search
    final filtered = _targetMembers.where((m) {
       final q = _searchParentController.text.toLowerCase(); // Reuse controller
       return m.fullName.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text('Bước 2: Xác thực Danh tính', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
         const SizedBox(height: 12),
         const Text('Bạn là ai trong dòng họ này?'),
         const SizedBox(height: 12),
         
         RadioListTile<bool>(
            title: const Text('Tôi là thành viên MỚI'),
            subtitle: const Text('Chưa có tên trong danh sách, cần thêm vào'),
            value: true, 
            groupValue: _isNewMember, 
            activeColor: const Color(0xFF8B1A1A),
            onChanged: (v) => setState(() => _isNewMember = v!),
         ),
         RadioListTile<bool>(
            title: const Text('Tôi ĐÃ CÓ trong danh sách'),
            subtitle: const Text('Chọn tên của bạn để hợp nhất dữ liệu'),
            value: false, 
            groupValue: _isNewMember, 
            activeColor: const Color(0xFF8B1A1A),
            onChanged: (v) => setState(() => _isNewMember = v!),
         ),
         
         const Divider(),
         
         if (!_isNewMember) ...[
            const Text('Hãy tìm và chọn tên của bạn:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Search Box
            TextField(
              decoration: const InputDecoration(labelText: 'Tìm tên...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState((){ _searchParentController.text = v; }), 
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                   final m = filtered[index];
                   final isSelected = _targetSelfMember?.id == m.id;
                   return ListTile(
                     title: Text(m.fullName),
                     subtitle: Text(m.birthDate == null ? '?' : m.birthDate.toString().split(' ')[0]),
                     selected: isSelected,
                     selectedTileColor: Colors.blue.shade50,
                     trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                     onTap: () => setState(() => _targetSelfMember = m),
                   );
                },
              ),
            )
         ] else ...[
            const Expanded(child: Center(child: Text('Bấm "Tiếp theo" để chọn cha/mẹ và tạo mới hồ sơ của bạn.')))
         ]
      ],
    );
  }
  
  Widget _buildStep3Parent() {
    final filtered = _targetMembers.where((m) {
       final q = _searchParentController.text.toLowerCase();
       return m.fullName.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bước 3: Kết nối Cha/Ông', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Tìm người cha/ông của bạn trong dòng họ đích để kết nối cây gia phả:'),
        const SizedBox(height: 8),
        TextField(
          controller: _searchParentController,
          decoration: const InputDecoration(labelText: 'Tìm tên thành viên', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
          onChanged: (_) => setState((){}),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
               if (index == filtered.length) {
                 return Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: OutlinedButton.icon(
                     onPressed: _showAddParentDialog,
                     icon: const Icon(Icons.add),
                     label: const Text('Không tìm thấy? Tạo người mới'),
                   ),
                 );
               }
               final m = filtered[index];
               final isSelected = _selectedParent?.id == m.id;
               return ListTile(
                 title: Text(m.fullName),
                 subtitle: Text(m.birthDate == null ? 'Không rõ ngày sinh' : m.birthDate.toString().split(' ')[0]),
                 selected: isSelected,
                 selectedTileColor: Colors.red.shade50,
                 trailing: isSelected ? const Icon(Icons.check, color: Colors.red) : null,
                 onTap: () => setState(() => _selectedParent = m),
               );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Branch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bước 4: Xác định Phân nhánh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Bạn là con thứ mấy của người cha đã chọn?'),
        const SizedBox(height: 16),
        
        RadioListTile<bool>(
          title: const Text('Nhánh Trưởng (Con Cả / Đích Tôn)'),
          subtitle: const Text('Sẽ được xếp là con đầu (Birth Order = 1)'),
          value: true, 
          groupValue: _isMainBranch, 
          activeColor: const Color(0xFF8B1A1A),
          onChanged: (v) => setState(() { _isMainBranch = v!; _birthOrder = 1; }),
        ),
        RadioListTile<bool>(
          title: const Text('Nhánh Phụ (Con Thứ)'),
          subtitle: const Text('Vui lòng nhập thứ tự sinh'),
          value: false, 
          groupValue: _isMainBranch, 
          activeColor: const Color(0xFF8B1A1A),
          onChanged: (v) => setState(() { _isMainBranch = v!; if(_birthOrder==1) _birthOrder = 2; }),
        ),
        
        if (!_isMainBranch)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Row(
              children: [
                const Text('Thứ tự sinh: '),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _birthOrder,
                  items: List.generate(10, (i) => DropdownMenuItem(value: i+2, child: Text('Con thứ ${i+2}'))), 
                  onChanged: (v) => setState(() => _birthOrder = v!),
                )
              ],
            ),
          ),
          
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text('Tóm tắt Gộp:', style: TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 4),
               Text('- Nguồn: ${widget.sourceClanName}'),
               Text('- Đích: ${_targetClanInfo?['name']}'),
               Text('- Kết nối vào Cha: ${_selectedParent?.fullName ?? 'Chưa chọn'}'),
               Text('- Vai trò: ${_isMainBranch ? 'Con Trưởng' : 'Con Thứ $_birthOrder'}'),
             ],
          ),
        )
      ],
    );
  }
}
