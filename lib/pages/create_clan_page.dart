import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../clan_tree_page.dart';

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
      body: SafeArea(
        child: SingleChildScrollView(
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Người dùng chưa đăng nhập';

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _clanNameController.text.trim(),
        'owner_id': user.id,
        'type': 'clan', // Explicitly 'clan'
        'qr_code': 'CLAN-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      }).select().single().timeout(const Duration(seconds: 10));
      final clanId = clanRes['id'];

      // 2. Create Root Ancestor
      await Supabase.instance.client.from('family_members').insert({
        'clan_id': clanId,
        'full_name': _ancestorNameController.text.trim(),
        'is_alive': true, 
        'gender': 'male',
        'profile_id': user.id, 
        'is_root': true,
        'generation_level': 1,
        'title': _ancestorTitleController.text.trim(),
        'relation_type': 'blood',
      }).timeout(const Duration(seconds: 10));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Thành công'),
            content: const Text('Đã tạo dòng họ thành công!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  // Pop main page
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();

                  // Navigate to the new clan
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClanTreePage(
                        clanId: clanId,
                        clanName: _clanNameController.text.trim(),
                        ownerId: user.id,
                        clanType: 'clan',
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
            content: Text('Không thể tạo dòng họ: $e'),
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
