import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_language.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.restore();
  final language = AppLanguage();
  await language.restore();
  runApp(Mfu333App(language: language));
}

class Mfu333App extends StatefulWidget {
  const Mfu333App({super.key, this.language});
  final AppLanguage? language;

  @override
  State<Mfu333App> createState() => _Mfu333AppState();
}

class _Mfu333AppState extends State<Mfu333App> {
  late final language = widget.language ?? AppLanguage();

  @override
  void dispose() {
    if (widget.language == null) language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102A4C);
    return AnimatedBuilder(
      animation: language,
      builder: (context, _) => AppLanguageScope(
        controller: language,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MFU333',
          locale: language.locale,
          supportedLocales: const [Locale('th'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            fontFamilyFallback: const ['NotoSansThai'],
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1265E8),
              primary: const Color(0xFF1265E8),
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F7FB),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5ECF5)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFDCE5F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFDCE5F0)),
              ),
            ),
          ),
          home: ApiService.token == null
              ? const LoginScreen()
              : const AppShell(),
        ),
      ),
    );
  }
}
