import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/message.dart';
import '../models/api_mode.dart';
import '../providers/settings_provider.dart';

/// Thrown for errors encountered within ApiService operations.
class ApiServiceException implements Exception {
  final String message;
  ApiServiceException(this.message);
  @override
  String toString() => 'ApiServiceException: $message';
}

/// Handles communication with AI backends (local server or RunPod API).
class ApiService {
  static const String _defaultLocalServerUrl = 'http://127.0.0.1:8000';
  static const String _runpodApiBaseUrl = 'https://api.runpod.ai/v2';
  static const Duration _defaultTimeout = Duration(seconds: 120);
  static const Duration _runpodPollDelay = Duration(seconds: 3);
  static const int _runpodMaxPollAttempts = 40;

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _secureApiKeyStorageKey = 'runpod_api_key_secure';

  /// Log initialization state.
  Future<void> initialize() async {
    debugPrint(
        'ApiService initialized. Using local server: ${await useLocalServer()}');
  }

  /// Checks if a RunPod API key is stored.
  Future<bool> isApiKeySet() async {
    try {
      final apiKey = await _secureStorage.read(key: _secureApiKeyStorageKey);
      return apiKey != null && apiKey.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking API key: $e');
      return false;
    }
  }

  /// Stores the RunPod API key securely.
  Future<void> saveApiKey(String apiKey) async {
    if (apiKey.isEmpty) throw ApiServiceException('API key cannot be empty');
    try {
      await _secureStorage.write(key: _secureApiKeyStorageKey, value: apiKey);
      debugPrint('RunPod API key saved.');
    } catch (e) {
      throw ApiServiceException('Failed to save API key: $e');
    }
  }

  /// Removes the stored RunPod API key.
  Future<void> clearApiKey() async {
    try {
      await _secureStorage.delete(key: _secureApiKeyStorageKey);
      debugPrint('RunPod API key cleared.');
    } catch (e) {
      throw ApiServiceException('Failed to clear API key: $e');
    }
  }

