import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/clan_repository.dart';

class FamilyTreeWizardPage extends StatefulWidget {
  final VoidCallback onCreated;
  const FamilyTreeWizardPage({super.key, required this.onCreated});

  @override
  State<FamilyTreeWizardPage> createState() => _FamilyTreeWizardPageState();
}

class _FamilyTreeWizardPageState extends State<FamilyTreeWizardPage> {
  final _pageCtrl = PageController();
  int _step = 0;
  String _mode = 'clan'; // 'clan' or 'family'
  
  final _nameCtrl = TextEditingController(); // Clan Name
  final _rootCtrl = TextEditingController(); // Root Member Name
  final _bioCtrl = TextEditingController();
  bool _isLoading = false;

  void _nextPage() {
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    
    final clanName = _nameCtrl.text.trim().isEmpty ? 'Dòng họ đang cập nhật' : _nameCtrl.text.trim();
    final rootName = _rootCtrl.text.trim().isEmpty ? 'Người khởi tạo (Đang cập nhật)' : _rootCtrl.text.trim();
    
    try {
      await ClanRepository().createClanWithRoot(
        clanName: clanName,
        description: _mode == 'clan' ? 'Dòng họ $clanName' : 'Gia đình $clanName',
        rootName: rootName,
        rootBio: _bioCtrl.text,
        isMaleLineage: true, // Default
        clanType: _mode,
      );
      widget.onCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
             // Progress Bar
             LinearProgressIndicator(value: (_step + 1) / 3, color: Colors.brown),
             Expanded(
               child: PageView(
                 controller: _pageCtrl,
                 physics: const NeverScrollableScrollPhysics(),
                 children: [
                   _buildIntroStep(),
                   _buildModeSelectionStep(),
                   _buildInputStep(),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories, size: 80, color: Colors.brown.shade800),
          const SizedBox(height: 24),
          Text(
            '"Cây có cội, nước có nguồn.\nCon người có tổ, có tông."',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(fontSize: 22, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chào mừng bạn đến với tính năng Gia Phả.\nHãy bắt đầu hành trình tìm về cội nguồn và lưu giữ những giá trị thiêng liêng cho thế hệ mai sau.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bắt đầu'),
          )
        ],
      ),
    );
  }

  Widget _buildModeSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bạn muốn tạo gia phả loại nào?', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          _buildOptionCard(
            title: 'Gia Phả Dòng Họ (Tộc)',
            desc: 'Dành cho việc xây dựng cây gia phả lớn của cả dòng họ, bắt đầu từ Thủy Tổ.',
            icon: Icons.temple_buddhist,
            value: 'clan',
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            title: 'Gia Đình Nhỏ (Gia đình)',
            desc: 'Dành cho việc lưu giữ thông tin gia đình hẹp (Ông bà, Cha mẹ, Con cái).',
            icon: Icons.house,
            value: 'family',
          ),

          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
             style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tiếp tục'),
          )
        ],
      ),
    );
  }

  Widget _buildOptionCard({required String title, required String desc, required IconData icon, required String value}) {
    final isSelected = _mode == value;
    return InkWell(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? Colors.brown : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.brown.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: isSelected ? Colors.brown : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.brown : Colors.black)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.brown),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStep() {
    final isClan = _mode == 'clan';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thông tin khởi tạo', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: isClan ? 'Tên Dòng Họ (Vd: Nguyễn Tộc Hà Đông)' : 'Tên Gia Đình (Vd: Gia đình ông A)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.bookmark),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              isClan ? 'Thông tin Thủy Tổ (Người khai sinh dòng họ)' : 'Thông tin Người đứng đầu (Ông/Bà/Cha/Mẹ)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rootCtrl,
              decoration: const InputDecoration(
                labelText: 'Họ và Tên đầy đủ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiểu sử / Ghi chú (Tùy chọn)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
        
            const SizedBox(height: 48),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hoàn tất & Tạo Cây'),
                )
          ],
        ),
      ),
    );
  }
}
