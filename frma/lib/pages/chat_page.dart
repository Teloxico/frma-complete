// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../services/api_service.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../providers/settings_provider.dart';
import '../models/api_mode.dart';

/// The main chat interface page for interacting with the health assistant AI.
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Controllers for text input and scrolling
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  // Controllers for the inline server config section
  final _localServerUrlController = TextEditingController();
  final _runpodEndpointController = TextEditingController();

  final List<Message> _messages = []; // Stores the current chat conversation.
  bool _isTesting = false; // Tracks if the connection test is running.
  bool _isTyping = false; // True when waiting for the AI response.
  bool _isServerConfigured = false; // Tracks if API settings are valid.
  String _errorMessage = ''; // Stores configuration or API error messages.
  final ApiService _apiService = ApiService(); // Service for backend calls.
  bool _settingsExpanded =
      false; // Controls visibility of the inline config section.
  ApiMode _selectedApiMode =
      ApiMode.localServer; // UI state for config section.

  // Key for storing chat history in SharedPreferences.
  static const String _chatHistoryKey = 'chat_history';

  @override
  void initState() {
    super.initState();
    // Load initial state after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final settingsProvider =
            Provider.of<SettingsProvider>(context, listen: false);
        _selectedApiMode = settingsProvider.apiMode; // Set initial UI state
        await _checkServerConfiguration(); // Verify API setup
        await _loadChatHistory(); // Load previous messages if enabled/available
        _addWelcomeMessageIfNeeded(); // Show greeting if chat is empty
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _localServerUrlController.dispose();
    _runpodEndpointController.dispose();
    super.dispose();
  }

  // Loads chat history from SharedPreferences if enabled in settings.
  Future<void> _loadChatHistory() async {
    if (!mounted) return;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.saveConversationHistory) {
      // History saving is off, don't load anything.
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_chatHistoryKey);

      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(historyJson);
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(decodedList
                .map((item) => Message.fromJson(item as Map<String, dynamic>)));
          });
          debugPrint("Loaded ${_messages.length} messages from history.");
          _scrollToBottom(); // Scroll down after loading history.
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      // Clear potentially corrupted history if loading fails.
      if (mounted) {
        setState(() {
          _messages.clear();
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_chatHistoryKey);
      }
    }
  }

  // Saves the current chat history to SharedPreferences if enabled.
  Future<void> _saveChatHistory() async {
    if (!mounted) return;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.saveConversationHistory) {
      return; // Saving is disabled.
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert messages to JSON maps, then encode the list to a string.
      final String historyJson =
          jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_chatHistoryKey, historyJson);
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  // Clears chat messages from the UI and optionally from storage.
  Future<void> _clearChatHistory() async {
    if (!mounted) return;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // Clear the message list in the UI.
    setState(() {
      _messages.clear();
    });

    // If history saving is enabled, remove it from storage.
    if (settingsProvider.saveConversationHistory) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_chatHistoryKey);
        debugPrint("Chat history cleared from SharedPreferences.");
      } catch (e) {
        debugPrint("Error clearing chat history from SharedPreferences: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error clearing saved history.'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
    // Add the welcome message back after clearing.
    _addWelcomeMessageIfNeeded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chat history cleared.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  // Shows a confirmation dialog before clearing history.
  void _showClearConfirmationDialog() {
    // Don't show if only the initial welcome message exists.
    if (_messages.length <= 1 && _messages.isNotEmpty && !_messages[0].isUser) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat is already empty.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
            'Are you sure you want to delete all messages in this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }

  // Checks if the selected API backend (Local or RunPod) is configured correctly.
  Future<void> _checkServerConfiguration() async {
    if (!mounted) return;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    try {
      final apiMode = settingsProvider.apiMode;
      bool configured = false;
      _selectedApiMode = apiMode; // Ensure UI state matches provider

      if (apiMode == ApiMode.localServer) {
        configured = settingsProvider.localServerUrl.isNotEmpty;
        _localServerUrlController.text = settingsProvider.localServerUrl;
        _errorMessage = configured
            ? ''
            : 'Local server URL not configured. Please check settings.';
      } else {
        // RunPod mode
        final apiKeySet =
            await _apiService.isApiKeySet(); // Uses secure storage check
        final endpointSet = settingsProvider.endpointId != null &&
            settingsProvider.endpointId!.isNotEmpty;
        configured = apiKeySet && endpointSet;
        _runpodEndpointController.text = settingsProvider.endpointId ?? '';
        if (!apiKeySet) {
          _errorMessage =
              'RunPod API key not configured. Please check settings.';
        } else if (!endpointSet) {
          _errorMessage =
              'RunPod Endpoint ID not configured. Please check settings.';
        } else {
          _errorMessage = '';
        }
      }

      if (mounted) {
        setState(() {
          _isServerConfigured = configured;
          if (configured) _errorMessage = '';
        });
        _addWelcomeMessageIfNeeded(); // Re-check welcome message based on new config status
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServerConfigured = false;
          _errorMessage =
              'Error checking configuration: ${e.toString().split('\n')[0]}';
        });
        _addWelcomeMessageIfNeeded();
      }
    }
  }

  // Adds the initial greeting message if the chat is empty.
  void _addWelcomeMessageIfNeeded() {
    if (!mounted || _messages.isNotEmpty) return;

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final name = profileProvider.name.isNotEmpty
        ? profileProvider.name.split(' ')[0]
        : "there";

    String welcomeMessage =
        "Hello $name! I'm your health assistant. How can I help you today?";
    if (!_isServerConfigured) {
      welcomeMessage =
          "Welcome! Before we can start, please configure the AI server in the settings section below or via the main Settings page.";
    }

    // Add message after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.isEmpty) {
        _addMessage(welcomeMessage, false,
            saveHistory: false); // Don't save the initial welcome message
      }
    });
  }

  // Adds a message to the UI list and optionally saves history.
  void _addMessage(String text, bool isUser, {bool saveHistory = true}) {
    if (text.trim().isEmpty) return;
    final newMessage =
        Message(text: text.trim(), isUser: isUser, timestamp: DateTime.now());
    if (mounted) {
      setState(() => _messages.add(newMessage));
      _scrollToBottom(); // Keep latest message visible
      if (saveHistory) {
        _saveChatHistory();
      }
    }
  }

  // Scrolls the chat list to the bottom.
  void _scrollToBottom() {
    // Short delay ensures the list has time to update before scrolling.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Sends the user's message to the backend AI service.
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _addMessage(messageText, true); // Show user message immediately
    final List<Message> currentMessageHistory =
        List.from(_messages); // Copy history for API call
    _messageController.clear();

    if (!_isServerConfigured) {
      _addMessage("Please configure the server settings first.", false,
          saveHistory: false);
      return;
    }

    if (mounted) setState(() => _isTyping = true); // Show typing indicator
    try {
      // Prepare profile data to send with the request.
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final Map<String, dynamic> profileData = {
        'name': profileProvider.name.isEmpty ? null : profileProvider.name,
        'age': profileProvider.age,
        'gender':
            profileProvider.gender.isEmpty ? null : profileProvider.gender,
        'weight_kg': profileProvider.weight > 0 ? profileProvider.weight : null,
        'height_cm': profileProvider.height > 0 ? profileProvider.height : null,
        'blood_type': profileProvider.bloodType.isEmpty
            ? null
            : profileProvider.bloodType,
        'medical_conditions': profileProvider.medicalConditions
            .where((c) => c.selected)
            .map((c) => c.name)
            .toList(),
        'allergies': profileProvider.allergies.isEmpty
            ? null
            : profileProvider.allergies,
        'medications': profileProvider.medications
            .map((m) => '${m.name} (${m.dosage}, ${m.frequency})')
            .toList(),
      };

      // Call the API service.
      final response = await _apiService.sendMedicalQuestion(
        question: messageText,
        messageHistory: currentMessageHistory,
        profileData: profileData,
        maxTokens: 512, // Example inference parameters
        temperature: 0.2,
      );

      // Handle the response.
      if (mounted) {
        setState(() => _isTyping = false);
        final answer = response['answer'];
        if (answer != null && answer.isNotEmpty) {
          _addMessage(answer, false); // Add AI response
        } else {
          _addMessage('Sorry, I received an empty response.', false,
              saveHistory: false);
        }
      }
    } on ApiServiceException catch (e) {
      // Handle specific API errors.
      if (mounted) {
        setState(() {
          _isTyping = false;
          _addMessage("Error communicating with assistant: ${e.message}", false,
              saveHistory: false);
        });
      }
    } catch (e) {
      // Handle unexpected errors.
      if (mounted) {
        setState(() {
          _isTyping = false;
          _addMessage(
              "An unexpected error occurred: ${e.toString().split('\n')[0]}",
              false,
              saveHistory: false);
        });
      }
    }
  }

  // Saves the API settings entered in the inline config section.
  Future<void> _updateServerSettings() async {
    if (!mounted) return;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final currentUIMode = _selectedApiMode; // Use the mode selected in the UI.
    try {
      // Update provider state first.
      await settingsProvider.setApiMode(currentUIMode);
      if (currentUIMode == ApiMode.localServer) {
        await settingsProvider
            .setLocalServerUrl(_localServerUrlController.text);
      } else {
        // API Key is set via Settings page, only Endpoint ID is set here.
        await settingsProvider.setEndpointId(_runpodEndpointController.text);
      }

      // Re-verify connection after saving.
      bool isConnected = await _apiService.verifyEndpoint();
      if (mounted) {
        setState(() {
          _isServerConfigured = isConnected;
          _settingsExpanded = false; // Collapse the settings panel.
          _errorMessage = isConnected ? '' : 'Connection failed after saving.';
        });
        _addWelcomeMessageIfNeeded(); // Update welcome msg based on new status.

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected
                ? 'Settings saved & connection verified!'
                : 'Settings saved, but connection failed.'),
            backgroundColor: isConnected ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Error saving settings: ';
        errorMsg += (e is ApiServiceException)
            ? e.message
            : e.toString().split('\n')[0];
        setState(() => _errorMessage = errorMsg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Builds the text input field and send button area.
  Widget _buildChatInput() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [
        BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05))
      ]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your medical question...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
              ),
              maxLines: null, // Allows multi-line input.
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(width: 8.0),
          // Send button, enabled only when input is not empty and server is configured.
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final canSend =
                    value.text.isNotEmpty && !_isTyping && _isServerConfigured;
                return CircleAvatar(
                  backgroundColor: canSend
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: canSend ? _sendMessage : null,
                    color: Colors.white,
                  ),
                );
              }),
        ],
      ),
    );
  }

  // Builds the expandable inline server configuration section.
  Widget _buildServerConfigSection() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode
        ? Colors.grey.shade800
        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5);

    // Sync text fields with provider state only when expanding.
    if (_settingsExpanded) {
      _localServerUrlController.text = settingsProvider.localServerUrl;
      _runpodEndpointController.text = settingsProvider.endpointId ?? '';
      // _selectedApiMode = settingsProvider.apiMode; // Sync radio buttons (done via setState in toggle)
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Height adjusts based on selected mode to fit content.
      height: _settingsExpanded
          ? (_selectedApiMode == ApiMode.runPod ? 280 : 220)
          : 0,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(color: backgroundColor),
      // Clip prevents content showing during collapse animation.
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
          physics:
              const ClampingScrollPhysics(), // Avoid scrolling when closed.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Connection Mode:",
                            style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            // Radio buttons for mode selection.
                            Radio<ApiMode>(
                                value: ApiMode.localServer,
                                groupValue: _selectedApiMode,
                                onChanged: (v) =>
                                    setState(() => _selectedApiMode = v!)),
                            const Text("Local Server"),
                            Radio<ApiMode>(
                                value: ApiMode.runPod,
                                groupValue: _selectedApiMode,
                                onChanged: (v) =>
                                    setState(() => _selectedApiMode = v!)),
                            const Text("RunPod"),
                          ],
                        )
                      ]),
                ),
                // Show relevant fields based on selected API mode.
                if (_selectedApiMode == ApiMode.localServer)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'Local Server URL',
                          hintText: 'http://...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link)),
                      controller: _localServerUrlController,
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                if (_selectedApiMode == ApiMode.runPod) ...[
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('RunPod API Key'),
                    subtitle: Text(settingsProvider
                        .apiKeyStatus), // Display status from provider.
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () => Navigator.pushNamed(context,
                        '/settings'), // Go to main settings to edit key.
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'RunPod Endpoint ID',
                          hintText: 'Enter ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.settings_ethernet)),
                      controller: _runpodEndpointController,
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Action buttons for the inline config section.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        // Test Connection button.
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.network_check, size: 18),
                        label: const Text('Test'),
                        onPressed: _isTesting
                            ? null
                            : () async {
                                setState(() => _isTesting = true);
                                // Temporarily modify ApiService settings for the test.
                                final originalMode =
                                    await _apiService.useLocalServer();
                                final originalUrl =
                                    await _apiService.getLocalServerUrl();
                                final originalEndpoint =
                                    await _apiService.getEndpointId();
                                await _apiService.setUseLocalServer(
                                    _selectedApiMode == ApiMode.localServer);
                                if (_selectedApiMode == ApiMode.localServer) {
                                  await _apiService.saveLocalServerUrl(
                                      _localServerUrlController.text);
                                } else {
                                  await _apiService.saveEndpointId(
                                      _runpodEndpointController.text);
                                }
                                // Run the test.
                                final bool isConnected =
                                    await _apiService.verifyEndpoint();
                                // Restore original settings.
                                await _apiService
                                    .setUseLocalServer(originalMode);
                                await _apiService
                                    .saveLocalServerUrl(originalUrl);
                                if (originalEndpoint != null)
                                  await _apiService
                                      .saveEndpointId(originalEndpoint);

                                setState(() => _isTesting = false);
                                if (mounted) {
                                  // Show result.
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(isConnected
                                              ? 'Connection successful!'
                                              : 'Connection failed.'),
                                          backgroundColor: isConnected
                                              ? Colors.green
                                              : Colors.red));
                                }
                              },
                      ),
                      ElevatedButton.icon(
                          // Save Settings button.
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Save'),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _updateServerSettings();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Chat'),
        elevation: 1.0,
        actions: [
          // Show clear button only if there are messages to clear.
          if (_messages.isNotEmpty &&
              !(_messages.length == 1 && !_messages[0].isUser))
            IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _showClearConfirmationDialog,
                tooltip: 'Clear Chat History'),
          // Toggle settings visibility button.
          IconButton(
            icon: Icon(_settingsExpanded ? Icons.expand_less : Icons.settings),
            onPressed: () {
              setState(() {
                _settingsExpanded = !_settingsExpanded;
                // Refresh UI state from provider when expanding.
                if (_settingsExpanded) {
                  final settings =
                      Provider.of<SettingsProvider>(context, listen: false);
                  _selectedApiMode = settings.apiMode;
                  _localServerUrlController.text = settings.localServerUrl;
                  _runpodEndpointController.text = settings.endpointId ?? '';
                }
              });
              HapticFeedback.selectionClick();
            },
            tooltip: 'Server Settings',
          ),
        ],
      ),
      drawer: const DrawerMenu(currentRoute: '/chat'),
      body: Column(
        children: [
          // Show configuration warning bar if needed.
          if (!_isServerConfigured && !_settingsExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: isDarkMode
                  ? Colors.orange.shade900.withOpacity(0.8)
                  : Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : 'Server not configured.',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.orange.shade100
                                  : Colors.orange.shade800,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                  TextButton(
                    onPressed: () {
                      // Expand settings on tap.
                      setState(() => _settingsExpanded = true);
                      final settings =
                          Provider.of<SettingsProvider>(context, listen: false);
                      _selectedApiMode = settings.apiMode;
                      _localServerUrlController.text = settings.localServerUrl;
                      _runpodEndpointController.text =
                          settings.endpointId ?? '';
                      HapticFeedback.selectionClick();
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child:
                        const Text('Configure', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          // The inline server config section (collapsible).
          _buildServerConfigSection(),
          // Main chat message area.
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? const Center(
                    // Show placeholder when chat is empty.
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Ask me anything about health',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Example: "What are symptoms of diabetes?"',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    // Display the list of messages.
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        MessageBubble(message: _messages[index]),
                  ),
          ),
          // Show typing indicator while waiting for AI response.
          if (_isTyping) const TypingIndicator(),
          // The input field and send button.
          _buildChatInput(),
        ],
      ),
    );
  }
}
