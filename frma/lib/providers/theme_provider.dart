import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages application theme settings and persistence.
class ThemeProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  ThemeMode _themeMode = ThemeMode.system;
  static const String _keyThemeMode = 'theme_mode';

  /// Initialize with stored preference.
  ThemeProvider(this.prefs) {
    _loadThemeMode();
  }

  /// Current theme selection.
  ThemeMode get themeMode => _themeMode;

  /// Determines if dark mode is active (accounts for system setting).
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Read saved theme from preferences (defaults to system).
  void _loadThemeMode() {
    try {
      final index = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
      if (index >= 0 && index < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[index];
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  /// Update theme mode and persist change.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    try {
      await prefs.setInt(_keyThemeMode, mode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
    notifyListeners();
  }

  /// Toggle between light and dark (handles system mode inversion).
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : (_themeMode == ThemeMode.dark
            ? ThemeMode.light
            : (isDarkMode ? ThemeMode.light : ThemeMode.dark));
    await setThemeMode(newMode);
  }
}
