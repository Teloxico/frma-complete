import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_mode.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/drawer_menu.dart';

/// SettingsPage provides a UI for managing all user preferences,
/// including API configuration, appearance, notifications, and data export.
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isTesting = false;
  ApiMode _selectedApiMode = ApiMode.localServer;
  final _localServerUrlController = TextEditingController();
  final _runpodEndpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeControllers();
    });
  }

  @override
  void dispose() {
    _localServerUrlController.dispose();
    _runpodEndpointController.dispose();
    super.dispose();
  }

  /// Populate controllers and selected mode from the provider
  void _initializeControllers() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _selectedApiMode = settings.apiMode;
      _localServerUrlController.text = settings.localServerUrl;
      _runpodEndpointController.text = settings.endpointId ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 1.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reset Appearance & Notification Settings',
            onPressed: () => _resetSettings(context, settingsProvider),
          ),
        ],
      ),
      drawer: const DrawerMenu(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Configuration
          _buildSectionCard(
            title: 'API Configuration',
            icon: Icons.cloud_queue,
            children: [
              ListTile(
                leading:
                    Icon(_selectedApiMode.icon, color: colorScheme.primary),
                title: const Text('Connection Mode'),
                subtitle: Text(_selectedApiMode.description),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _showApiModeDialog(context, settingsProvider),
              ),
              if (_selectedApiMode == ApiMode.localServer)
                _buildLocalServerSettings(settingsProvider)
              else
                _buildRunPodSettings(settingsProvider),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.network_check_outlined, size: 20),
                    label: const Text('Test Connection'),
                    onPressed: _isTesting
                        ? null
                        : () => _testApiConnection(settingsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        _saveApiSettings(context, settingsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save API Settings'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Appearance Settings
          _buildSectionCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme Mode'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  onChanged: (newMode) {
                    if (newMode != null) themeProvider.setThemeMode(newMode);
                  },
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('System Default')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  underline: Container(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('Primary Color'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: settingsProvider.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                onTap: () => _showColorPicker(context, settingsProvider),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_outlined),
                title: const Text('Font Size'),
                subtitle: Slider(
                  value: settingsProvider.fontSize,
                  min: 12,
                  max: 24,
                  divisions: 6,
                  label: '${settingsProvider.fontSize.round()}',
                  onChanged: (value) => settingsProvider.setFontSize(value),
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.contrast_outlined),
                title: const Text('High Contrast Mode'),
                subtitle:
                    const Text('Increases UI contrast (requires app restart)'),
                value: settingsProvider.highContrast,
                onChanged: (_) => settingsProvider.toggleHighContrast(),
                activeColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notification Settings
          _buildSectionCard(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive health & medication reminders'),
                value: settingsProvider.enableNotifications,
                onChanged: (_) => settingsProvider.toggleNotifications(),
                activeColor: colorScheme.primary,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Sound Effects'),
                subtitle: const Text('Play sounds for actions & notifications'),
                value: settingsProvider.enableSoundEffects,
                onChanged: (_) => settingsProvider.toggleSoundEffects(),
                activeColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Privacy & Data
          _buildSectionCard(
            title: 'Privacy & Data',
            icon: Icons.privacy_tip_outlined,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.history_outlined),
                title: const Text('Save Conversation History'),
                subtitle: const Text('Keep chat messages locally'),
                value: settingsProvider.saveConversationHistory,
                onChanged: (_) =>
                    settingsProvider.toggleSaveConversationHistory(),
                activeColor: colorScheme.primary,
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export Your Data'),
                subtitle: const Text('Copy profile & settings to clipboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportData(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Clear All App Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => _showClearDataDialog(context),
                  ),
                ),
              ),
            ],
          ),

          // Footer with version info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Health Assistant v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // Local server settings input field
  Widget _buildLocalServerSettings(SettingsProvider settingsProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _localServerUrlController,
        decoration: const InputDecoration(
          labelText: 'Local Server URL',
          hintText: 'e.g., http://192.168.1.10:8000',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.link_outlined),
        ),
        keyboardType: TextInputType.url,
      ),
    );
  }

  // RunPod settings: API key and endpoint ID
  Widget _buildRunPodSettings(SettingsProvider settingsProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('RunPod API Key'),
            subtitle: Text(settingsProvider.apiKeyStatus),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () => _showApiKeyDialog(context, settingsProvider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _runpodEndpointController,
              decoration: const InputDecoration(
                labelText: 'RunPod Endpoint ID',
                hintText: 'Enter your RunPod endpoint ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card wrapper for each settings section
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Display dialog to choose connection mode
  void _showApiModeDialog(
      BuildContext context, SettingsProvider settingsProvider) {
    final initial = _selectedApiMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Connection Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildApiModeOption(
              context: ctx,
              mode: ApiMode.localServer,
              isSelected: _selectedApiMode == ApiMode.localServer,
              onTap: () {
                setState(() => _selectedApiMode = ApiMode.localServer);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            _buildApiModeOption(
              context: ctx,
              mode: ApiMode.runPod,
              isSelected: _selectedApiMode == ApiMode.runPod,
              onTap: () {
                setState(() => _selectedApiMode = ApiMode.runPod);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedApiMode = initial);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Option widget inside the API mode dialog
  Widget _buildApiModeOption({
    required BuildContext context,
    required ApiMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(mode.icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
                size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? theme.colorScheme.primary : null)),
                  const SizedBox(height: 4),
                  Text(mode.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor),
          ],
        ),
      ),
    );
  }

  // Save API settings to the provider
  Future<void> _saveApiSettings(
      BuildContext context, SettingsProvider settingsProvider) async {
    HapticFeedback.mediumImpact();
    final localUrl = _localServerUrlController.text.trim();
    final endpointId = _runpodEndpointController.text.trim();
    final modeToSave = _selectedApiMode;

    if (modeToSave == ApiMode.localServer &&
        !localUrl.startsWith(RegExp(r'https?://'))) {
      _showErrorSnackbar(context, 'Invalid Local Server URL format.');
      return;
    }
    if (modeToSave == ApiMode.runPod && endpointId.isEmpty) {
      _showErrorSnackbar(context, 'RunPod Endpoint ID cannot be empty.');
      return;
    }

    try {
      await settingsProvider.setApiMode(modeToSave);
      if (modeToSave == ApiMode.localServer) {
        await settingsProvider.setLocalServerUrl(localUrl);
      } else {
        await settingsProvider.setEndpointId(endpointId);
      }
      _showSuccessSnackbar(context, 'API settings saved!');
    } catch (e) {
      debugPrint('Error saving API settings: $e');
      _showErrorSnackbar(context, 'Error saving settings.');
    }
  }

  // Test connectivity without permanently changing settings
  Future<void> _testApiConnection(SettingsProvider settingsProvider) async {
    setState(() => _isTesting = true);
    final mode = _selectedApiMode;
    final tempUrl = _localServerUrlController.text.trim();
    final tempEndpoint = _runpodEndpointController.text.trim();

    // Backup original values
    final origMode = settingsProvider.apiMode;
    final origUrl = settingsProvider.localServerUrl;
    final origEndpoint = settingsProvider.endpointId;

    try {
      await settingsProvider.setApiMode(mode);
      if (mode == ApiMode.localServer) {
        await settingsProvider.setLocalServerUrl(tempUrl);
      } else {
        await settingsProvider.setEndpointId(tempEndpoint);
      }
      final success = await settingsProvider.testConnection();
      _showInfoSnackbar(context,
          success ? 'Connection successful!' : 'Connection failed.', success);
    } catch (e) {
      debugPrint('Error testing connection: $e');
      _showErrorSnackbar(context, 'Error during connection test.');
    } finally {
      // Restore backups
      await settingsProvider.setApiMode(origMode);
      await settingsProvider.setLocalServerUrl(origUrl);
      await settingsProvider.setEndpointId(origEndpoint ?? '');
      setState(() => _isTesting = false);
    }
  }

  // Dialog to set or clear RunPod API key
  void _showApiKeyDialog(
      BuildContext context, SettingsProvider settingsProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set RunPod API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Paste your RunPod API key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key_outlined),
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (settingsProvider.apiKeyStatus != 'Not configured')
            TextButton(
              onPressed: () async {
                try {
                  await settingsProvider.clearApiKey();
                  Navigator.pop(ctx);
                  _showSuccessSnackbar(context, 'API Key cleared.');
                } catch (e) {
                  debugPrint('Error clearing API key: $e');
                  _showErrorSnackbar(context, 'Failed to clear API Key.');
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Clear Key'),
            ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                try {
                  await settingsProvider.setApiKey(key);
                  Navigator.pop(ctx);
                  _showSuccessSnackbar(context, 'API Key saved.');
                } catch (e) {
                  debugPrint('Error saving API key: $e');
                  _showErrorSnackbar(context, 'Failed to save API Key.');
                }
              } else {
                _showErrorSnackbar(ctx, 'API Key cannot be empty.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Color picker dialog for selecting primary color
  void _showColorPicker(
      BuildContext context, SettingsProvider settingsProvider) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.lime,
      Colors.brown,
      Colors.grey.shade600,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Primary Color'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: colors.map((color) {
              final isSelected = color == settingsProvider.primaryColor;
              return GestureDetector(
                onTap: () {
                  settingsProvider.setPrimaryColor(color);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.outline
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          spreadRadius: 1)
                    ],
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))
        ],
      ),
    );
  }

  // Confirm reset of appearance & notification settings only
  void _resetSettings(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
            'Reset Appearance and Notification settings to defaults? API settings remain unchanged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await settingsProvider.resetToDefaults();
                if (mounted) {
                  Navigator.pop(ctx);
                  _initializeControllers();
                  _showSuccessSnackbar(context, 'Settings reset to defaults.');
                }
              } catch (e) {
                debugPrint('Error resetting settings: $e');
                if (mounted)
                  _showErrorSnackbar(context, 'Failed to reset settings.');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // Confirm clearing all app data including profile & settings
  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All App Data?'),
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error),
        content: const Text(
            'WARNING: Permanently delete profile, settings, history, etc.? This cannot be undone!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Future.delayed(const Duration(milliseconds: 300));
              try {
                await _clearAllData(context);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showSuccessSnackbar(context, 'All app data cleared.');
                }
              } catch (e) {
                debugPrint('Error clearing data: $e');
                if (mounted)
                  _showErrorSnackbar(context, 'Failed to clear app data.');
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('CLEAR ALL DATA'),
          ),
        ],
      ),
    );
  }

  // Perform full data clear: shared prefs, providers, secure storage
  Future<void> _clearAllData(BuildContext context) async {
    if (!mounted) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
    profileProvider.clearProfile();
    await settingsProvider.resetToDefaults();
    try {
      await settingsProvider.clearApiKey();
    } catch (_) {
      debugPrint('Note: Could not clear API key during full data clear.');
    }
    if (mounted) _initializeControllers();
  }

  // Export data as JSON and copy to clipboard
  Future<void> _exportData(BuildContext context) async {
    if (!mounted) return;
    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final exportData = {
        'profile': {
          'name': profileProvider.name,
          'dateOfBirth': profileProvider.dateOfBirth?.toIso8601String(),
          'gender': profileProvider.gender,
          'weight': profileProvider.weight,
          'height': profileProvider.height,
          'bloodType': profileProvider.bloodType,
          'medicalConditions': profileProvider.medicalConditions
              .where((c) => c.selected)
              .map((c) => c.name)
              .toList(),
          'allergies': profileProvider.allergies,
          'medications':
              profileProvider.medications.map((m) => m.toJson()).toList(),
          'emergencyContacts':
              profileProvider.emergencyContacts.map((c) => c.toJson()).toList(),
        },
        'settings': {
          'primaryColorValue': settingsProvider.primaryColor.value,
          'fontSize': settingsProvider.fontSize,
          'highContrast': settingsProvider.highContrast,
          'enableNotifications': settingsProvider.enableNotifications,
          'enableSoundEffects': settingsProvider.enableSoundEffects,
          'saveConversationHistory': settingsProvider.saveConversationHistory,
          'apiMode': settingsProvider.apiMode.name,
          'localServerUrl': settingsProvider.localServerUrl,
          'endpointId': settingsProvider.endpointId,
        },
        'exportMetadata': {
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.0.0',
        },
      };
      const encoder = JsonEncoder.withIndent('  ');
      final jsonData = encoder.convert(exportData);
      await Clipboard.setData(ClipboardData(text: jsonData));
      _showSuccessSnackbar(context, 'Data copied to clipboard.');
    } catch (e) {
      debugPrint('Error exporting data: $e');
      _showErrorSnackbar(context, 'Error exporting data.');
    }
  }

  // Snackbar helpers
  void _showSuccessSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade600),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showInfoSnackbar(BuildContext context, String message, bool success) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green.shade600 : Colors.orange.shade700,
      ),
    );
  }
}
