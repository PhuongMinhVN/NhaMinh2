import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import 'models/clan_event.dart';
import 'repositories/event_repository.dart';
import 'clan_events_page.dart';
import 'create_genealogy_wizard.dart'; 
import 'family_tree_welcome_page.dart';
import 'widgets/event_list_widget.dart';
import 'pages/events/add_event_page.dart';
import 'scan_qr_page.dart';
import 'notifications_page.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'pages/join_request_page.dart';
import 'repositories/clan_repository.dart';
import 'widgets/dashboard_action_button.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final user = Supabase.instance.client.auth.currentUser;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/'); 
    }
  }

  @override
  void initState() {
    super.initState();
    // Removed legacy profile check
  }

  // Legacy profile code removed


  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nhà Mình', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateOptions,
            tooltip: 'Tạo Gia Phả',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
               // Sửa: Đợi kết quả trả về từ màn hình Scan
               final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQrPage(returnScanData: true)));
               if (result != null && result is String) {
                 _processJoinCode(result);
               }
            },
            tooltip: 'Quét QR',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
            },
            tooltip: 'Thông báo',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showEditProfileDialog(),
            tooltip: 'Hồ sơ cá nhân',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(),
              tooltip: 'Đăng xuất',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Xin chào, ${user?.email?.split('@')[0] ?? 'Thành viên'}!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ).animate().fadeIn().slideX(),
              const SizedBox(height: 4),
              Text(
                'Chúc một ngày tốt lành bên gia đình.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.brown.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 32),

              // Main Layout
              isWide 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildClanAffairsCard()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildActionButtonsColumn()),
                    ],
                  )
                : Column(
                    children: [
                      _buildClanAffairsCard(),
                      const SizedBox(height: 24),
                      _buildActionButtonsColumn(),
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          'Power by PMVN 2025',
                          style: GoogleFonts.inter(
                            fontSize: 12, 
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClanAffairsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black12,
      child: Container(
        // height removed for dynamic sizing
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: Colors.brown.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, color: Theme.of(context).primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Sự Kiện & Giỗ Chạp',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Theme.of(context).primaryColor,
                      tooltip: 'Thêm sự kiện',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddEventPage()),
                        ).then((value) {
                          if (value == true) {
                            setState(() {}); // Trigger rebuild/refresh if needed
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                )
              ],
            ),
            const Divider(height: 32, thickness: 1),
            
            // New Event List Widget
            const EventListWidget(),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  void _showEditProfileDialog() async {
    // 1. Fetch current data
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      final data = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
      if (mounted) Navigator.pop(context); // Hide loading

      final nameCtrl = TextEditingController(text: data['full_name']);
      final phoneCtrl = TextEditingController(text: data['phone']);
      final vnccidCtrl = TextEditingController(text: data['vnccid']);
      final addressCtrl = TextEditingController(text: data['current_address']);
      final passwordCtrl = TextEditingController(); // Để đổi mật khẩu
      
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Hồ Sơ Cá Nhân'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 _buildDialogTextField(nameCtrl, 'Họ và Tên', Icons.person),
                 const SizedBox(height: 12),
                 _buildDialogTextField(phoneCtrl, 'Số điện thoại', Icons.phone, type: TextInputType.phone),
                 const SizedBox(height: 12),
                 _buildDialogTextField(vnccidCtrl, 'Số CCCD', Icons.badge, type: TextInputType.number),
                 const SizedBox(height: 12),
                 _buildDialogTextField(addressCtrl, 'Nơi ở hiện tại', Icons.location_on),
                 const SizedBox(height: 12),
                 _buildDialogTextField(passwordCtrl, 'Mật khẩu mới (Nếu muốn đổi)', Icons.lock_outline, isObscure: true),
                 const SizedBox(height: 24),
                 
                 // BUTTONS
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton.icon(
                     onPressed: () {
                        // Show QR Dialog
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Mã QR Cá Nhân', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Container(
                                  width: 200, height: 200,
                                  color: Colors.white,
                                  child: Center(
                                    child: QrImageView(
                                      data: user.id, // User ID as QR Data
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(user.id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                     },
                     icon: const Icon(Icons.qr_code),
                     label: const Text('Mã QR Của Tôi'),
                     style: OutlinedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       foregroundColor: Colors.blue.shade800, 
                       side: BorderSide(color: Colors.blue.shade800),
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),
                 
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog hồ sơ
                      _showSecuritySettingsDialog(); // Mở dialog bảo mật
                    },
                    icon: const Icon(Icons.security),
                    label: const Text('Thiết lập Câu hỏi Bảo mật'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFFD32F2F), 
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog hồ sơ
                      _showInheritanceDialog(); 
                    },
                    icon: const Icon(Icons.family_restroom),
                    label: const Text('Di chúc số / Người thừa kế'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog hồ sơ
                      _showClaimInheritanceDialog();
                    },
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Tiếp nhận Thừa kế'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.brown,
                  ),
                ),
                ),
                const SizedBox(height: 12),
                
                // LOGOUT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _signOut(); // Perform sign out
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng Xuất'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                    ),
                  ),
                ),

              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPhone = phoneCtrl.text.trim();
                final newPassword = passwordCtrl.text.trim();
                bool isPasswordChanged = newPassword.isNotEmpty;

                try {
                  // 1. CẬP NHẬT MẬT KHẨU (Nếu có nhập)
                  if (isPasswordChanged) {
                       if (newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu mới phải từ 6 ký tự')));
                          return;
                       }
                       await Supabase.instance.client.auth.updateUser(
                         UserAttributes(password: newPassword)
                       );
                  }

                  // CHECK DUPLICATE VNCCID (CUSTOM LOGIC)
                  final newVnccid = vnccidCtrl.text.trim();
                  if (newVnccid != data['vnccid']) {
                     final duplicate = await Supabase.instance.client
                         .from('profiles')
                         .select('id')
                         .eq('vnccid', newVnccid)
                         .maybeSingle();
                     
                     if (duplicate != null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VNCCID này đã có người sử dụng. Vui lòng kiểm tra lại.')));
                        return;
                     }
                  }

                  // 2. CẬP NHẬT HỒ SƠ 
                  await Supabase.instance.client.from('profiles').update({
                    'full_name': nameCtrl.text.trim(),
                    'phone': newPhone,
                    'vnccid': vnccidCtrl.text.trim(),
                    'current_address': addressCtrl.text.trim(),
                  }).eq('id', user.id);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    
                    String msg = 'Hồ sơ đã được lưu. Hệ thống tự động đồng bộ tài khoản.';
                    if (isPasswordChanged) msg += ' Mật khẩu đã được thay đổi.';
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(msg),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ));
                    
                    setState(() {}); // Refresh UI
                  }
                } catch (e) {
                   String err = e.toString();
                   if (err.contains('weak_password')) {
                     err = 'Mật khẩu quá yếu.';
                   }
                   if (err.contains('violates unique constraint') || err.contains('already exists')) {
                     err = 'SĐT này có thể đã được sử dụng.';
                   }
                   
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                     content: Text('Lỗi: $err'),
                     backgroundColor: Colors.red,
                   ));
                }
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
    }
  }

  void _showSecuritySettingsDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    List<dynamic> questionBank = [];
    List<dynamic> existingAnswers = []; // Check if user already has answers

    try {
      // 1. Fetch Question Bank
      questionBank = await Supabase.instance.client.from('question_bank').select('content');
      
      // 2. Fetch User Answers
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
         existingAnswers = await Supabase.instance.client
             .from('user_security_answers')
             .select()
             .eq('user_id', user.id);
      }

      if (mounted) Navigator.pop(context); // Hide loading
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      return;
    }

    if (questionBank.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hệ thống chưa có ngân hàng câu hỏi.')));
       return;
    }

    if (!mounted) return;

    // A. SHOW VIEW MODE (Nếu đã có câu trả lời)
    if (existingAnswers.isNotEmpty && existingAnswers.length >= 3) {
       _showSecurityInfoViewDialog(existingAnswers);
       return;
    }

    // B. SHOW SETUP MODE (Như cũ)
    _showSecuritySetupDialog(questionBank);
  }

  // --- VIEW MODE ---
  void _showSecurityInfoViewDialog(List<dynamic> answers) {
    final screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AREA TO CAPTURE
              Screenshot(
                controller: screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    children: [
                       const Icon(Icons.security, size: 50, color: Colors.green),
                       const SizedBox(height: 16),
                       Text('BẢO MẬT TÀI KHOẢN', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Text('Lưu lại ảnh này để khôi phục tài khoản khi cần.', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
                       const Divider(height: 32),
                       
                       ...List.generate(answers.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Câu hỏi ${i+1}: ${answers[i]['question']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Trả lời: ${answers[i]['answer']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                       }),
                       
                       const SizedBox(height: 16),
                       Text('User ID: ${Supabase.instance.client.auth.currentUser?.email}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton.icon(
            onPressed: () async {
               // SAVE IMAGE LOGIC WITH GAL
               try {
                  final image = await screenshotController.capture();
                  if (image == null) return;
                  
                  // Gal handles permissions automatically
                  await Gal.putImageBytes(Uint8List.fromList(image), name: "NhaMinh_Security_${DateTime.now().millisecondsSinceEpoch}");
                  
                  if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu ảnh vào Thư viện!'), backgroundColor: Colors.green));
                  }
               } catch (e) {
                  if (e is GalException && e.type == GalExceptionType.accessDenied) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng cấp quyền truy cập Thư viện ảnh.')));
                  } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                  }
               }
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('Lưu Ảnh'),
          ),
        ],
      ),
    );
  }

  // --- SETUP MODE (Tách ra từ hàm cũ) ---
  void _showSecuritySetupDialog(List<dynamic> questionBank) {
    // We need 3 pairs of (Question, Answer)
    final questions = List<String?>.filled(3, null);
    final answersCtrl = List.generate(3, (_) => TextEditingController());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thiết lập Bảo mật'),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Text('Chọn 3 câu hỏi và trả lời để khôi phục tài khoản khi quên mật khẩu.', 
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 16),
                      
                      ...List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: questions[index],
                                hint: Text('Câu hỏi ${index + 1}'),
                                items: questionBank.map<DropdownMenuItem<String>>((q) {
                                  return DropdownMenuItem(
                                    value: q['content'].toString(),
                                    child: Text(q['content'].toString(), overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) => setStateDialog(() => questions[index] = val),
                                validator: (val) => val == null ? 'Vui lòng chọn câu hỏi' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: answersCtrl[index],
                                decoration: InputDecoration(
                                  labelText: 'Câu trả lời của bạn',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập câu trả lời' : null,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Check for duplicate questions
                      final selected = questions.where((q) => q != null).toSet();
                      if (selected.length < 3) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn 3 câu hỏi KHÁC NHAU.')));
                        return;
                      }

                      try {
                        // Prepare data for RPC
                        final questionsData = List.generate(3, (i) => {
                          'question': questions[i],
                          'answer': answersCtrl[i].text.trim()
                        });

                        await Supabase.instance.client.rpc('setup_security_answers', params: {
                          'questions_data': questionsData
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Đã lưu thiết lập! Bạn có thể dùng VNCCID để khôi phục mật khẩu.'),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                  child: const Text('Lưu bảo mật'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildDialogTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, bool isObscure = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }



  Widget _buildEventItem({required String title, required String date, required String description, bool isHighPriority = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighPriority ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isHighPriority ? Colors.red.shade700 : Colors.brown.shade300,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isHighPriority ? Colors.red.shade900 : Colors.brown.shade900,
                  ),
                ),
              ),
              if (isHighPriority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Sắp tới', style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time_filled, size: 14, color: Colors.brown.shade400),
              const SizedBox(width: 4),
              Text(date, style: TextStyle(color: Colors.brown.shade600, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: Colors.brown.shade700, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildActionButtonsColumn() {
    return Column(
      children: [
        DashboardActionButton(
          title: 'Cây Gia Phả',
          subtitle: 'Xem sơ đồ toàn bộ dòng tộc',
          icon: Icons.account_tree_sharp,
          color: const Color(0xFF8B1A1A), // Primary Red
          delay: 500,
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyTreeWelcomePage()));
          },
        ),


      ],
    );
  }

  void _showInheritanceDialog() {
     final vnccidCtrl = TextEditingController();
     final nameCtrl = TextEditingController();
     final phoneCtrl = TextEditingController();
     
     // Load current settings
     Supabase.instance.client.from('inheritance_settings')
       .select()
       .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
       .maybeSingle()
       .then((data) {
          if (data != null && mounted) {
             vnccidCtrl.text = data['heir_vnccid'] ?? '';
             nameCtrl.text = data['heir_full_name'] ?? '';
             phoneCtrl.text = data['heir_phone'] ?? '';
          }
       });

     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Lập Di chúc Số (Thừa kế)'),
         content: SingleChildScrollView(
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text('Chỉ định người thừa kế quản lý tài khoản này nếu bạn không hoạt động trong 1 năm.', 
                 style: TextStyle(fontSize: 13, color: Colors.grey)),
               const SizedBox(height: 16),
               
               TextField(
                 controller: vnccidCtrl,
                 decoration: InputDecoration(
                   labelText: 'VNCCID Người thừa kế',
                   suffixIcon: IconButton(
                     icon: const Icon(Icons.search),
                     onPressed: () async {
                       if (vnccidCtrl.text.length != 12) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VNCCID phải 12 số')));
                          return;
                       }
                       final res = await Supabase.instance.client.from('profiles').select('full_name, phone').eq('vnccid', vnccidCtrl.text).maybeSingle();
                       if (res != null) {
                          nameCtrl.text = res['full_name'] ?? '';
                          phoneCtrl.text = res['phone'] ?? '';
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tìm thấy người dùng!')));
                       } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy ai với VNCCID này.')));
                       }
                     },
                   ),
                   helperText: 'Nhập VNCCID và bấm kính lúp để tìm',
                 ),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 8),
               TextField(
                 controller: nameCtrl,
                 decoration: const InputDecoration(labelText: 'Tên người thừa kế'),
                 readOnly: true, // Should be auto-filled
               ),
               const SizedBox(height: 8),
               TextField(
                 controller: phoneCtrl,
                 decoration: const InputDecoration(labelText: 'SĐT liên hệ'),
                 readOnly: true,
               ),
             ],
           ),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
           ElevatedButton(
             onPressed: () async {
               if (vnccidCtrl.text.isEmpty) return;
               try {
                 await Supabase.instance.client.rpc('register_heir', params: {
                   'heir_vnccid_input': vnccidCtrl.text.trim(),
                   'heir_name_input': nameCtrl.text,
                   'heir_phone_input': phoneCtrl.text
                 });
                 if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                     content: Text('Đã lưu người thừa kế thành công!'),
                     backgroundColor: Colors.green,
                   ));
                 }
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
               }
             },
             child: const Text('Lưu thiết lập'),
           ),
         ],
       ),
     );
  }

  void _showClaimInheritanceDialog() {
    final vnccidCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiếp nhận Thừa kế'),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text('Nhập VNCCID của người để lại di chúc (người quá cố hoặc không hoạt động) để yêu cầu tiếp quản dữ liệu.'),
             const SizedBox(height: 16),
             TextField(
               controller: vnccidCtrl,
               decoration: const InputDecoration(labelText: 'VNCCID người để lại', border: OutlineInputBorder()),
               keyboardType: TextInputType.number,
             ),
           ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ElevatedButton(
            onPressed: () async {
               if (vnccidCtrl.text.isEmpty) return;
               
               // Show loading
               showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
               
               try {
                 final res = await Supabase.instance.client.rpc('claim_inheritance', params: {
                   'target_owner_vnccid': vnccidCtrl.text.trim()
                 });
                 
                 if (mounted) {
                   Navigator.pop(context); // Close loading
                   Navigator.pop(context); // Close input dialog
                   
                   showDialog(context: context, builder: (_) => AlertDialog(
                     title: const Text('Kết quả'),
                     content: Text(res.toString()),
                     actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                   ));
                 }
               } catch (e) {
                 if (mounted) Navigator.pop(context); // Close loading
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
               }
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }
  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
               Text('Tạo mới hoặc Tham gia', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 24),
               
               // --- JOIN SECTION ---
               const Text('Tham gia Gia phả có sẵn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
               const SizedBox(height: 12),
               Row(
                 children: [
                   Expanded(
                     child: InkWell(
                       onTap: () async {
                          Navigator.pop(context);
                          final id = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQrPage(returnScanData: true)));
                          if (id != null && id is String) _processJoinCode(id);
                       },
                       child: Container(
                         height: 100,
                         decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(12), color: Colors.blue.shade50),
                         child: const Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.qr_code_scanner, size: 32, color: Colors.blue),
                             SizedBox(height: 8),
                             Text('Quét mã QR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                           ],
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: InkWell(
                       onTap: () {
                          Navigator.pop(context);
                          _showJoinByIdDialog();
                       },
                       child: Container(
                         height: 100,
                          decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade200), borderRadius: BorderRadius.circular(12), color: Colors.orange.shade50),
                         child: const Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.edit, size: 32, color: Colors.orange),
                             SizedBox(height: 8),
                             Text('Nhập Mã ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ],
               ),
               
               const SizedBox(height: 24),
               const Divider(),
               const SizedBox(height: 12),
               
               // --- CREATE SECTION ---
               const Text('Tạo mới Gia phả', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
               const SizedBox(height: 12),
               ListTile(
                 contentPadding: EdgeInsets.zero,
                 leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.brown.shade100, shape: BoxShape.circle), child: Icon(Icons.account_balance, color: Colors.brown.shade800)),
                 title: const Text('Gia Phả Dòng Họ'),
                 subtitle: const Text('Quy mô lớn, nhiều chi/đời.'),
                 onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGenealogyWizard(isClan: true)));
                 },
               ),
               ListTile(
                 contentPadding: EdgeInsets.zero,
                 leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle), child: Icon(Icons.cottage, color: Colors.green.shade800)),
                 title: const Text('Gia Phả Gia Đình'),
                 subtitle: const Text('Quy mô nhỏ (bố mẹ, con cái).'),
                 onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGenealogyWizard(isClan: false)));
                 },
               ),
             ],
           ),
          ),
        );
      },
    );
  }

  void _showJoinByIdDialog() {
     final idCtrl = TextEditingController();
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Nhập Mã Gia Phả'),
         content: TextField(
           controller: idCtrl,
           decoration: const InputDecoration(labelText: 'Mã Gia Phả (UUID)', border: OutlineInputBorder(), hintText: 'Nhập mã được chia sẻ...'),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
           ElevatedButton(
             onPressed: () {
                if (idCtrl.text.trim().isNotEmpty) {
                   Navigator.pop(context);
                   _processJoinCode(idCtrl.text.trim());
                }
             }, 
             child: const Text('Tiếp tục'),
           )
         ],
       ),
     );
  }

  // Handle both QR and Manual ID
  void _processJoinCode(String code) async {
     // Check if code is CLAN ID
     // Usually valid UUID or specific format.
     // For now, assume code IS the clan ID.
     // Navigate to JoinRequestPage to check validity and join.
     
     // Need to fetch Clan Name/Info first to show in JoinRequestPage? 
     // JoinRequestPage requires a `Clan` object.
     
     showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
     
     try {
       // Code from QR might have prefix. Manual ID is likely raw ID.
       String rawId = code;
       if (code.startsWith('CLAN:')) {
          rawId = code.substring(5);
       }
       
       final clan = await ClanRepository().getClanById(rawId);
       if (mounted) Navigator.pop(context); // hide loading
       
       if (clan != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => JoinRequestPage(clan: clan)));
       } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy Gia phả với mã này.')));
       }
       
     } catch (e) {
       if (mounted) Navigator.pop(context);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
     }
  }
}
