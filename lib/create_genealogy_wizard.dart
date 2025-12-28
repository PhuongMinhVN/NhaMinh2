import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CreateGenealogyWizard extends StatefulWidget {
  final bool isClan; // true for Clan (Dòng họ), false for Family (Gia đình)

  const CreateGenealogyWizard({super.key, required this.isClan});

  @override
  State<CreateGenealogyWizard> createState() => _CreateGenealogyWizardState();
}

class _CreateGenealogyWizardState extends State<CreateGenealogyWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data for 9 Generations + Meta info
  final _metaFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(); // Name of Clan/Family
  final _descriptionController = TextEditingController();
  
  // 9 Generations Data Controllers
  // Key: Generation Index (-4 to +4, 0 is Self)
  // Value: Map of data (name, spouse, etc.)
  final Map<int, Map<String, dynamic>> _generationsData = {};

  final List<String> _genTitles = [
    'Cao Tổ (Ông nội của ông nội)',
    'Tằng Tổ (Ông nội của cha)',
    'Nội Tổ (Ông nội)',
    'Phụ Thân (Cha)',
    'Bản Thân (Tôi)',
    'Tử (Con)',
    'Tôn (Cháu)',
    'Tằng Tôn (Chất)',
    'Huyền Tôn (Chút)'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    // Pre-fill "Self" data if available
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null) {
        setState(() {
          _generationsData[0] = {
            'name': profile['full_name'],
            'dob': '',
            'is_alive': true,
            'is_self': true,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isClan ? 'Tạo Gia Phả Dòng Họ' : 'Tạo Gia Phả Gia Đình'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / 10, // 1 Meta step + 9 Gen steps
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _currentStep--),
                    child: const Text('Quay lại'),
                  )
                else
                  const SizedBox(),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _onNextStep,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text(_currentStep == 9 ? 'Hoàn tất' : 'Tiếp tục'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return _buildMetaStep();
    } else {
      // Steps 1 to 9 correspond to Generation Index 0 to 8 in the list
      // But map to Gen Index -4 to +4 logic
      final listIndex = _currentStep - 1; 
      final genIndex = listIndex - 4; // -4, -3, ... 0 ... +4
      return _buildGenerationStep(listIndex, genIndex);
    }
  }

  Widget _buildMetaStep() {
    return Form(
      key: _metaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin chung',
            style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
          ).animate().fadeIn().slideX(),
          const SizedBox(height: 8),
          Text(
            widget.isClan 
              ? 'Hãy đặt tên cho Dòng họ của bạn (Ví dụ: Họ Nguyễn - Chi 2 - Bắc Ninh)'
              : 'Đặt tên cho Gia đình nhỏ (Ví dụ: Gia đình Ông Ba)',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.stars),
            ),
            validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Mô tả / Ghi chú (Từ đường, địa chỉ gốc...)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('Sau bước này, bạn sẽ nhập thông tin cho 9 đời theo cấu trúc "Cửu Tộc" để hệ thống xây dựng cây gia phả mẫu.')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGenerationStep(int listIndex, int genIndex) {
    // genIndex: -4 (Cao Tổ) ... 0 (Self) ... +4 (Huyền Tôn)
    final title = _genTitles[listIndex];
    final isSelf = genIndex == 0;
    
    // Ensure map entry exists
    if (!_generationsData.containsKey(genIndex)) {
       _generationsData[genIndex] = {};
    }
    final data = _generationsData[genIndex]!;
    
    // Use controllers specifically for this step to persist text when switching steps?
    // A simplified approach: bind value to a map update on change, init value from map.
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text('Đời thứ ${listIndex + 1} / 9'),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          labelStyle: TextStyle(color: Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown.shade900),
        ).animate().fadeIn().slideY(),
        
        if (isSelf) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text('Đây chính là BẠN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 32),
        
        // Input Fields
        TextFormField(
          initialValue: data['name'] ?? '',
          decoration: const InputDecoration(
            labelText: 'Họ và Tên',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          onChanged: (val) => data['name'] = val,
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: data['gender'] ?? 'unknown',
          decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'unknown', child: Text('Không rõ / Mặc định')),
            DropdownMenuItem(value: 'Nam', child: Text('Nam')),
            DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
          ],
          onChanged: (val) => data['gender'] = val,
        ),
        
        if (!isSelf) ...[
           const SizedBox(height: 16),
           CheckboxListTile(
             contentPadding: EdgeInsets.zero,
             title: const Text('Còn sống?'),
             value: data['is_alive'] ?? false, 
             onChanged: (val) => setState(() => data['is_alive'] = val),
           ),
        ],

        const SizedBox(height: 16),
        Text(
          genIndex < 0 ? 'Nếu thông tin này chưa rõ, bạn có thể để trống và cập nhật sau.' 
                       : (isSelf ? 'Kiểm tra kỹ thông tin của bạn.' : 'Nhập tên con/cháu đại diện nếu có.'),
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      ],
    );
  }

  void _onNextStep() async {
    // 1. Validation for Step 0
    if (_currentStep == 0) {
      if (!_metaFormKey.currentState!.validate()) return;
    }
    
    // 2. Logic for Finish (Step 9)
    if (_currentStep == 9) {
      await _submitData();
      return;
    }

    // 3. Move Next
    setState(() => _currentStep++);
  }

  Future<void> _submitData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'owner_id': user.id,
        'type': widget.isClan ? 'clan' : 'family', // Assuming column exists or JSON
        'qr_code': _generateRandomCode(6),
      }).select().single();
      
      final clanId = clanRes['id'];

      // 2. Create Members recursively?
      // Since it's a direct lineage line (Cao To -> Tang To -> Noi To -> Cha -> Me -> Con -> Chau...),
      // we can link them sequentially.
      
      int? previousFatherId;
      
      // Iterate from Gen -4 to +4
      for (int i = -4; i <= 4; i++) {
        final d = _generationsData[i];
        if (d == null || (d['name'] == null && i != 0)) {
            // Gap in data, but we must maintain linkage?
            // If unknown ancestor, we might skip creating record OR create a placeholder "Unknown".
            // Let's create placeholder if name is empty but previous existed?
            // For simplicity, if name empty, skip? No, that breaks tree.
            // If name is empty, we insert "Chưa rõ" to keep the chain.
            if (previousFatherId != null || i == -4) {
               // Continue chain
            } else {
               continue; 
            }
        }
        
        String name = d?['name'] ?? 'Chưa rõ';
        // Cleanup
        if (name.trim().isEmpty) name = 'Chưa rõ';
        
        final Map<String, dynamic> memberData = {
          'clan_id': clanId,
          'full_name': name,
          'father_id': previousFatherId,
          // 'generation': i, // Optional if schema has it
          'gender': d?['gender'] == 'Nữ' ? 'female' : 'male', // Default male usually for ancestors in VN genealogy
          'is_alive': d?['is_alive'] ?? false,
        };

        // If Self
        if (i == 0) {
           memberData['profile_id'] = user.id; // Link to auth user
           memberData['is_alive'] = true;
        }

        final memberRes = await Supabase.instance.client.from('family_members').insert(memberData).select().single();
        previousFatherId = memberRes['id'];
        
        // Update Root if first
        if (i == -4 || (previousFatherId != null && i == -4)) {
           // Maybe mark root
        }
      }
      
      if (mounted) {
        Navigator.pop(context); // Close Wizard
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo gia phả thành công!')));
        // Trigger generic refresh if needed
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  String _generateRandomCode(int length) {
    // Simple random string
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[(DateTime.now().microsecondsSinceEpoch * (index + 1)) % chars.length]).join();
  }
}
