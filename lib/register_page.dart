import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vnccidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otherCityController = TextEditingController(); // Cho trường hợp nhập tay
  
  String? _selectedCity;
  // Danh sách 63 tỉnh thành Việt Nam
  final List<String> _cities = [
    'Hà Nội', 'TP. Hồ Chí Minh', 'Hải Phòng', 'Đà Nẵng', 'Cần Thơ',
    'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 
    'Bắc Ninh', 'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 
    'Bình Thuận', 'Cà Mau', 'Cao Bằng', 'Đắk Lắk', 'Đắk Nông', 
    'Điện Biên', 'Đồng Nai', 'Đồng Tháp', 'Gia Lai', 'Hà Giang', 
    'Hà Nam', 'Hà Tĩnh', 'Hải Dương', 'Hậu Giang', 'Hòa Bình', 
    'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu', 
    'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 
    'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 
    'Quảng Bình', 'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 
    'Sóc Trăng', 'Sơn La', 'Tây Ninh', 'Thái Bình', 'Thái Nguyên', 
    'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang', 'Trà Vinh', 'Tuyên Quang', 
    'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái',
    'Khác'
  ];

  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vnccidController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otherCityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate Password Match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
      );
      return;
    }

    // Logic lấy địa chỉ: Nếu chọn 'Khác' thì lấy từ ô nhập tay
    String finalAddress = _selectedCity ?? '';
    if (_selectedCity == 'Khác') {
      if (_otherCityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập nơi ở cụ thể')),
        );
        return;
      }
      finalAddress = _otherCityController.text.trim();
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final vnccid = _vnccidController.text.trim();
      final password = _passwordController.text.trim();
      
      // Chiến lược Fake Email: 0912... -> vn0912...@gmail.com
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final fakeEmail = 'vn$cleanPhone@gmail.com';

      // 1. Đăng ký Auth User
      final res = await Supabase.instance.client.auth.signUp(
        email: fakeEmail,
        password: password,
        data: {
          'full_name': name,
          'phone': phone,
          'vnccid': vnccid,
          'current_address': finalAddress, 
          'avatar_url': '', 
        },
      );

      // 2. Kiểm tra kết quả
      if (res.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công! Đang đăng nhập...'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Đợi 1 chút để Trigger Database (nếu có) kịp chạy tạo Profile
          await Future.delayed(const Duration(seconds: 1));

          // Chuyển hướng vào Dashboard
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = 'Lỗi đăng ký: ${e.message}';
        if (e.message.contains('security purposes')) {
          message = 'Hệ thống đang bận. Vui lòng thử lại sau 60 giây.';
        } else if (e.message.contains('Password')) {
          message = 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu khác.';
        } else if (e.message.contains('User already registered')) {
          message = 'Số điện thoại này đã được đăng ký.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Icon Small
                Align(
                  child: Container(
                    height: 80, 
                    width: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.cover, 
                      )
                    ),
                  ).animate().scale(),
                ),

                Text(
                  'Đăng Ký Thành Viên',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ).animate().fadeIn().moveY(begin: 10),

                const SizedBox(height: 8),
                Text(
                  'Tham gia kết nối dòng họ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 32),

                // Full Name
                _buildTextField(
                  controller: _nameController,
                  label: 'Họ và Tên',
                  icon: Icons.person_outline_rounded,
                  hint: 'Nguyễn Văn A',
                  validator: (v) => v!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                ),

                const SizedBox(height: 16),
                
                // Phone
                _buildTextField(
                  controller: _phoneController,
                  label: 'Số điện thoại',
                  icon: Icons.phone_android_rounded,
                  hint: '0912...',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => (v == null || v.length != 10) ? 'Số điện thoại phải đúng 10 số' : null,
                ),

                const SizedBox(height: 16),

                // VNCCID
                _buildTextField(
                  controller: _vnccidController,
                  label: 'Số CCCD / VNCCID',
                  icon: Icons.badge_outlined,
                  hint: '00109xxxxxxx',
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (v) => (v == null || v.length != 12) ? 'Số CCCD phải đúng 12 số' : null,
                ),

                const SizedBox(height: 16),

                // City / Province Selector
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Nơi ở hiện tại',
                    prefixIcon: Icon(Icons.location_city, color: Theme.of(context).primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  isExpanded: true, // Needed for long list
                  menuMaxHeight: 400, // Limit height
                  value: _selectedCity,
                  items: _cities.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v),
                  validator: (v) => v == null ? 'Vui lòng chọn nơi ở' : null,
                ),

                // Show manual input if 'Khác' is selected
                if (_selectedCity == 'Khác') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _otherCityController,
                    label: 'Nhập nơi ở cụ thể',
                    icon: Icons.edit_location_alt_rounded,
                    validator: (v) => v!.isEmpty ? 'Vui lòng nhập nơi ở' : null,
                  ),
                ],

                const SizedBox(height: 16),

                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Mật khẩu',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  isObscure: _isObscure,
                  onToggleObscure: () => setState(() => _isObscure = !_isObscure),
                  validator: (v) => v!.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                ),

                const SizedBox(height: 16),

                // Confirm Password
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Xác nhận mật khẩu',
                  icon: Icons.lock_reset_rounded,
                  isPassword: true,
                  isObscure: _isObscure,
                  validator: (v) => v!.isEmpty ? 'Vui lòng xác nhận mật khẩu' : null,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('HOÀN TẤT ĐĂNG KÝ'),
                  ),
                ).animate().fadeIn(delay: 300.ms).moveY(begin: 10),
              ],
            ),
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
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? isObscure : false,
      keyboardType: keyboardType,
      validator: validator,
      maxLength: maxLength,
      style: GoogleFonts.inter(color: Colors.brown.shade900),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: "", // Hide character counter
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
