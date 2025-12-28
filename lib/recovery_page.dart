import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _vnccidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  
  // State for flow
  int _step = 1; // 1: Input VNCCID, 2: Answer Questions
  List<String> _questions = [];
  List<TextEditingController> _answerCtrls = [];
  final _formKey = GlobalKey<FormState>();

  Future<void> _checkVnccid() async {
    final vnccid = _vnccidCtrl.text.trim();
    if (vnccid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số CCCD/VNCCID')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Call RPC to get questions
      final res = await Supabase.instance.client.rpc('get_user_security_questions', params: {
        'target_vnccid': vnccid
      });
      
      final List<dynamic> data = res as List<dynamic>;
      if (data.isEmpty) {
        throw 'Không tìm thấy tài khoản hoặc tài khoản chưa thiết lập câu hỏi bảo mật.';
      }

      setState(() {
        _questions = data.map((e) => e['question_content'].toString()).toList();
        _answerCtrls = List.generate(_questions.length, (_) => TextEditingController());
        _step = 2; // Move to next step
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newPass = _passwordCtrl.text.trim();
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu mới phải từ 6 ký tự')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Prepare answers data
      final answersData = List.generate(_questions.length, (i) => {
        'question': _questions[i],
        'answer': _answerCtrls[i].text.trim()
      });

      final res = await Supabase.instance.client.rpc('verify_and_reset_password', params: {
        'target_vnccid': _vnccidCtrl.text.trim(),
        'answers_data': answersData,
        'new_password': newPass
      });

      if (res == true) {
        if (mounted) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (c) => AlertDialog(
               title: const Text('Thành công'),
               content: const Text('Mật khẩu đã được đặt lại. Vui lòng đăng nhập bằng mật khẩu mới.'),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.pop(c); // close dialog
                     Navigator.pop(context); // back to login
                   },
                   child: const Text('Về màn hình đăng nhập'),
                 )
               ],
             )
           );
        }
      } else {
        throw 'Câu trả lời không chính xác. Vui lòng thử lại.';
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khôi phục tài khoản')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 80, color: Color(0xFFD32F2F)),
        const SizedBox(height: 24),
        const Text(
          'Nhập số CCCD/VNCCID của bạn để tìm tài khoản và khôi phục mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _vnccidCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số CCCD (VNCCID)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _checkVnccid,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trả lời các câu hỏi bảo mật cho tài khoản VNCCID: ${_vnccidCtrl.text}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          ...List.generate(_questions.length, (index) {
             return Padding(
               padding: const EdgeInsets.only(bottom: 16.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('${index + 1}. ${_questions[index]}', style: const TextStyle(fontSize: 15)),
                   const SizedBox(height: 8),
                   TextFormField(
                     controller: _answerCtrls[index],
                     decoration: const InputDecoration(
                       labelText: 'Câu trả lời',
                       border: OutlineInputBorder(),
                       isDense: true,
                     ),
                     validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc nhập' : null,
                   ),
                 ],
               ),
             );
          }),

          const Divider(height: 32),
          const Text('Thiết lập mật khẩu mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu quá ngắn' : null,
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Đặt lại Mật khẩu', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
