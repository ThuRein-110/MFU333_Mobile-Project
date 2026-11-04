import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await ApiService.login(email.text.trim(), password.text);
      if (!mounted) return;
      if (data['user']?['must_change_password'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell(forcePassword: true)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
      }
    } catch (e) { setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(children: [
      if (MediaQuery.sizeOf(context).width > 760) Expanded(child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF102A4C), Color(0xFF1769C2)])),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance, size: 76, color: Colors.white),
          SizedBox(height: 18), Text('MFU333', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
          SizedBox(height: 8), Text('ระบบจัดการกิจกรรมและคะแนนสะสม\nมหาวิทยาลัยแม่ฟ้าหลวง', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16))
        ])))),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.school, size: 56, color: Color(0xFF1265E8)),
          const SizedBox(height: 10), const Text('เข้าสู่ระบบ MFU333', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF102A4C))),
          const SizedBox(height: 8), const Text('ใช้บัญชีที่ได้รับจากมหาวิทยาลัย', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 28), const Text('อีเมล'), const SizedBox(height: 7),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'name@mfu.ac.th')),
          const SizedBox(height: 16), const Text('รหัสผ่าน'), const SizedBox(height: 7),
          TextField(controller: password, obscureText: obscure, onSubmitted: (_) => submit(), decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscure = !obscure)))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 22), FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), child: busy ? const CircularProgressIndicator() : const Text('เข้าสู่ระบบ')),
        ]))))),
    ]),
  );
}
