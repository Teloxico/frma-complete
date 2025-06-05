import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/api_mode.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

/// Provider for managing user and application settings with persistence and security.
class SettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  final ApiService _apiService = ApiService();

  static const String _defaultLocalServerUrl = 'http://localhost:8000';

  // Secure storage for sensitive data (API key, profile password).
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _secureProfilePasswordHashKey = 'profile_password_hash';
  static const String _keyIsPasswordSet = 'settings_is_password_set';

  // UI and feature settings state.
  Color _primaryColor = Colors.blue;
  double _fontSize = 16.0;
  bool _highContrast = false;
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;
  bool _saveConversationHistory = true;

  // API configuration state.
  ApiMode _apiMode = ApiMode.localServer;
  String? _apiKeyStatus;
  String? _endpointId;
  String _localServerUrl = _defaultLocalServerUrl;

  // Profile password state.
  bool _isPasswordSet = false;

  // SharedPreferences keys.
  static const String _keyPrefix = 'settings_';
  static const String _keyPrimaryColor = '${_keyPrefix}primary_color';
  static const String _keyFontSize = '${_keyPrefix}font_size';
  static const String _keyHighContrast = '${_keyPrefix}high_contrast';
  static const String _keyEnableNotifications =
      '${_keyPrefix}enable_notifications';
  static const String _keyEnableSoundEffects =
      '${_keyPrefix}enable_sound_effects';
  static const String _keySaveHistory =
      '${_keyPrefix}save_conversation_history';
  static const String keyApiMode = 'use_local_server';
  static const String keyEndpointId = 'runpod_endpoint_id';
  static const String keyServerUrl = 'local_server_url';

  SettingsProvider(this.prefs);

  // Public getters for UI.
  Color get primaryColor => _primaryColor;
  double get fontSize => _fontSize;
  bool get highContrast => _highContrast;
  bool get enableNotifications => _enableNotifications;
  bool get enableSoundEffects => _enableSoundEffects;
  bool get saveConversationHistory => _saveConversationHistory;
  ApiMode get apiMode => _apiMode;
  String get apiKeyStatus => _apiKeyStatus ?? 'Checking...';
  String? get endpointId => _endpointId;
  String get localServerUrl => _localServerUrl;
  bool get isPasswordSet => _isPasswordSet;

  /// Load all settings from SharedPreferences and secure storage.
  Future<void> loadSettings() async {
    try {
      _primaryColor =
          Color(prefs.getInt(_keyPrimaryColor) ?? _primaryColor.value);
      _fontSize = prefs.getDouble(_keyFontSize) ?? _fontSize;
      _highContrast = prefs.getBool(_keyHighContrast) ?? _highContrast;
      _enableNotifications =
          prefs.getBool(_keyEnableNotifications) ?? _enableNotifications;
      _enableSoundEffects =
          prefs.getBool(_keyEnableSoundEffects) ?? _enableSoundEffects;
      _saveConversationHistory =
          prefs.getBool(_keySaveHistory) ?? _saveConversationHistory;
      _endpointId = prefs.getString(keyEndpointId);
      _localServerUrl = prefs.getString(keyServerUrl) ?? _defaultLocalServerUrl;
      _apiMode = (prefs.getBool(keyApiMode) ?? true)
          ? ApiMode.localServer
          : ApiMode.runPod;
      _isPasswordSet = prefs.getBool(_keyIsPasswordSet) ?? false;

      await checkApiKeyStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _apiKeyStatus = 'Error';
      notifyListeners();
    }
  }

  /// Check if RunPod API key is configured.
  Future<void> checkApiKeyStatus() async {
    try {
      final isSet = await _apiService.isApiKeySet();
      _apiKeyStatus = isSet ? 'Configured' : 'Not configured';
    } catch (e) {
      _apiKeyStatus = 'Error';
      debugPrint('Error checking API key status: $e');
    }
    notifyListeners();
  }

  /// Store RunPod API key securely.
  Future<void> setApiKey(String apiKey) async {
    _apiKeyStatus = 'Saving...';
    notifyListeners();
    try {
      await _apiService.saveApiKey(apiKey);
      await checkApiKeyStatus();
    } catch (e) {
      debugPrint('Error saving API key: $e');
      _apiKeyStatus = 'Error';
      notifyListeners();
      rethrow;
    }
  }

  /// Remove stored RunPod API key.
  Future<void> clearApiKey() async {
    _apiKeyStatus = 'Clearing...';
    notifyListeners();
    try {
      await _apiService.clearApiKey();
      await checkApiKeyStatus();
    } catch (e) {
      debugPrint('Error clearing API key: $e');
      _apiKeyStatus = 'Error';
      notifyListeners();
      rethrow;
    }
  }

  /// Update and persist the local server URL.
  Future<void> setLocalServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty && (Uri.tryParse(trimmed)?.isAbsolute != true)) {
      throw ArgumentError('Invalid URL format.');
    }
    _localServerUrl = trimmed;
    await _apiService.saveLocalServerUrl(trimmed);
    notifyListeners();
  }

  /// Update and persist the RunPod endpoint ID.
  Future<void> setEndpointId(String endpointId) async {
    final trimmed = endpointId.trim();
    _endpointId = trimmed.isEmpty ? null : trimmed;
    await _apiService.saveEndpointId(trimmed);
    notifyListeners();
  }

  /// Switch between local server and RunPod mode.
  Future<void> setApiMode(ApiMode mode) async {
    if (_apiMode == mode) return;
    _apiMode = mode;
    await _apiService.setUseLocalServer(mode == ApiMode.localServer);
    notifyListeners();
  }

  /// Update primary color preference.
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor == color) return;
    _primaryColor = color;
    await prefs.setInt(_keyPrimaryColor, color.value);
    notifyListeners();
  }

  /// Update font size preference.
  Future<void> setFontSize(double size) async {
    if (size <= 0 || _fontSize == size) return;
    _fontSize = size;
    await prefs.setDouble(_keyFontSize, size);
    notifyListeners();
  }

  /// Toggle a boolean setting by key.
  Future<void> _toggleBoolSetting(String key, bool current) async {
    final newValue = !current;
    await prefs.setBool(key, newValue);
    switch (key) {
      case _keyHighContrast:
        _highContrast = newValue;
        break;
      case _keyEnableNotifications:
        _enableNotifications = newValue;
        break;
      case _keyEnableSoundEffects:
        _enableSoundEffects = newValue;
        break;
      case _keySaveHistory:
        _saveConversationHistory = newValue;
        break;
    }
    notifyListeners();
  }

  Future<void> toggleHighContrast() =>
      _toggleBoolSetting(_keyHighContrast, _highContrast);
  Future<void> toggleNotifications() =>
      _toggleBoolSetting(_keyEnableNotifications, _enableNotifications);
  Future<void> toggleSoundEffects() =>
      _toggleBoolSetting(_keyEnableSoundEffects, _enableSoundEffects);
  Future<void> toggleSaveConversationHistory() =>
      _toggleBoolSetting(_keySaveHistory, _saveConversationHistory);

  /// Set or change the profile password (stored as a hash).
  Future<void> setPassword(String password) async {
    if (password.isEmpty) throw ArgumentError('Password cannot be empty.');
    final hash = _hashPassword(password);
    await _secureStorage.write(key: _secureProfilePasswordHashKey, value: hash);
    await prefs.setBool(_keyIsPasswordSet, true);
    _isPasswordSet = true;
    notifyListeners();
  }

  /// Verify entered profile password against the stored hash.
  Future<bool> verifyPassword(String entered) async {
    if (!_isPasswordSet) return true;
    final stored =
        await _secureStorage.read(key: _secureProfilePasswordHashKey);
    if (stored == null) {
      await prefs.setBool(_keyIsPasswordSet, false);
      _isPasswordSet = false;
      notifyListeners();
      return true;
    }
    return stored == _hashPassword(entered);
  }

  /// Clear the profile password and related flag.
  Future<void> clearPassword() async {
    await _secureStorage.delete(key: _secureProfilePasswordHashKey);
    await prefs.setBool(_keyIsPasswordSet, false);
    _isPasswordSet = false;
    notifyListeners();
  }

  /// Hash a password using SHA-256 (use stronger approach in production).
  String _hashPassword(String password) {
    const salt = 'unique_app_salt';
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Test connectivity to the configured backend.
  Future<bool> testConnection() async {
    try {
      return await _apiService.verifyEndpoint();
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  /// Reset all preferences (excluding secure data) to defaults.
  Future<void> resetToDefaults() async {
    _primaryColor = Colors.blue;
    _fontSize = 16.0;
    _highContrast = false;
    _enableNotifications = true;
    _enableSoundEffects = true;
    _saveConversationHistory = true;
    _apiMode = ApiMode.localServer;
    _localServerUrl = _defaultLocalServerUrl;
    _endpointId = null;

    await prefs.setInt(_keyPrimaryColor, _primaryColor.value);
    await prefs.setDouble(_keyFontSize, _fontSize);
    await prefs.setBool(_keyHighContrast, _highContrast);
    await prefs.setBool(_keyEnableNotifications, _enableNotifications);
    await prefs.setBool(_keyEnableSoundEffects, _enableSoundEffects);
    await prefs.setBool(_keySaveHistory, _saveConversationHistory);

    await _apiService.setUseLocalServer(true);
    await _apiService.saveLocalServerUrl(_defaultLocalServerUrl);
    await prefs.remove(keyEndpointId);

    await checkApiKeyStatus();
    notifyListeners();
  }

  /// Clear all stored data including preferences and secure storage.
  Future<void> clearAllData() async {
    await prefs.clear();
    await clearPassword();
    await clearApiKey();
    await loadSettings();
  }
}
