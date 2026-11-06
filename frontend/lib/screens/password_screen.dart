import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  Future<void> save() async {
    setState(() => busy = true);
    try {
      final r = await ApiService.request(
        'PATCH',
        '/api/auth/change-password',
        body: {
          'current_password': current.text,
          'new_password': next.text,
          'confirm_password': confirm.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(r['message']?.toString() ?? 'เปลี่ยนรหัสผ่านสำเร็จ'),
          ),
        ),
      );
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        context.tr('เปลี่ยนรหัสผ่าน'),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: current,
        obscureText: true,
        decoration: InputDecoration(labelText: context.tr('รหัสผ่านปัจจุบัน')),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: next,
        obscureText: true,
        decoration: InputDecoration(
          labelText: context.tr('รหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: confirm,
        obscureText: true,
        decoration: InputDecoration(
          labelText: context.tr('ยืนยันรหัสผ่านใหม่'),
        ),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(context.tr('บันทึกรหัสผ่าน')),
      ),
    ],
  );
}
