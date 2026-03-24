import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  String get themeName {
    if (_themeMode == ThemeMode.light) return 'Light Mode';
    if (_themeMode == ThemeMode.dark) return 'Dark Mode';
    return 'System Default';
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final tmStr = prefs.getString('theme_mode');
    if (tmStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (tmStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    if (themeName == 'Light Mode') {
      _themeMode = ThemeMode.light;
      await prefs.setString('theme_mode', 'light');
    } else if (themeName == 'Dark Mode') {
      _themeMode = ThemeMode.dark;
      await prefs.setString('theme_mode', 'dark');
    } else {
      _themeMode = ThemeMode.system;
      await prefs.setString('theme_mode', 'system');
    }
    notifyListeners();
  }
}

// Extension to quickly fetch theme colors depending on brightness
extension AppThemeColors on ThemeData {
  bool get isDark => brightness == Brightness.dark;

  Color get pGlassBackground => isDark ? const Color(0xFF141414) : Colors.white.withOpacity(0.4);
  Color get pGlassBorder => isDark ? Colors.cyanAccent.withOpacity(0.3) : Colors.white.withOpacity(0.6);
  Color get pGlassShadow => isDark ? Colors.cyanAccent.withOpacity(0.05) : Colors.black.withOpacity(0.05);

  Color get pBackground => isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF0F2F5);
  Color get pPrimaryText => isDark ? Colors.white : const Color(0xFF121212);
  Color get pSecondaryText => isDark ? Colors.white54 : Colors.black54;

  Color get pAccentText => isDark ? Colors.cyanAccent : const Color(0xFF007A99); // Darker cyan for light mode readability
}
