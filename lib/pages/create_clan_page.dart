import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CreateClanPage extends StatefulWidget {
  const CreateClanPage({super.key});

  @override
  State<CreateClanPage> createState() => _CreateClanPageState();
}

class _CreateClanPageState extends State<CreateClanPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _clanNameController = TextEditingController();
  final _ancestorNameController = TextEditingController(); // Viễn Tổ / Thủy Tổ
  final _ancestorTitleController = TextEditingController(text: 'Viễn Tổ'); 
  
  // Note about complexity: "Thuỷ tổ A . Khi sát nhập với dòng họ B... thì đánh dấu dòng họ B là thuỷ tổ rồi đến đời thứ 2..."
  // Initial creation: Just create the Root Ancestor.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành Lập Dòng Họ'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông tin Dòng Họ',
                style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900),
              ),
              const SizedBox(height: 8),
              const Text('Dòng họ sẽ bắt đầu từ một vị Tổ Tiên (Thủy Tổ/Viễn Tổ). Đây là gốc rễ để các chi nhánh khác sát nhập vào sau này.'),
              const SizedBox(height: 24),

              TextFormField(
                controller: _clanNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên Dòng Họ',
                  hintText: 'VD: Dòng họ Nguyễn (Hà Đông)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.temple_buddhist),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên dòng họ' : null,
              ),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Vị Tổ Tiên Đầu Tiên (Gốc)',
                style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _ancestorTitleController,
                decoration: const InputDecoration(
                  labelText: 'Danh xưng (Chức vị)',
                  helperText: 'VD: Viễn Tổ, Thủy Tổ, Cao Tổ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _ancestorNameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và Tên Tổ Tiên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên tổ tiên' : null,
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Tạo Dòng Họ Mới'),
                ),
              ),
            ],
          ).animate().fadeIn(),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _clanNameController.text.trim(),
        'owner_id': user.id,
        'type': 'clan', // Explicitly 'clan'
        'qr_code': 'CLAN-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      }).select().single();
      final clanId = clanRes['id'];

      // 2. Create Root Ancestor (The User creates it, but is likely NOT the ancestor themselves, usually)
      // HOWEVER, the user asked: "Mặc định người tạo là Thuỷ tổ A" (Wait, usually user is alive, ancestor is dead long ago).
      // "Mặc định người tạo là Thuỷ tổ A . Khi sát nhập với dòng họ B... thì đánh dấu dòng họ B là thuỷ tổ"
      // It seems the user implies the CREATOR is the ROOT of this specific tree segment initially?
      // "Mặc định người tạo là Thuỷ tổ A" -> "Default the creator is Ancestor A".
      // This is ambiguous. Does "Người tạo" mean the User Account? Or the person A they are entering?
      // Usually a user creates a clan starting from themselves or their known ancestor.
      // Re-reading: "Mặc định người tạo là Thuỷ tổ A".
      // Let's assume the Creator User is mapped to the Root Member A for this specific "Branch" created.
      // If the user intends to create a long-dead ancestor, they should just name it.
      // BUT, if the user says "Người tạo (User) là Thủy Tổ A", it implies the user IS the root of this tree.
      // Let's allow the form to decide. I'll bind the User Profile to this Root Member.
      
      final ancestorRes = await Supabase.instance.client.from('family_members').insert({
        'clan_id': clanId,
        'full_name': _ancestorNameController.text.trim(),
        'is_alive': true, // Assuming active user or close ancestor
        'gender': 'male',
        'profile_id': user.id, // User owns this root node
        'is_root': true,
        'generation_number': 1,
        'title': _ancestorTitleController.text.trim(),
        'relation_type': 'blood',
      }).select().single();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo dòng họ thành công!')));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
