import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateFamilyForm extends StatefulWidget {
  const CreateFamilyForm({super.key});

  @override
  State<CreateFamilyForm> createState() => _CreateFamilyFormState();
}

class _CreateFamilyFormState extends State<CreateFamilyForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _paternalGrandpa = TextEditingController();
  final _paternalGrandma = TextEditingController();
  final _maternalGrandpa = TextEditingController();
  final _maternalGrandma = TextEditingController();
  final _fatherName = TextEditingController(); // Derived/Editable
  final _motherName = TextEditingController(); // Derived/Editable
  final _fatherAlive = ValueNotifier<bool>(true);
  final _motherAlive = ValueNotifier<bool>(true);
  
  // Children List - Dynamic
  final List<TextEditingController> _childrenNames = [TextEditingController()];
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
  
  void _loadProfile() async {
     // Optional: Pre-fill self? 
     // We assume the user is ONE of the children or they are the parent?
     // User request structure: 1. Ong Noi, 2. Ba Noi, 3. Ong Ngoai, 4. Ba Ngoai, 5. Con (nhieu)
     // Usually User is either the Father/Mother or one of the Children.
     // Let's pre-fill "Me" into the first child slot if profile found.
     final user = Supabase.instance.client.auth.currentUser;
     if (user != null) {
        final profile = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null && profile['full_name'] != null) {
           _childrenNames[0].text = profile['full_name'];
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Cây Gia Đình')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _buildSectionHeader('1. Bên Nội', Icons.male),
               _buildInputPair('Ông Nội', _paternalGrandpa, 'Bà Nội', _paternalGrandma),
               
               const SizedBox(height: 24),
               _buildSectionHeader('2. Bên Ngoại', Icons.female),
               _buildInputPair('Ông Ngoại', _maternalGrandpa, 'Bà Ngoại', _maternalGrandma),

               const SizedBox(height: 24),
               _buildSectionHeader('3. Bố Mẹ (Kết nối)', Icons.favorite),
               _buildParentSection(),

               const SizedBox(height: 24),
               _buildSectionHeader('4. Các Con', Icons.child_care),
               _buildChildrenSection(),
               
               const SizedBox(height: 48),
               ElevatedButton(
                 onPressed: _isLoading ? null : _submit,
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   backgroundColor: Colors.brown,
                   foregroundColor: Colors.white,
                 ),
                 child: _isLoading 
                   ? const CircularProgressIndicator(color: Colors.white)
                   : const Text('HOÀN TẤT & TẠO CÂY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
               const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.brown, size: 28),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
          const Expanded(child: Divider(indent: 16, thickness: 2)),
        ],
      ),
    );
  }

  Widget _buildInputPair(String label1, TextEditingController ctrl1, String label2, TextEditingController ctrl2) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: ctrl1,
            decoration: InputDecoration(labelText: label1, border: const OutlineInputBorder(), hintText: '...'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: ctrl2,
            decoration: InputDecoration(labelText: label2, border: const OutlineInputBorder(), hintText: '...'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildParentSection() {
    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Father
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fatherName,
                    decoration: const InputDecoration(
                      labelText: 'Bố (Con Ông Nội)',
                      prefixIcon: Icon(Icons.man),
                      border: OutlineInputBorder(),
                      fillColor: Colors.white, filled: true,
                    ),
                  ),
                ),
                // Alive check?
              ],
            ),
            const SizedBox(height: 8),
            const Row(children: [Expanded(child: Divider()), Icon(Icons.favorite, color: Colors.red, size: 16), Expanded(child: Divider())]),
            const SizedBox(height: 8),
            // Mother
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _motherName,
                    decoration: const InputDecoration(
                      labelText: 'Mẹ (Con Ông Ngoại)',
                      prefixIcon: Icon(Icons.woman),
                      border: OutlineInputBorder(),
                      fillColor: Colors.white, filled: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '* Bố là con của Ông Nội & Bà Nội. Mẹ là con của Ông Ngoại & Bà Ngoại.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChildrenSection() {
     return Column(
       children: [
         ..._childrenNames.asMap().entries.map((entry) {
             final index = entry.key;
             final ctrl = entry.value;
             return Padding(
               padding: const EdgeInsets.only(bottom: 12),
               child: Row(
                 children: [
                   CircleAvatar(
                     radius: 12, 
                     backgroundColor: Colors.brown.shade200, 
                     child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: TextFormField(
                       controller: ctrl,
                       decoration: InputDecoration(
                         labelText: 'Tên người con thứ ${index + 1}',
                         border: const OutlineInputBorder(),
                         suffixIcon: index > 0 
                            ? IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _childrenNames.removeAt(index)))
                            : null
                       ),
                     ),
                   )
                 ],
               ),
             );
         }),
         TextButton.icon(
           onPressed: () => setState(() => _childrenNames.add(TextEditingController())),
           icon: const Icon(Icons.add),
           label: const Text('Thêm người con'),
         )
       ],
     );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Create Clan/Family Container
      final clanName = _fatherName.text.isNotEmpty ? 'Gia đình ${_fatherName.text}' : 'Gia đình Mới';
      final clanRes = await client.from('clans').insert({
          'name': clanName,
          'type': 'family',
          'description': 'Gia phả gia đình nhỏ',
          'owner_id': user.id,
      }).select().single();
      final clanId = clanRes['id'];

      // 2. Create Grandparents (Gen 1)
      // Paternal
      final patGrandpaRes = await _insertMember(client, clanId, _paternalGrandpa.text, 'male', null, title: 'Ông Nội');
      final patGrandmaRes = await _insertMember(client, clanId, _paternalGrandma.text, 'female', null, spouseId: patGrandpaRes?['id'], title: 'Bà Nội');
      if (patGrandpaRes != null && patGrandmaRes != null) {
          // Link Grandpa spouse
          await client.from('family_members').update({'spouse_id': patGrandmaRes['id']}).eq('id', patGrandpaRes['id']);
      }

      // Maternal
      final matGrandpaRes = await _insertMember(client, clanId, _maternalGrandpa.text, 'male', null, title: 'Ông Ngoại');
      final matGrandmaRes = await _insertMember(client, clanId, _maternalGrandma.text, 'female', null, spouseId: matGrandpaRes?['id'], title: 'Bà Ngoại');
      if (matGrandpaRes != null && matGrandmaRes != null) {
          await client.from('family_members').update({'spouse_id': matGrandmaRes['id']}).eq('id', matGrandpaRes['id']);
      }

      // 3. Create Parents (Gen 2)
      // Father -> Child of PatGrandpa
      final fatherRes = await _insertMember(client, clanId, _fatherName.text, 'male', patGrandpaRes?['id'], title: 'Bố');
      
      // Mother -> Child of MatGrandpa
      final motherRes = await _insertMember(client, clanId, _motherName.text, 'female', matGrandpaRes?['id'], title: 'Mẹ'); // Mother is daughter of maternal grandpa
      
      // Link Parents Spouses
      if (fatherRes != null && motherRes != null) {
         await client.from('family_members').update({'spouse_id': motherRes['id']}).eq('id', fatherRes['id']);
         await client.from('family_members').update({'spouse_id': fatherRes['id']}).eq('id', motherRes['id']);
      }
      
      // 4. Create Children (Gen 3)
      for (var ctrl in _childrenNames) {
         if (ctrl.text.trim().isNotEmpty) {
             await _insertMember(client, clanId, ctrl.text, 'male', fatherRes?['id'], title: 'Con');
         }
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo gia đình thành công!')));
         Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _insertMember(
    SupabaseClient client, 
    String clanId, 
    String name, 
    String gender, 
    int? fatherId, {
    int? spouseId,
    String? title,
  }) async {
     String finalName = name.trim();
     if (finalName.isEmpty) return null;
     if (finalName == '...') return null; 

     return await client.from('family_members').insert({
       'clan_id': clanId,
       'full_name': finalName,
       'gender': gender,
       'father_id': fatherId,
       'spouse_id': spouseId,
       'is_alive': true,
       'title': title, // Save the role label
     }).select().single();
  }
}
