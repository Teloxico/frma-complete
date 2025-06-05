// lib/widgets/drawer_menu.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/appointments_page.dart';
import '../pages/chat_page.dart';
import '../pages/emergency_care_page.dart';
import '../pages/health_metrics_page.dart';
import '../pages/home_page.dart';
import '../pages/med_reminder_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class DrawerMenu extends StatelessWidget {
  final String currentRoute;

  const DrawerMenu({Key? key, required this.currentRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Drawer(
      elevation: 16.0,
      child: Column(
        children: [
          // Enhanced Header with profile info
          _buildHeader(context, profileProvider, settingsProvider, isDarkMode),

          // Navigation items
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black12 : Colors.white,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  _buildNavItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    route: '/home',
                    isSelected: currentRoute == '/home',
                    onTap: () => _navigateTo(context, const HomePage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.chat_rounded,
                    title: 'Health Chat',
                    route: '/chat',
                    isSelected: currentRoute == '/chat',
                    onTap: () => _navigateTo(context, const ChatPage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'My Profile',
                    route: '/profile',
                    isSelected: currentRoute == '/profile',
                    onTap: () => _navigateTo(context, const ProfilePage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.show_chart_rounded,
                    title: 'Health Metrics',
                    route: '/health_metrics',
                    isSelected: currentRoute == '/health_metrics',
                    onTap: () =>
                        _navigateTo(context, const HealthMetricsPage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.medication_rounded,
                    title: 'Medications',
                    route: '/medications',
                    isSelected: currentRoute == '/medications',
                    onTap: () =>
                        _navigateTo(context, const MedicationReminderPage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.calendar_month_rounded,
                    title: 'Appointments',
                    route: '/appointments',
                    isSelected: currentRoute == '/appointments',
                    onTap: () => _navigateTo(context, const AppointmentsPage()),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.emergency_rounded,
                    title: 'Emergency',
                    route: '/emergency',
                    isSelected: currentRoute == '/emergency',
                    onTap: () =>
                        _navigateTo(context, const EmergencyCarePage()),
                    color: Colors.red,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    route: '/settings',
                    isSelected: currentRoute == '/settings',
                    onTap: () => _navigateTo(context, const SettingsPage()),
                  ),

                  // Theme toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            themeProvider.isDarkMode
                                ? 'Dark Mode'
                                : 'Light Mode',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),

                  // App version
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Health Assistant v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // API status indicator (if needed)
          if (settingsProvider.apiKeyStatus.contains("Not configured"))
            Container(
              padding: const EdgeInsets.all(12.0),
              width: double.infinity,
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'API not configured. Check Settings.',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProfileProvider profileProvider,
    SettingsProvider settingsProvider,
    bool isDarkMode,
  ) {
    final primaryColor = settingsProvider.primaryColor;

    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile avatar with better styling
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Text(
                  profileProvider.name.isNotEmpty
                      ? profileProvider.name[0].toUpperCase()
                      : "H",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name with shadow effect for better readability
            Text(
              profileProvider.name.isNotEmpty
                  ? profileProvider.name
                  : 'Health Assistant',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Color.fromARGB(80, 0, 0, 0),
                  ),
                ],
              ),
            ),
            if (profileProvider.age != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${profileProvider.age} years old',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final itemColor = color ?? (isSelected ? theme.colorScheme.primary : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            icon,
            color: itemColor,
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: itemColor,
            ),
          ),
          selected: isSelected,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: isSelected
              ? theme.colorScheme.primary.withOpacity(isDarkMode ? 0.15 : 0.1)
              : null,
          // Add a subtle hover effect
          hoverColor: theme.colorScheme.primary.withOpacity(0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    if (currentRoute != page.runtimeType.toString()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }
}
