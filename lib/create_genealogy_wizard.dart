import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'pages/create_family_form.dart';

class CreateGenealogyWizard extends StatefulWidget {
  final bool isClan; // true for Clan (Dòng họ), false for Family (Gia đình)

  const CreateGenealogyWizard({super.key, required this.isClan});

  @override
  State<CreateGenealogyWizard> createState() => _CreateGenealogyWizardState();
}

class _CreateGenealogyWizardState extends State<CreateGenealogyWizard> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Meta Data
  final _clanNameController = TextEditingController();
  final _clanDescController = TextEditingController();

  // Generations Data
  // 5 Generations: Tứ Đại, Tam Đại, Ông Nội, Bố, Con
  final List<String> _genTitles = [
    'Tứ Đại (Ông Cố)',
    'Tam Đại (Ông Sơ)',
    'Ông Nội',
    'Bố',
    'Con (Bạn)',
  ];

  // Controllers for each generation (Male & Female)
  late List<TextEditingController> _maleControllers;
  late List<TextEditingController> _femaleControllers;

  @override
  void initState() {
    super.initState();
    // Initialize 5 pairs of controllers
    _maleControllers = List.generate(5, (_) => TextEditingController());
    _femaleControllers = List.generate(5, (_) => TextEditingController());
    
    _initializeData();
  }

  @override
  void dispose() {
    _clanNameController.dispose();
    _clanDescController.dispose();
    for (var c in _maleControllers) c.dispose();
    for (var c in _femaleControllers) c.dispose();
    super.dispose();
  }

  void _initializeData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null && profile['full_name'] != null) {
        setState(() {
          // Pre-fill the last generation (Con/User) with profile name
          _maleControllers[4].text = profile['full_name'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isClan) {
       return const CreateFamilyForm();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Gia Phả (5 Đời)'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMetaResection(),
            const SizedBox(height: 24),
            const Divider(thickness: 2),
            const SizedBox(height: 16),
            ...List.generate(5, (index) => _buildGenerationRow(index)),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaResection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin Dòng họ',
          style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _clanNameController,
          decoration: const InputDecoration(
            labelText: 'Tên Dòng Họ',
            hintText: 'VD: Họ Nguyễn - Chi 2',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.stars),
          ),
          validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập tên dòng họ' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _clanDescController,
          decoration: const InputDecoration(
            labelText: 'Mô tả / Địa chỉ',
            hintText: '...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildGenerationRow(int index) {
    // 0: Tu Dai, ..., 4: Con
    final title = _genTitles[index];
    final isUser = index == 4;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                if (isUser) ...[
                  const Spacer(),
                  const Chip(label: Text('Bạn'), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white), visualDensity: VisualDensity.compact),
                ]
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maleControllers[index],
                    decoration: InputDecoration(
                      labelText: isUser ? 'Họ tên (Bạn)' : 'Tên Ông (Chồng)',
                      hintText: '...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.man),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) {
                      if (isUser && (val == null || val.trim().isEmpty)) {
                        return 'Bắt buộc';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _femaleControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Tên Bà (Vợ)',
                      hintText: '...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.woman),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (100 * index).ms).slideX(begin: 0.1);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitForm,
        icon: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.check),
        label: Text(_isLoading ? 'Đang tạo...' : 'Hoàn tất & Tạo Gia Phả'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng kiểm tra lại thông tin')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Chưa đăng nhập';

      // 1. Create Clan
      final clanRes = await Supabase.instance.client.from('clans').insert({
        'name': _clanNameController.text.trim(),
        'description': _clanDescController.text.trim(),
        'owner_id': user.id,
        'type': widget.isClan ? 'clan' : 'family',
        'qr_code': _generateRandomCode(8),
      }).select().single();
      
      final clanId = clanRes['id'];

      // 2. Insert Members (Top Down)
      // Order: Tứ Đại (Index 0) -> Tam Đại (1) -> Ông Nội (2) -> Bố (3) -> Con (4, User)
      // Logic: Ancestors (0,1,2,3) -> Self (4)
      int? previousFatherId;

      for (int i = 0; i < 5; i++) {
        final maleName = _maleControllers[i].text.trim();
        final femaleName = _femaleControllers[i].text.trim();
        
        // "Con" (Self) is always required.
        // For ancestors: If user provided a name, create them.
        // If user skipped (empty name), do we break chain?
        // To ensure the tree is connected, we should probably create "Unknown" nodes if there are gaps 
        // between a known ancestor and the user?
        // But for this wizard, let's assume if they fill Tứ Đại, they fill the rest. 
        // Or if they leave blank, we insert "Không rõ" to maintain father_id chain.
        // Let's go with "Không rõ" if empty, except for Self which is validated.
        
        String finalMaleName = maleName.isEmpty ? (i == 4 ? 'Bạn' : 'Không rõ') : maleName;
        
        // Create Husband (Male)
        final husData = {
          'clan_id': clanId,
          'full_name': finalMaleName,
          'gender': 'male',
          'is_alive': (i == 4), // Only Self is alive by default in this bulk create? Or let user edit later.
          'father_id': previousFatherId,
        };
        
        // If Self
        if (i == 4) {
          husData['profile_id'] = user.id;
          husData['is_alive'] = true;
        }

        final husRes = await Supabase.instance.client
            .from('family_members')
            .insert(husData)
            .select()
            .single();
        
        final husId = husRes['id'];
        previousFatherId = husId; // Pass to next generation as father

        // Create Wife (Female) if provided
        if (femaleName.isNotEmpty) {
           final wifeData = {
             'clan_id': clanId,
             'full_name': femaleName,
             'gender': 'female',
             'is_alive': (i == 4),
             'spouse_id': husId, // Link to husband
           };
           
           final wifeRes = await Supabase.instance.client
              .from('family_members')
              .insert(wifeData)
              .select()
              .single();
           
           // Update Husband link
           await Supabase.instance.client
              .from('family_members')
              .update({'spouse_id': wifeRes['id']})
              .eq('id', husId);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close Wizard
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo gia phả thành công!')));
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
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[(DateTime.now().microsecondsSinceEpoch * (index + 1)) % chars.length]).join();
  }
}
