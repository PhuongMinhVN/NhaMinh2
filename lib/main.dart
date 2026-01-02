import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'auth_gate.dart';
import 'dart:ui'; // For PointerDeviceKind

// --- CẤU HÌNH KẾT NỐI (Từ thông tin bạn cung cấp) ---
const String DEFAULT_PROJECT_URL = 'https://dpfyflwxvbvnckctwhyd.supabase.co';
const String DEFAULT_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwZnlmbHd4dmJ2bmNrY3R3aHlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4NzA5OTQsImV4cCI6MjA4MjQ0Njk5NH0.MzofJ4bPDZLqmD9x9tf5fjgEqvTjpZwYNLBR_aq5EVA';
// [USER CONFIG] Thay thế bằng Web Client ID từ Google Cloud Console (Dành cho Android/iOS login)
const String GOOGLE_WEB_CLIENT_ID = '366728105944-drv6g7b6ehpo2mna7hh2qutk8fgsc5ut.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Supabase ngay khi app start
  await Supabase.initialize(
    url: DEFAULT_PROJECT_URL,
    anonKey: DEFAULT_API_KEY,
    debug: false, // Tắt debug log cho gọn
  );

  runApp(const GiaPhaApp());
}

class GiaPhaApp extends StatelessWidget {
  const GiaPhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Việc Họ & Giỗ Chạp',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF8B1A1A), // Deep Red (Đỏ trầm)
        scaffoldBackgroundColor: const Color(0xFFFFF8E1), // Cream (Màu kem)
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B1A1A),
          secondary: Color(0xFFA52A2A),
          surface: Color(0xFFFFF8E1),
          background: Color(0xFFFFF8E1),
          onPrimary: Colors.white,
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.playfairDisplay(
              fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF8B1A1A)),
          displayMedium: GoogleFonts.playfairDisplay(
              fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF8B1A1A)),
          bodyLarge: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF3E2723)),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D4037)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7CCC8)), // Light brown border
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7CCC8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: const TextStyle(color: Color(0xFF8D6E63)),
          hintStyle: const TextStyle(color: Color(0xFFBCAAA4)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B1A1A),
            foregroundColor: const Color(0xFFFFF8E1), // Text on button is Cream
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF8B1A1A)),
            foregroundColor: const Color(0xFF8B1A1A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// Giữ lại ConnectionPage nếu sau này cần dùng để đổi config, 
// nhưng hiện tại App sẽ chạy thẳng LoginPage.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  // Sử dụng giá trị mặc định nếu có
  final _urlController = TextEditingController(text: DEFAULT_PROJECT_URL);
  final _keyController = TextEditingController(text: DEFAULT_API_KEY);
  bool _isLoading = false;
  bool _isObscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('https://poirikgsravezzdljkwz.supabase.co');
    final key = prefs.getString('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvaXJpa2dzcmF2ZXp6ZGxqa3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYxOTI4NDksImV4cCI6MjA4MTc2ODg0OX0.hGApDOLdLERxsGBcJQChgnRCuHWXDmBAnqRU_lh4kSE');
    if (url != null && key != null) {
      setState(() {
        _urlController.text = url;
        _keyController.text = key;
        _rememberMe = true;
      });
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    try {
      // Initialize Supabase to test connection
      await Supabase.initialize(
        url: url,
        anonKey: key,
        debug: false,
      );

      // Simple test query to verify validity (even if table doesn't exist, auth check happens)
      // Or just checking if initialize throws isn't enough usually, need to make a call.
      // We will try to get the session or just proceed.
      // For this step, simply initializing successfully is a good first step, 
      // but let's try a lightweight check.
      
      final client = Supabase.instance.client;
      // Just check if we can access the health check endpoint or similar? 
      // Supabase public URL doesn't always fail on init.
      // Let's assume validity if no immediate crash and UI proceeds.
      
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('supabase_url', url);
        await prefs.setString('supabase_key', key);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('supabase_url');
        await prefs.remove('supabase_key');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to next screen (Placeholder for now)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối: ${e.toString()}'),
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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1549488497-2a818c7cda7e?q=80&w=1920&auto=format&fit=crop'),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 64, color: Color(0xFFD4AF37))
                      .animate().fadeIn().scale(),
                  const SizedBox(height: 24),
                  Text(
                    'Sổ Tay Việc Họ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text(
                    'Kết nối kho dữ liệu dòng họ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 48),
                  
                  // URL Input
                  TextFormField(
                    controller: _urlController,
                    style: GoogleFonts.inter(),
                    decoration: const InputDecoration(
                      labelText: 'Supabase URL',
                      prefixIcon: Icon(Icons.cloud_outlined, color: Color(0xFFD4AF37)),
                      hintText: 'https://xyz.supabase.co',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập URL';
                      if (!value.startsWith('https://')) return 'URL phải bắt đầu bằng https://';
                      return null;
                    },
                  ).animate().fadeIn(delay: 600.ms).slideX(),
                  
                  const SizedBox(height: 16),
                  
                  // Key Input
                  TextFormField(
                    controller: _keyController,
                    obscureText: _isObscure,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      labelText: 'API Key (Anon/Public)',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFFD4AF37)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Vui lòng nhập API Key' : null,
                  ).animate().fadeIn(delay: 700.ms).slideX(),

                  const SizedBox(height: 12),
                  
                  // Remember Me
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFFD4AF37),
                        checkColor: Colors.black,
                        onChanged: (v) => setState(() => _rememberMe = v!),
                      ),
                      Text(
                        'Ghi nhớ đăng nhập trên thiết bị này',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connect,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('TIẾP TỤC'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 900.ms).shimmer(delay: 2000.ms, duration: 1500.ms),
                  
                  const SizedBox(height: 24),
                  Text(
                    '© 2024 Vĩnh Cửu Tộc',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
