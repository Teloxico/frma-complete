// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/drawer_menu.dart';

// Import the screens accessible from the home page
import 'chat_page.dart';
import 'health_metrics_page.dart';
import 'med_reminder_page.dart';
import 'appointments_page.dart';
import 'emergency_care_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

/// The HomePage widget serves as the central dashboard for the FRMA
/// application, offering navigation to key features and managing
/// daily water consumption tracking.
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Timer used to trigger hourly hydration reminders
  Timer? _waterReminderTimer;

  /// Timestamp of the last displayed hydration reminder
  DateTime? _lastWaterReminder;

  /// Controls whether the reminder notification is visible
  bool _showWaterReminder = false;

  /// Flag to enable or disable hydration reminders
  bool _waterRemindersEnabled = true;

  /// Count of glasses of water consumed today
  int _glassesConsumed = 0;

  /// Volume of a single glass in milliliters (customizable)
  int _glassSize = 200;

  /// Daily hydration target in milliliters (adjusted by user profile)
  int _dailyGoal = 4000;

  /// Indicates whether the celebration animation should appear
  bool _showCelebration = false;

  /// Flag that marks completion of today's hydration goal
  bool _goalReached = false;

  @override
  void initState() {
    super.initState();
    // Begin the hydration reminder cycle
    _initWaterReminderTimer();
    // Restore persisted water intake data
    _loadWaterTrackingData();
  }

  @override
  void dispose() {
    _waterReminderTimer?.cancel();
    super.dispose();
  }

  /// Set the daily hydration target based on the user's gender
  void _initializeWaterGoal() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Default target if gender is unspecified
    int goalBasedOnGender = 4000;

    if (profileProvider.gender.toLowerCase() == 'male') {
      // Recommended target for male users
      goalBasedOnGender = 5000;
    } else if (profileProvider.gender.toLowerCase() == 'female') {
      // Recommended target for female users
      goalBasedOnGender = 4000;
    }

    SharedPreferences.getInstance().then((prefs) {
      final savedGoal = prefs.getInt('daily_water_goal');
      setState(() {
        _dailyGoal = savedGoal ?? goalBasedOnGender;
      });
    }).catchError((e) {
      debugPrint('Error loading water goal: $e');
      setState(() {
        _dailyGoal = goalBasedOnGender;
      });
    });
  }

  /// Load persisted data for today's water tracking
  Future<void> _loadWaterTrackingData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      final int savedGlassSize = prefs.getInt('glass_size') ?? 200;
      final String? lastTrackedDate =
          prefs.getString('last_water_tracked_date');
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      setState(() {
        _glassSize = savedGlassSize;
      });

      // Determine if tracking should reset for a new calendar day
      _initializeWaterGoal();
      if (lastTrackedDate != today) {
        setState(() {
          _glassesConsumed = 0;
          _goalReached = false;
        });
        await prefs.setString('last_water_tracked_date', today);
        await prefs.setInt('glasses_consumed', 0);
        await prefs.setBool('water_goal_reached', false);
      } else {
        setState(() {
          _glassesConsumed = prefs.getInt('glasses_consumed') ?? 0;
          _goalReached = prefs.getBool('water_goal_reached') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading water tracking data: $e');
    }
  }

  /// Persist the current water intake state to local storage
  Future<void> _saveWaterTrackingData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('glasses_consumed', _glassesConsumed);
      await prefs.setBool('water_goal_reached', _goalReached);
      await prefs.setString('last_water_tracked_date',
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
    } catch (e) {
      debugPrint('Error saving water tracking data: $e');
    }
  }

  /// Configure a repeating timer to check for hourly reminders
  void _initWaterReminderTimer() {
    _lastWaterReminder = DateTime.now();

    _waterReminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_waterRemindersEnabled) return;

      final now = DateTime.now();
      final difference = now.difference(_lastWaterReminder!);

      if (difference.inHours >= 1) {
        setState(() {
          _showWaterReminder = true;
          _lastWaterReminder = now;
        });
        // Automatically dismiss the reminder after 15 seconds
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted) {
            setState(() {
              _showWaterReminder = false;
            });
          }
        });
      }
    });
  }

  /// Increment the glass count when a standard serving is logged
  void _logWaterGlass() {
    if (_goalReached) return;

    setState(() {
      _glassesConsumed++;
      final int totalConsumed = _glassesConsumed * _glassSize;
      if (totalConsumed >= _dailyGoal) {
        _goalReached = true;
        _showCongratulations();
      }
    });

    _saveWaterTrackingData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Great job! $_glassSize ml of water added'),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Display a dialog allowing the user to specify a custom volume
  void _showCustomWaterInputDialog() {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Water'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (ml)',
                hintText: 'e.g., 250',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Your default glass size is $_glassSize ml',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                final int amount = int.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  _logCustomWaterAmount(amount);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Handle logging of a user-defined quantity of water
  void _logCustomWaterAmount(int amountInMl) {
    if (amountInMl <= 0) return;

    setState(() {
      final double glassesEquivalent = amountInMl / _glassSize;
      _glassesConsumed += glassesEquivalent.ceil();
      final int totalConsumed = _glassesConsumed * _glassSize;
      if (totalConsumed >= _dailyGoal) {
        _goalReached = true;
        _showCongratulations();
      }
    });

    _saveWaterTrackingData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Great job! $amountInMl ml of water added'),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Present a dialog to adjust the standard glass volume
  void _showCustomGlassSizeDialog() {
    final TextEditingController glassController =
        TextEditingController(text: _glassSize.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Glass Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: glassController,
              decoration: const InputDecoration(
                labelText: 'Glass Size (ml)',
                hintText: 'e.g., 250',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (glassController.text.isNotEmpty) {
                final int size = int.tryParse(glassController.text) ?? 0;
                if (size > 0) {
                  setState(() {
                    _glassSize = size;
                  });
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setInt('glass_size', size);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Glass size updated to $_glassSize ml'),
                    duration: const Duration(seconds: 2),
                  ));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Allow the user to set a custom daily hydration target
  void _showCustomDailyGoalDialog() {
    final TextEditingController goalController =
        TextEditingController(text: _dailyGoal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Daily Water Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalController,
              decoration: const InputDecoration(
                labelText: 'Goal (ml)',
                hintText: 'e.g., 4000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Recommended: 4000ml (women) or 5000ml (men)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (goalController.text.isNotEmpty) {
                final int goal = int.tryParse(goalController.text) ?? 0;
                if (goal >= 1000) {
                  setState(() {
                    _dailyGoal = goal;
                    final int totalConsumed = _glassesConsumed * _glassSize;
                    _goalReached = totalConsumed >= goal;
                  });
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setInt('daily_water_goal', goal);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Daily goal updated to $_dailyGoal ml'),
                    duration: const Duration(seconds: 2),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter a goal of at least 1000ml'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Reset the hydration tracking data for the current day
  void _resetWaterTracking() {
    setState(() {
      _glassesConsumed = 0;
      _goalReached = false;
    });

    _saveWaterTrackingData();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Water tracking reset for today')));
  }

  /// Construct a visual representation of a water glass
  Widget _buildWaterGlass(bool filled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 24,
      height: 32,
      decoration: BoxDecoration(
        color: filled ? Colors.blue.withOpacity(0.7) : Colors.transparent,
        border: Border.all(
          color: Colors.blue.shade300,
          width: 2,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
    );
  }

  /// Compute the remaining time until the next hydration reminder
  String _formatTimeUntilReminder() {
    if (_lastWaterReminder == null) return "1 hour";

    final now = DateTime.now();
    final nextReminder = _lastWaterReminder!.add(const Duration(hours: 1));
    final difference = nextReminder.difference(now);

    final minutes = difference.inMinutes;
    if (minutes < 1) return "less than a minute";
    return "$minutes ${minutes == 1 ? 'minute' : 'minutes'}";
  }

  /// Show a congratulatory dialog when the daily goal is met
  void _showCongratulations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.blue.shade50,
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('Congratulations!',
                style: TextStyle(color: Colors.blue)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                children: List.generate(
                  20,
                  (index) => Positioned(
                    left: 10.0 * index,
                    top: index % 2 == 0 ? 20.0 : 40.0,
                    child: Icon(
                      Icons.water_drop,
                      color: Colors.blue.withOpacity(0.7),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'You\'ve reached your daily water goal of $_dailyGoal ml! 🎉\n\nStaying hydrated is a key part of maintaining good health. Keep up the great work!',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Thanks!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FRMA'),
        centerTitle: true,
        elevation: 2.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfilePage())),
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: const DrawerMenu(currentRoute: '/home'),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // Provide tactile feedback on refresh
              await Future.delayed(const Duration(milliseconds: 800));
              HapticFeedback.mediumImpact();
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Header section with greeting and avatar
                _buildEnhancedHeader(
                    context, profileProvider, settingsProvider),

                // Display a rotating daily wellness tip
                _buildHealthTip(context, isDarkMode),

                // Quick access emergency button
                _buildEmergencyButton(context),

                // Grid of primary feature tiles
                _buildFeaturesGrid(context, size),

                // Hydration tracker with goals and reminders
                _buildWaterReminderSection(context, isDarkMode),
              ],
            ),
          ),

          // Overlay notification for hydration reminder
          if (_showWaterReminder) _buildWaterReminderNotification(context),
        ],
      ),
    );
  }

  // Build enhanced header with uplifting message
  Widget _buildEnhancedHeader(BuildContext context,
      ProfileProvider profileProvider, SettingsProvider settingsProvider) {
    final String timeBasedGreeting = _getGreeting();
    final String name = profileProvider.name.isNotEmpty
        ? profileProvider.name.split(' ')[0]
        : "friend";

    // Get wellness message based on time of day
    final String wellnessMessage = _getWellnessMessage();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            settingsProvider.primaryColor,
            settingsProvider.primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: settingsProvider.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar and greeting
            Row(
              children: [
                // Enhanced avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      profileProvider.name.isNotEmpty
                          ? profileProvider.name[0].toUpperCase()
                          : "H",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: settingsProvider.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Warm, personalized greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$timeBasedGreeting, $name",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Uplifting, time-relevant message
                      Text(
                        wellnessMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Decorative pattern (small dots)
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get wellness message based on time of day with expanded variety
  String _getWellnessMessage() {
    final hour = DateTime.now().hour;
    final random = DateTime.now().microsecond % 8;

    // Morning messages (5 AM - 11 AM)
    if (hour >= 5 && hour < 12) {
      final morningMessages = [
        "Ready to make today amazing?",
        "Let's start the day with positive energy!",
        "A healthy morning sets the tone for your day.",
        "Time to embrace today's possibilities!",
        "Every morning is a fresh start. Make it count!",
        "Rise and shine! Your body needs you today.",
        "Morning routines build healthy foundations.",
        "Mindful mornings lead to productive days."
      ];
      return morningMessages[random];
    }

    // Afternoon messages (12 PM - 5 PM)
    else if (hour >= 12 && hour < 18) {
      final afternoonMessages = [
        "Hope your day is going well!",
        "Taking care of yourself today?",
        "Remember to take a moment for yourself.",
        "A healthy break can boost your afternoon.",
        "Stay hydrated throughout your busy day!",
        "A short walk can recharge your afternoon energy.",
        "Afternoon slump? Try some deep breathing exercises.",
        "Don't forget to stretch if you've been sitting long."
      ];
      return afternoonMessages[random];
    }

    // Evening messages (6 PM - 9 PM)
    else if (hour >= 18 && hour < 22) {
      final eveningMessages = [
        "Winding down for a restful evening?",
        "How was your day? Time to relax.",
        "Evenings are perfect for self-care.",
        "Take a moment to reflect on today's achievements.",
        "Consider a gentle evening stretch routine.",
        "Preparing for quality sleep will improve tomorrow.",
        "Evening is a good time to practice gratitude.",
        "Your mind needs unwinding just as much as your body."
      ];
      return eveningMessages[random];
    }

    // Night messages (10 PM - 4 AM)
    else {
      final nightMessages = [
        "Getting ready for restful sleep?",
        "Remember: quality sleep is essential for health.",
        "Tomorrow brings new opportunities.",
        "Wishing you peaceful dreams ahead.",
        "Proper sleep helps your body recover and heal.",
        "Try to avoid screens right before bedtime.",
        "A calm mind leads to better sleep quality.",
        "Set yourself up for success with good sleep habits."
      ];
      return nightMessages[random];
    }
  }

  // Build a feature tile for the grid
  Widget _buildFeatureTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the features grid section
  Widget _buildFeaturesGrid(BuildContext context, Size size) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: size.width > 600 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildFeatureTile(
                context: context,
                title: 'Health Chat',
                icon: Icons.chat_rounded,
                color: Colors.blue,
                onTap: () => _navigateTo(const ChatPage()),
              ),
              _buildFeatureTile(
                context: context,
                title: 'Health Metrics',
                icon: Icons.show_chart,
                color: Colors.purple,
                onTap: () => _navigateTo(const HealthMetricsPage()),
              ),
              _buildFeatureTile(
                context: context,
                title: 'Medications',
                icon: Icons.medication,
                color: Colors.orange,
                onTap: () => _navigateTo(const MedicationReminderPage()),
              ),
              _buildFeatureTile(
                context: context,
                title: 'Appointments',
                icon: Icons.calendar_month,
                color: Colors.teal,
                onTap: () => _navigateTo(const AppointmentsPage()),
              ),
              _buildFeatureTile(
                context: context,
                title: 'Profile',
                icon: Icons.person,
                color: Colors.indigo,
                onTap: () => _navigateTo(const ProfilePage()),
              ),
              _buildFeatureTile(
                context: context,
                title: 'Settings',
                icon: Icons.settings,
                color: Colors.blueGrey,
                onTap: () => _navigateTo(const SettingsPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Navigation helper
  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  // Get appropriate greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  // Build the water reminder section with improved tracking
  Widget _buildWaterReminderSection(BuildContext context, bool isDarkMode) {
    // Calculate progress percentage
    final int totalConsumed = _glassesConsumed * _glassSize;
    final double progressPercentage =
        (totalConsumed / _dailyGoal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop,
                    color: Colors.blue,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Water Tracker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  // Toggle button for water reminders
                  Switch(
                    value: _waterRemindersEnabled,
                    onChanged: (value) {
                      setState(() {
                        _waterRemindersEnabled = value;
                        if (value && _waterReminderTimer == null) {
                          _initWaterReminderTimer();
                        }
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),

              // Configuration row
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _showCustomDailyGoalDialog,
                      child: Row(
                        children: [
                          Text(
                            'Goal: $_dailyGoal ml',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Icon(Icons.edit,
                              size: 14,
                              color:
                                  isDarkMode ? Colors.white60 : Colors.black54)
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _showCustomGlassSizeDialog,
                      child: Row(
                        children: [
                          Text(
                            'Glass: $_glassSize ml',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Icon(Icons.edit,
                              size: 14,
                              color:
                                  isDarkMode ? Colors.white60 : Colors.black54)
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Water consumption progress bar
              Stack(
                children: [
                  // Background progress bar
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),

                  // Filled progress bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 10,
                    width: (MediaQuery.of(context).size.width - 64) *
                        progressPercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade300, Colors.blue.shade600],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),

                  // Goal indicator mark at 100%
                  if (progressPercentage >= 1.0)
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Water consumption stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalConsumed ml / $_dailyGoal ml',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    '${(progressPercentage * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),

              // Glass visualization - only show consumed glasses
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    _glassesConsumed.clamp(
                        0, 20), // Limit to reasonable display
                    (index) => _buildWaterGlass(true),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Track your daily water intake. Your personal goal is based on your profile.',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                _waterRemindersEnabled
                    ? 'Next reminder in: ${_formatTimeUntilReminder()}'
                    : 'Reminders disabled',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                ),
              ),

              const SizedBox(height: 16),
              // Water logging buttons - now with two options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add glass button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _goalReached ? null : _logWaterGlass,
                      icon: const Icon(Icons.local_drink),
                      label: const Text('Add Glass'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.blue.shade200,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add custom amount button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _goalReached ? null : _showCustomWaterInputDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Custom'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.teal.shade200,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              // Reset button (more prominent when goal is reached)
              const SizedBox(height: 16),
              Center(
                child: _goalReached
                    ? ElevatedButton(
                        onPressed: _resetWaterTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reset for today'),
                      )
                    : TextButton(
                        onPressed: _resetWaterTracking,
                        child: const Text('Reset for today'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced health tip section with expanded variety
  Widget _buildHealthTip(BuildContext context, bool isDarkMode) {
    // Get a random health tip
    final String healthTip = _getRandomHealthTip();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Daily Wellness Tip',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  healthTip,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Get a random health tip - expanded with 20 tips
  String _getRandomHealthTip() {
    final List<String> healthTips = [
      'Stay hydrated by drinking water throughout the day. Proper hydration supports brain function, digestion, and regulates body temperature.',
      'Aim for 7-9 hours of quality sleep each night. Good sleep boosts your immune system and improves mental clarity.',
      'Take short breaks every hour to stretch and rest your eyes if you work at a computer. This reduces eye strain and muscle tension.',
      'Include colorful fruits and vegetables in your diet to provide essential vitamins and antioxidants for optimal health.',
      'Just 30 minutes of moderate physical activity most days can significantly improve your mood and overall health.',
      'Practice deep breathing for 5 minutes when feeling stressed. Breathe in for 4 counts, hold for 2, and exhale for 6 to activate relaxation.',
      'Small healthy habits add up! Try taking the stairs, parking further away, or adding an extra serving of vegetables to your meals.',
      'Remember to maintain good posture throughout the day. Align your head, shoulders, and hips to reduce strain on your spine.',
      'Limit processed foods and added sugars. Focus on whole foods like fruits, vegetables, whole grains, and lean proteins.',
      'Stay socially connected. Strong relationships are linked to better health, longevity, and lower rates of depression.',
      'Practice mindfulness daily, even for just 5 minutes. This can reduce stress and improve focus and emotional regulation.',
      'Protect your skin by using sunscreen daily, even on cloudy days. This helps prevent premature aging and reduces skin cancer risk.',
      'Regular health check-ups can catch potential issues early. Follow recommended screening guidelines for your age and risk factors.',
      'Keep your brain active with puzzles, reading, learning new skills, or taking alternate routes during your commute.',
      'Wash your hands frequently to prevent the spread of germs, especially before eating and after using public facilities.',
      'Find ways to include more movement throughout your day – stretching during TV commercials or walking while on phone calls.',
      'Laughter can boost your immune system and reduce stress hormones. Make time for humor and joy in your daily life.',
      'Limit caffeine intake after midday to protect your sleep quality, as caffeine can stay in your system for up to 8 hours.',
      'Practice gratitude by noting three things you are thankful for each day. This can improve mental health and outlook on life.',
      'Set boundaries on screen time. Try to avoid screens at least one hour before bedtime to improve sleep quality.'
    ];

    final random = DateTime.now().day % healthTips.length;
    return healthTips[random];
  }

  // Build water reminder notification
  Widget _buildWaterReminderNotification(BuildContext context) {
    return SafeArea(
      child: Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade400),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hydration Reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time to drink some water! Stay hydrated for better health.',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showWaterReminder = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build emergency button
  Widget _buildEmergencyButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EmergencyCarePage()),
        ),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade700,
                Colors.red.shade900,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EmergencyCarePage()),
              ),
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Get immediate medical assistance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
