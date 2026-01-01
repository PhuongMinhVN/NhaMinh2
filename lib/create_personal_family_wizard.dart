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

  final _formKey = GlobalKey<FormState>();
  
  // Family Info
  final _familyNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Personal Info
  final _myNameController = TextEditingController();
  DateTime? _dob;
  String _gender = 'male'; // 'male' or 'female'

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
          _myNameController.text = profile['full_name'] ?? '';
          _familyNameController.text = 'Gia đình ${profile['full_name'] ?? ''}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Gia Đình Mới'),
        backgroundColor: const Color(0xFF8B1A1A), // Consistent app color
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Simple Progress Indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / 2,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B1A1A)),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: _currentStep == 0 ? _buildFamilyInfoStep() : _buildPersonalInfoStep(),
              ),
            ),
          ),
          
          _buildNavigationArea(),
        ],
      ),
    );
  }

  Widget _buildFamilyInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin Gia Đình', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8B1A1A))),
        const SizedBox(height: 8),
        const Text('Hãy đặt tên cho gia đình của bạn để bắt đầu hành trình lưu giữ cội nguồn.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        TextFormField(
          controller: _familyNameController,
          decoration: const InputDecoration(
            labelText: 'Tên Gia Đình',
            hintText: 'Vd: Gia đình Nguyễn Văn A',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên gia đình' : null,
        ),
        const SizedBox(height: 24),
        
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ / Quê quán',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          maxLines: 2,
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin của Bạn', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8B1A1A))),
        const SizedBox(height: 8),
        const Text('Bạn sẽ là người đầu tiên trong cây gia phả này. Các thành viên khác có thể được thêm hoặc gộp sau.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),

        TextFormField(
          controller: _myNameController,
          decoration: const InputDecoration(
            labelText: 'Họ và Tên',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập họ tên' : null,
        ),
        const SizedBox(height: 24),

        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(1990),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _dob = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Ngày sinh',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _dob == null ? 'Chọn ngày sinh' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
              style: TextStyle(color: _dob == null ? Colors.grey : Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text('Giới tính:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Nam'),
                value: 'male',
                groupValue: _gender,
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Nữ'),
                value: 'female',
                groupValue: _gender,
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildNavigationArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(onPressed: () => setState(() => _currentStep--), child: const Text('Quay lại'))
          else
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_currentStep == 1 ? 'Tạo Gia Đình' : 'Tiếp tục'),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_familyNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên gia đình')));
        return;
      }
      setState(() => _currentStep++);
    } else {
      if (_myNameController.text.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập họ tên của bạn')));
         return;
      }
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _familyNameController.text.trim(),
        'description': _addressController.text.trim(),
        'owner_id': user.id,
        'type': 'family',
        'qr_code': 'FAM-${DateTime.now().millisecondsSinceEpoch % 1000000}', // Simple unique code
      }).select().single();
      
      final clanId = clanRes['id'];

      // 2. Create Root Member (The User)
      await Supabase.instance.client.from('family_members').insert({
        'clan_id': clanId,
        'full_name': _myNameController.text.trim(),
        'birth_date': _dob?.toIso8601String(),
        'gender': _gender,
        'is_alive': true,
        'profile_id': user.id,
        // No father_id, no mother_id -> Creates a single node tree
      });

      if (mounted) {
        Navigator.pop(context); // Close Wizard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo gia đình thành công!'), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
