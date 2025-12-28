import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_page.dart';
import 'dashboard_page.dart';
import 'recovery_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  bool _rememberMe = true; // Default to true

  Future<void> _signIn() async {
    final input = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    
    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập SĐT hoặc CCCD và mật khẩu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String cleanPhone = input.replaceAll(RegExp(r'\D'), '');
      
      // Trường hợp nhập CCCD (12 số) -> Tìm SĐT
      if (cleanPhone.length == 12) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('phone')
            .eq('vnccid', cleanPhone)
            .maybeSingle();
            
        if (data == null || data['phone'] == null) {
          throw const AuthException('Không tìm thấy tài khoản với số CCCD này');
        }
        
        // Lấy SĐT tìm được từ profile
        cleanPhone = data['phone'].toString().replaceAll(RegExp(r'\D'), '');
      }
      
      // Luôn dùng SĐT để tạo 'fake email' đăng nhập
      // (Bỏ hỗ trợ đăng nhập trực tiếp bằng email thực ở ô này)
      final email = 'vn$cleanPhone@gmail.com'; 
      
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        String msg = 'Đăng nhập thất bại';
        if (error.message.contains('Invalid login')) {
          msg = 'Thông tin đăng nhập không chính xác';
        } else if (error.message.contains('Email not confirmed')) {
          msg = 'Lỗi cấu hình: Vui lòng tắt "Confirm Email" trong Supabase';
        } else {
          msg = error.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi không xác định. Vui lòng thử lại.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    try {
      // For Web, this triggers a redirect.
      // Make sure Site URL and Redirect URLs are configured in Supabase Dashboard.
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'http://localhost:5000/callback', // Or your deployed URL
      );
      // On Web, the page will redirect, so no navigation code needed here usually.
      // However, if it's a popup flow or native, we might need to handle state.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng nhập Google: $e')),
        );
      }
    }
  }

  void _showFindAccountDialog() {
    final vnccidController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm lại số điện thoại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập số CCCD/VNCCID bạn đã dùng để đăng ký:'),
            const SizedBox(height: 12),
            TextField(
              controller: vnccidController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Số CCCD',
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final id = vnccidController.text.trim();
              if (id.isEmpty) return;
              if (id.length != 12) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VNCCID phải đủ 12 số')));
                return;
              }
              
              try {
                // Tìm kiếm trong bảng profiles (bảng này công khai policy select true)
                final data = await Supabase.instance.client
                    .from('profiles')
                    .select('phone, full_name')
                    .eq('vnccid', id)
                    .maybeSingle();

                if (context.mounted) {
                  Navigator.pop(context); // Đóng dialog nhập
                  if (data != null) {
                    final phone = data['phone'];
                    final name = data['full_name'];
                    // Hiện kết quả
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Tìm thấy tài khoản'),
                        content: Text('Thành viên: $name\nSố điện thoại đăng ký: $phone'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không tìm thấy tài khoản với CCCD này')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Tra cứu'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordEmailDialog() {
    final emailController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Khôi phục mật khẩu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nhập Email bạn đã liên kết để nhận link đặt lại mật khẩu:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email liên kết',
                      hintText: 'vidu@gmail.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email không hợp lệ')));
                      return;
                    }

                    setStateDialog(() => isSending = true);
                    try {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi email khôi phục! Vui lòng kiểm tra hộp thư.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setStateDialog(() => isSending = false);
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                  child: isSending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Gửi yêu cầu'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- End of Page State ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background is now handled by Theme (Cream color)
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    )
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Đăng Nhập',
                style: Theme.of(context).textTheme.displayMedium,
              ).animate().fadeIn().slideY(begin: 0.3),
              
              const SizedBox(height: 8),
              Text(
                'Quản Lý Việc Họ & Giỗ Chạp',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 48),

              // Phone/CCCD Input
              _buildTextField(
                controller: _identifierController,
                label: 'Số điện thoại hoặc CCCD',
                icon: Icons.person_outline_rounded,
                hint: '0912... hoặc số CCCD',
                keyboardType: TextInputType.number,
              ).animate().fadeIn(delay: 300.ms).slideX(),

              const SizedBox(height: 16),

              // Password Input
              _buildTextField(
                controller: _passwordController,
                label: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isObscure: _isObscure,
                onToggleObscure: () => setState(() => _isObscure = !_isObscure),
              ).animate().fadeIn(delay: 400.ms).slideX(),
              
              const SizedBox(height: 8),
              Row(
                children: [
                   Transform.scale(
                     scale: 0.9,
                     child: Checkbox(
                      value: _rememberMe,
                      activeColor: Theme.of(context).primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                     ),
                   ),
                   Text('Ghi nhớ đăng nhập vô thời hạn', style: GoogleFonts.inter(fontSize: 13, color: Colors.brown.shade800)),
                ],
              ),
              const SizedBox(height: 4),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryPage()));
                  },
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('Khôi phục mật khẩu qua VNCCID', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
                ),
              ),

              const SizedBox(height: 16),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('ĐĂNG NHẬP'),
                ),
              ).animate().fadeIn(delay: 500.ms).moveY(begin: 10),
              
              const SizedBox(height: 16),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => const RegisterPage()),
                     );
                  },
                  child: const Text('ĐĂNG KÝ TÀI KHOẢN MỚI'),
                ),
              ).animate().fadeIn(delay: 600.ms).moveY(begin: 10),

              const SizedBox(height: 32),

              // Or Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.brown.withOpacity(0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'HOẶC',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.brown.withOpacity(0.4)),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.brown.withOpacity(0.2))),
                ],
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 24),

              // Google Login Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _googleSignIn,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.brown.withOpacity(0.2)),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                    height: 24,
                  ),
                  label: Text(
                    'Tiếp tục với Gmail',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).moveY(begin: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? isObscure : false,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.brown.shade900),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.brown.shade300,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }
}