  /// Saves or clears the RunPod endpoint ID in shared preferences.
  Future<void> saveEndpointId(String endpointId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (endpointId.isEmpty) {
        await prefs.remove(SettingsProvider.keyEndpointId);
        debugPrint('Endpoint ID cleared.');
      } else {
        await prefs.setString(SettingsProvider.keyEndpointId, endpointId);
        debugPrint('Endpoint ID saved.');
      }
    } catch (e) {
      throw ApiServiceException('Failed to save endpoint ID: $e');
    }
  }

  /// Retrieves the saved RunPod endpoint ID, if any.
  Future<String?> getEndpointId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(SettingsProvider.keyEndpointId);
    } catch (e) {
      debugPrint('Error getting endpoint ID: $e');
      return null;
    }
  }

  /// Stores or clears the local server URL. Validates format.
  Future<void> saveLocalServerUrl(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isNotEmpty && (uri == null || !uri.isAbsolute)) {
      throw ApiServiceException('Invalid URL format.');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (trimmed.isEmpty) {
        await prefs.remove(SettingsProvider.keyServerUrl);
        debugPrint('Local server URL cleared.');
      } else {
        await prefs.setString(SettingsProvider.keyServerUrl, trimmed);
        debugPrint('Local server URL saved: $trimmed');
      }
    } catch (e) {
      throw ApiServiceException('Failed to save local server URL: $e');
    }
  }

  /// Obtains the configured local server URL, adjusting for Android emulator.
  Future<String> getLocalServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String url = prefs.getString(SettingsProvider.keyServerUrl) ??
          _defaultLocalServerUrl;
      if (Platform.isAndroid && kDebugMode) {
        final parsed = Uri.tryParse(url);
        if (parsed != null &&
            (parsed.host == 'localhost' || parsed.host == '127.0.0.1')) {
          url = parsed.replace(host: '10.0.2.2').toString();
          debugPrint('Adjusted Android emulator URL: $url');
        }
      }
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    } catch (e) {
      debugPrint('Error getting local URL: $e');
      if (Platform.isAndroid && kDebugMode) {
        return _defaultLocalServerUrl.replaceFirst('127.0.0.1', '10.0.2.2');
      }
      return _defaultLocalServerUrl;
    }
  }

  /// Returns true if configured to use the local server.
  Future<bool> useLocalServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(SettingsProvider.keyApiMode) ?? true;
    } catch (e) {
      debugPrint('Error checking server preference: $e');
      return true;
    }
  }

  /// Sets whether to use the local server.
  Future<void> setUseLocalServer(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SettingsProvider.keyApiMode, value);
      debugPrint('Set useLocalServer to $value');
    } catch (e) {
      throw ApiServiceException('Failed to save preference: $e');
    }
  }

  Future<String?> _getApiKey() async {
    try {
      return await _secureStorage.read(key: _secureApiKeyStorageKey);
    } catch (e) {
      debugPrint('Error reading API key: $e');
      return null;
    }
  }

  /// Sends a chat request to the selected backend.
  Future<Map<String, dynamic>> sendMedicalQuestion({
    required String question,
    required List<Message> messageHistory,
    Map<String, dynamic>? profileData,
    int maxTokens = 512,
    double temperature = 0.2,
    double topP = 0.9,
    int topK = 50,
  }) async {
    if (question.trim().isEmpty) {
      throw ApiServiceException('Question cannot be empty.');
    }
    try {
      final local = await useLocalServer();
      if (local) {
        return await _sendToLocalServer(
          endpoint: '/chat',
          prompt: question,
          history: _buildChatHistoryPayload(messageHistory),
          profileData: profileData,
          maxNewTokens: maxTokens,
          temperature: temperature,
          topP: topP,
          topK: topK,
        );
      } else {
        final context = messageHistory
            .map((m) => "${m.isUser ? 'User' : 'Assistant'}: ${m.text}")
            .join("\n");
        return await _sendToRunPod(
          question: question,
          context: context.isEmpty ? null : context,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      }
    } catch (e) {
      _handleGeneralApiError(e, 'sendMedicalQuestion');
      rethrow;
    }
  }

  /// Sends an emergency assessment request.
  Future<Map<String, dynamic>> sendEmergencyPrompt({
    required String prompt,
    Map<String, dynamic>? profileData,
    int maxTokens = 768,
    double temperature = 0.3,
  }) async {
    if (prompt.trim().isEmpty) {
      throw ApiServiceException('Emergency prompt cannot be empty.');
    }
    try {
      final local = await useLocalServer();
      if (local) {
        return await _sendToLocalServer(
          endpoint: '/emergency_assessment',
          prompt: prompt,
          history: [],
          profileData: profileData,
          maxNewTokens: maxTokens,
          temperature: temperature,
          topP: 0.9,
          topK: 50,
        );
      } else {
        return await _sendToRunPod(
          question: prompt,
          context: null,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      }
    } catch (e) {
      _handleGeneralApiError(e, 'sendEmergencyPrompt');
      rethrow;
    }
  }

  /// Helper for sending requests to local server endpoints.
  Future<Map<String, dynamic>> _sendToLocalServer({
    required String endpoint,
    required String prompt,
    required List<Map<String, dynamic>> history,
    Map<String, dynamic>? profileData,
    required int maxNewTokens,
    required double temperature,
    required double topP,
    required int topK,
  }) async {
    try {
      final serverUrl = await getLocalServerUrl();
      final uri = Uri.parse('$serverUrl$endpoint');
      final payload = <String, dynamic>{
        'prompt': prompt,
        'history': history,
        'max_new_tokens': maxNewTokens,
        'temperature': temperature,
        'top_p': topP,
        'top_k': topK,
        'user_profile': _filterProfileData(profileData),
      };
      if (endpoint == '/emergency_assessment') {
        payload.remove('history');
        payload.remove('top_k');
      }
      if (payload['user_profile'] == null) payload.remove('user_profile');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode(payload))
          .timeout(_defaultTimeout);
      if (response.statusCode != 200) {
        final detail = utf8.decode(response.bodyBytes);
        throw ApiServiceException(
            'Error $endpoint: ${response.statusCode} - $detail');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final answer = body['answer'] as String?;
      if (answer == null) {
        throw ApiServiceException('Invalid response format: missing answer');
      }
      return {'answer': _extractAnswerContent(answer)};
    } on SocketException catch (e) {
      throw ApiServiceException('Network error: $e');
    } on TimeoutException {
      throw ApiServiceException('Request timed out ($endpoint).');
    }
  }

  Map<String, dynamic>? _filterProfileData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    final result = <String, dynamic>{};
    data.forEach((k, v) {
      if (v == null && k != 'age') return;
      if (v is String && v.trim().isEmpty) return;
      if (v is List && v.isEmpty) return;
      result[k] = v;
    });
    return result.isEmpty ? null : result;
  }

  List<Map<String, dynamic>> _buildChatHistoryPayload(List<Message> msgs) {
    final history =
        msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <Message>[];
    return history
        .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
  }

  String _extractAnswerContent(String response) {
    var cleaned = response
        .replaceAll(RegExp(r'<\|.*?\|>', dotAll: true), '')
        .replaceAll(RegExp(r'\[INST\].*?\[/INST\]', dotAll: true), '')
        .replaceAll(RegExp(r'<<SYS>>.*?<</SYS>>', dotAll: true), '')
        .trim();
    cleaned = cleaned
        .replaceFirst(
            RegExp(r'^(assistant|bot)[:\s]*', caseSensitive: false), '')
        .trim();
    return cleaned;
  }

  Future<Map<String, dynamic>> _sendToRunPod({
    required String question,
    String? context,
    required int maxTokens,
    required double temperature,
  }) async {
    final endpointId = await getEndpointId();
    final apiKey = await _getApiKey();
    if (endpointId == null || apiKey == null) {
      throw ApiServiceException('RunPod API key or endpoint ID missing.');
    }
    final uri = Uri.parse('$_runpodApiBaseUrl/$endpointId/run');
    final payload = {
      'input': {
        'prompt': question,
        'max_new_tokens': maxTokens,
        'temperature': temperature,
        if (context != null) 'chat_history': context,
      }
    };
    final initResp = await http
        .post(uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(payload))
        .timeout(const Duration(seconds: 45));
    if (initResp.statusCode != 200) {
      final detail = utf8.decode(initResp.bodyBytes);
      throw ApiServiceException(
          'RunPod error: ${initResp.statusCode} - $detail');
    }
    final data = jsonDecode(utf8.decode(initResp.bodyBytes));
    if (data['id'] is String) {
      return await _pollRunPodJob(endpointId, data['id'], apiKey);
    } else if (data['output'] != null) {
      return {'answer': _extractAnswerContent(jsonEncode(data['output']))};
    } else {
      throw ApiServiceException('Unexpected RunPod response format.');
    }
  }

  Future<Map<String, dynamic>> _pollRunPodJob(
      String eid, String jobId, String apiKey) async {
    for (var attempt = 0; attempt < _runpodMaxPollAttempts; attempt++) {
      await Future.delayed(_runpodPollDelay);
      final statusUri = Uri.parse('$_runpodApiBaseUrl/$eid/status/$jobId');
      final resp = await http.get(statusUri, headers: {
        'Authorization': 'Bearer $apiKey'
      }).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) continue;
      final d = jsonDecode(utf8.decode(resp.bodyBytes));
      switch ((d['status'] as String).toUpperCase()) {
        case 'COMPLETED':
          return {'answer': _extractAnswerContent(jsonEncode(d['output']))};
        case 'FAILED':
          throw ApiServiceException(
              'RunPod job failed: ${d['error'] ?? 'Unknown'}');
        default:
          continue;
      }
    }
    throw ApiServiceException(
        'RunPod job timed out after $_runpodMaxPollAttempts attempts.');
  }

  /// Verifies the health of the selected backend.
  Future<bool> verifyEndpoint() async {
    try {
      if (await useLocalServer()) {
        final healthUrl = '${await getLocalServerUrl()}/health';
        final resp = await http
            .get(Uri.parse(healthUrl))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          return data['status'] == 'healthy' &&
              data['model_status'] == 'loaded';
        }
        return false;
      } else {
        final eid = await getEndpointId();
        final apiKey = await _getApiKey();
        if (eid == null || apiKey == null) return false;
        final url = '$_runpodApiBaseUrl/$eid/health';
        final resp = await http.get(Uri.parse(url), headers: {
          'Authorization': 'Bearer $apiKey'
        }).timeout(const Duration(seconds: 20));
        return resp.statusCode == 200;
      }
    } catch (_) {
      return false;
    }
  }

  /// Wraps errors into ApiServiceException for clarity.
  void _handleGeneralApiError(dynamic error, String fn) {
    if (error is ApiServiceException) throw error;
    if (error is SocketException)
      throw ApiServiceException('Network error in $fn');
    if (error is TimeoutException) throw ApiServiceException('Timeout in $fn');
    throw ApiServiceException('Unexpected error in $fn: ${error.toString()}');
  }
}
