import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../clan_tree_page.dart';

class CreateFamilySimplePage extends StatefulWidget {
  const CreateFamilySimplePage({super.key});

  @override
  State<CreateFamilySimplePage> createState() => _CreateFamilySimplePageState();
}

class _CreateFamilySimplePageState extends State<CreateFamilySimplePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Family Info
  final _familyNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Personal Info
  final _memberNameController = TextEditingController();
  DateTime? _dob;
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    try {
      _loadUserInfo();
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  void _loadUserInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      final name = user.userMetadata?['full_name'] ?? '';
      _memberNameController.text = name;
      _familyNameController.text = 'Gia đình $name';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Gia Đình Mới'),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Thông tin Gia Đình'),
                TextFormField(
                  controller: _familyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên Gia Đình',
                    hintText: 'VD: Gia đình Nguyễn Văn A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home),
                  ),
                  validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên gia đình' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
  
                const SizedBox(height: 32),
                _buildSectionTitle('Thông tin thành viên tạo (Bạn)'),
                TextFormField(
                  controller: _memberNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và Tên',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 16),
                
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
                const SizedBox(height: 16),
  
                const Text('Giới tính:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                     Expanded(
                       child: RadioListTile<String>(
                         title: const Text('Nam'),
                         value: 'male',
                         groupValue: _gender,
                         onChanged: (v) => setState(() => _gender = v!),
                         contentPadding: EdgeInsets.zero,
                       ),
                     ),
                     Expanded(
                       child: RadioListTile<String>(
                         title: const Text('Nữ'),
                         value: 'female',
                         groupValue: _gender,
                         onChanged: (v) => setState(() => _gender = v!),
                         contentPadding: EdgeInsets.zero,
                       ),
                     ),
                  ],
                ),
  
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Tạo Gia Đình', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8B1A1A),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw 'Người dùng chưa đăng nhập';
      }

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _familyNameController.text.trim(),
        'description': _addressController.text.trim(),
        'owner_id': user.id,
        'type': 'family',
        'qr_code': 'FAM-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      }).select().single().timeout(const Duration(seconds: 10));
      
      final clanId = clanRes['id'];

      // 2. Create Root Member (The User)
      await Supabase.instance.client.from('family_members').insert({
        'clan_id': clanId,
        'full_name': _memberNameController.text.trim(),
        'birth_date': _dob?.toIso8601String(),
        'gender': _gender,
        'is_alive': true,
        'profile_id': user.id,
        'generation_level': 1,
        'is_root': true,
      }).timeout(const Duration(seconds: 10));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Thành công'),
            content: const Text('Đã tạo gia đình thành công!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  // Pop main page (create options)
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop();

                  // Navigate to the new family
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClanTreePage(
                        clanId: clanId,
                        clanName: _familyNameController.text.trim(),
                        ownerId: user.id,
                        clanType: 'family',
                      ),
                    ),
                  );
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Lỗi'),
            content: Text('Không thể tạo gia đình: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
