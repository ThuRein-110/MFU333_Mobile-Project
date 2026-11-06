import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One preference for the whole app, including routes opened after signing in.
class AppLanguage extends ChangeNotifier {
  static const preferenceKey = 'app_language';
  Locale _locale = const Locale('th');

  Locale get locale => _locale;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(preferenceKey);
    _locale = Locale(saved == 'en' ? 'en' : 'th');
    notifyListeners();
  }

  Future<void> select(String languageCode) async {
    if (!['th', 'en'].contains(languageCode) ||
        languageCode == _locale.languageCode) {
      return;
    }
    _locale = Locale(languageCode);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, languageCode);
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguage> {
  const AppLanguageScope({
    super.key,
    required AppLanguage controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.notifier;
}
