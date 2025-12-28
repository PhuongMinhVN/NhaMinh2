import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CreatePersonalFamilyWizard extends StatefulWidget {
  const CreatePersonalFamilyWizard({super.key});

  @override
  State<CreatePersonalFamilyWizard> createState() => _CreatePersonalFamilyWizardState();
}

class _CreatePersonalFamilyWizardState extends State<CreatePersonalFamilyWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _metaFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Data structure for 5 generations
  // 0: Ông Cố, 1: Ông Nội, 2: Bố, 3: Bản thân & Anh em, 4: Con cái
  final Map<int, Map<String, dynamic>> _data = {
    0: {'title': 'Ông Cố', 'name': '', 'is_alive': false},
    1: {'title': 'Ông Nội', 'name': '', 'is_alive': false},
    2: {'title': 'Bố', 'name': '', 'is_alive': true, 'mother_name': '', 'mother_alive': true},
    3: {'title': 'Bản Thân & Anh Chị Em', 'self_name': '', 'siblings': ''},
    4: {'title': 'Con Cái', 'children': ''},
  };

  @override
  void initState() {
    super.initState();
    _loadSelfData();
  }

  void _loadSelfData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null) {
        setState(() {
          _data[3]!['self_name'] = profile['full_name'];
          _nameController.text = 'Gia đình ${profile['full_name']}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Gia Phả Gia Đình 5 Đời'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            backgroundColor: Colors.green.shade50,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          _buildNavigationArea(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) return _buildMetaStep();
    return _buildGenerationStep(_currentStep - 1);
  }

  Widget _buildMetaStep() {
    return Form(
      key: _metaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông tin gia đình', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tên Gia Phả (Vd: Gia đình anh Hùng)', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Ghi chú / Địa chỉ', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildGenerationStep(int stepIndex) {
    final stepData = _data[stepIndex]!;
    final title = stepData['title'];

    if (stepIndex == 3) { // Gen 4: Self & Siblings
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _genHeader(title, stepIndex + 1),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: stepData['self_name'],
            decoration: const InputDecoration(labelText: 'Họ tên của Bạn', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
            onChanged: (v) => stepData['self_name'] = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: stepData['siblings'],
            decoration: const InputDecoration(
              labelText: 'Họ tên Anh Chị Em (cùng bố)',
              helperText: 'Các tên cách nhau bằng dấu phẩy (,)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.groups),
            ),
            maxLines: 2,
            onChanged: (v) => stepData['siblings'] = v,
          ),
        ],
      ).animate().fadeIn();
    }

    if (stepIndex == 4) { // Gen 5: Children
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _genHeader(title, stepIndex + 1),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: stepData['children'],
            decoration: const InputDecoration(
              labelText: 'Họ tên các Con của bạn',
              helperText: 'Các tên cách nhau bằng dấu phẩy (,)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.child_care),
            ),
            maxLines: 3,
            onChanged: (v) => stepData['children'] = v,
          ),
        ],
      ).animate().fadeIn();
    }

    // Default Ancestor Step (Ông Cố, Ông Nội, Bố)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _genHeader(title, stepIndex + 1),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: stepData['name'],
          decoration: InputDecoration(labelText: 'Họ và Tên $title', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person_outline)),
          onChanged: (v) => stepData['name'] = v,
        ),
        CheckboxListTile(
          title: const Text('Còn sống?'),
          value: stepData['is_alive'],
          onChanged: (v) => setState(() => stepData['is_alive'] = v),
        ),
        
        // Add Mother Input for Gen 3 (Father)
        if (stepIndex == 2) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Thông tin Mẹ (Vợ của Bố)', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: stepData['mother_name'],
            decoration: const InputDecoration(labelText: 'Họ và Tên Mẹ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_3_outlined)),
            onChanged: (v) => stepData['mother_name'] = v,
          ),
          CheckboxListTile(
            title: const Text('Mẹ còn sống?'),
            value: stepData['mother_alive'] ?? true,
            onChanged: (v) => setState(() => stepData['mother_alive'] = v),
          ),
        ]
      ],
    ).animate().fadeIn();
  }

  Widget _genHeader(String title, int num) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(label: Text('Đời thứ $num / 5')),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
      ],
    );
  }

  Widget _buildNavigationArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(onPressed: () => setState(() => _currentStep--), child: const Text('Quay lại'))
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleNext,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_currentStep == 5 ? 'Hoàn tất' : 'Tiếp tục'),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (!_metaFormKey.currentState!.validate()) return;
    }
    if (_currentStep == 5) {
      _submit();
    } else {
      setState(() => _currentStep++);
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Create Clan/Family
      final clan = await Supabase.instance.client.from('clans').insert({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'owner_id': user.id,
        'type': 'family',
        'qr_code': 'FAM-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      }).select().single();

      final clanId = clan['id'];

      // 2. Insert Ancestors (Linear) & Mother
      int? currentFatherId;
      for (int i = 0; i < 3; i++) {
        // Insert Father/Ancestor
        final res = await Supabase.instance.client.from('family_members').insert({
          'clan_id': clanId,
          'full_name': _data[i]!['name'].toString().isEmpty ? 'Ông ${_data[i]!['title']}' : _data[i]!['name'],
          'is_alive': _data[i]!['is_alive'],
          'father_id': currentFatherId,
          'gender': 'male',
        }).select().single();
        final ancestorId = res['id'];
        
        // Update currentFatherId for next generation linkage
        currentFatherId = ancestorId;

        // If this is Gen 3 (Father), insert Mother
        if (i == 2) {
           final motherName = _data[i]!['mother_name'];
           if (motherName != null && motherName.toString().isNotEmpty) {
               final motherRes = await Supabase.instance.client.from('family_members').insert({
                   'clan_id': clanId,
                   'full_name': motherName,
                   'is_alive': _data[i]!['mother_alive'] ?? true,
                   'gender': 'female',
                   'spouse_id': ancestorId, // Link to Father
                   'is_maternal': false, // Married into family
               }).select().single();
               
               // Link Father to Mother
               await Supabase.instance.client.from('family_members').update({
                   'spouse_id': motherRes['id']
               }).eq('id', ancestorId);
           }
        }
      }

      // 3. Insert Self & Siblings (Step 3)
      final step3 = _data[3]!;
      // Create Self
      final selfRes = await Supabase.instance.client.from('family_members').insert({
        'clan_id': clanId,
        'full_name': step3['self_name'],
        'is_alive': true,
        'father_id': currentFatherId,
        'profile_id': user.id,
        'gender': 'male', // Default, would be better to fetch from profile
      }).select().single();
      final selfId = selfRes['id'];

      // Create Siblings
      final siblingNames = step3['siblings'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (var sName in siblingNames) {
        await Supabase.instance.client.from('family_members').insert({
          'clan_id': clanId,
          'full_name': sName,
          'is_alive': true,
          'father_id': currentFatherId,
        });
      }

      // 4. Insert Children (Step 4)
      final step4 = _data[4]!;
      final childrenNames = step4['children'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (var cName in childrenNames) {
        await Supabase.instance.client.from('family_members').insert({
          'clan_id': clanId,
          'full_name': cName,
          'is_alive': true,
          'father_id': selfId,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo gia phả gia đình thành công!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
