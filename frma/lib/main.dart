import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

// Import application pages for routing
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/profile_page.dart';
import 'pages/chat_page.dart';
import 'pages/health_metrics_page.dart';
import 'pages/med_reminder_page.dart';
import 'pages/appointments_page.dart';
import 'pages/emergency_care_page.dart';

// Import providers and services
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';

// Global instance for managing local notifications.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Global key to access the Navigator state from outside the build context,
// used for handling notification taps.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background entry point for handling notification taps when the app is launched from terminated state.
// Needs the @pragma('vm:entry-point') annotation for release mode reliability.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Notification Clicked: ${notificationResponse.payload}');
}

// Main entry point of the Flutter application.
void main() async {
  // Ensure Flutter is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone and notifications.
  await _configureLocalTimeZone();
  await _initializeNotifications();

  // Restrict orientation.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // Initialize preferences and services.
  final prefs = await SharedPreferences.getInstance();
  await ApiService().initialize();

  // Run the application.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}

// Configures the local timezone.
Future<void> _configureLocalTimeZone() async {
  tz_data.initializeTimeZones();
  try {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
  } catch (e) {
    debugPrint("Error configuring timezone: $e");
  }
}

// Initializes the notification plugin and requests permissions.
Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        // Callback for taps when app is running (foreground/background).
        onDidReceiveNotificationResponse: onNotificationTap,
        // Callback for taps launching app from terminated state.
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    // Request permissions on mobile platforms.
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
        // await androidImplementation?.requestExactAlarmsPermission(); // Optional
      } else if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    }
  } catch (e) {
    debugPrint("Error initializing notifications: $e");
  }
}

// Handles notification taps when the app is in the foreground or background (running).
// ALWAYS navigates to the HomePage ('/home').
void onNotificationTap(NotificationResponse notificationResponse) {
  debugPrint(
      'Foreground/Background Notification Tapped - Payload: ${notificationResponse.payload}');
  debugPrint('Action: Navigating to /home');

  // Ensure the navigator is available before attempting navigation.
  if (navigatorKey.currentState != null) {
    // Use the global navigator key to push the '/home' route.
    // This will add HomePage to the stack, even if it's already visible.
    // Consider pushReplacementNamed('/home') if you want to replace the current view,
    // or check ModalRoute.of(context)?.settings.name != '/home' before pushing.
    navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/home', (route) => false); // Clears stack and pushes home
    // Alternatively, just push:
    // navigatorKey.currentState!.pushNamed('/home');
  } else {
    // Log if navigation cannot proceed.
    debugPrint('Navigation to /home failed: navigator unavailable.');
  }
}

// The root application widget.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Health Assistant',
      navigatorKey:
          navigatorKey, // Crucial for navigating from notification taps.
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,

      // Light Theme Configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: settingsProvider.primaryColor,
          secondary: settingsProvider.primaryColor.withAlpha(178),
        ),
        fontFamily: 'Roboto',
      ),

      // Dark Theme Configuration
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: settingsProvider.primaryColor,
          secondary: settingsProvider.primaryColor.withAlpha(178),
          surface: const Color(0xFF1E1E1E),
        ),
        cardTheme: const CardTheme(color: Color(0xFF2C2C2C)),
        fontFamily: 'Roboto',
      ),

      initialRoute: '/home', // Start page.

      // Named routes definition.
      routes: {
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/profile': (context) => const ProfilePage(),
        '/chat': (context) => const ChatPage(),
        '/health_metrics': (context) => const HealthMetricsPage(),
        '/medications': (context) => const MedicationReminderPage(),
        '/appointments': (context) => const AppointmentsPage(),
        '/emergency': (context) => const EmergencyCarePage(),
      },
    );
  }
}
