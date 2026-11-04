import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.restore();
  runApp(const Mfu333App());
}

class Mfu333App extends StatelessWidget {
  const Mfu333App({super.key});
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102A4C);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MFU333',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1265E8), primary: const Color(0xFF1265E8)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: navy, elevation: 0),
        cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE5ECF5)))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDCE5F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDCE5F0))),
        ),
      ),
      home: ApiService.token == null ? const LoginScreen() : const AppShell(),
    );
  }
}
