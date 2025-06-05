// lib/pages/emergency_care_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:url_launcher/url_launcher.dart'; // For making phone calls
import '../services/location_service.dart'; // For getting user location
import '../widgets/drawer_menu.dart'; // App navigation drawer
import 'emergency_assessment_page.dart'; // The next page in the flow

// Simple data structure to hold display info for each emergency type shown on the page.
class EmergencyData {
  final String id; // Unique identifier, used to load assessment data
  final String title;
  final IconData icon;
  final Color color;
  final bool
      isHighPriority; // Determines if it's listed first and shows warnings
  final String description;

  EmergencyData({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.isHighPriority,
    required this.description,
  });
}

/// Displays a list of common emergencies and provides quick access to call emergency services.
class EmergencyCarePage extends StatefulWidget {
  const EmergencyCarePage({Key? key}) : super(key: key);

  @override
  State<EmergencyCarePage> createState() => _EmergencyCarePageState();
}

class _EmergencyCarePageState extends State<EmergencyCarePage>
    with SingleTickerProviderStateMixin {
  // For the pulsing animation on the call bar icon
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _pulseTimer; // Used to trigger rebuilds for the flashing effect

  // Location related state
  final LocationService _locationService = LocationService();
  String _locationInfo = "Retrieving location..."; // Displayed location string
  String _countryCode =
      "IN"; // Default country code (used for emergency numbers)
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;
  Timer? _refreshLocationTimer; // Periodically updates location

  // Hardcoded data for emergency types displayed on this page
  final Map<String, EmergencyData> _emergencyDatabase = {};
  // Hardcoded map of emergency numbers by country code.
  final Map<String, Map<String, String>> _emergencyNumbers = {
    'US': {'general': '911', 'ambulance': '911'},
    'UK': {'general': '999', 'ambulance': '999', 'non_urgent': '111'},
    'IN': {'general': '112', 'ambulance': '108'}, // India
    'AU': {'general': '000', 'ambulance': '000'},
    'CA': {'general': '911', 'ambulance': '911'},
    'DEFAULT': {'general': '112', 'ambulance': '108'}, // Fallback
  };
  String _activeEmergencyNumber =
      '112'; // The number currently displayed/dialed
  String _selectedEmergencyService =
      'general'; // Type of service selected ('general', 'ambulance', etc.)

  @override
  void initState() {
    super.initState();

    // --- Animation Setup ---
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true); // Make the icon pulse in/out
    // Timer to make the call bar background flash slightly (triggers rebuilds)
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });
    // --- End Animation Setup ---

    _populateEmergencyDatabase(); // Load the hardcoded list of emergencies
    _getLocationAndNumbers(); // Get initial location and set emergency number

    // Refresh location every 5 minutes
    _refreshLocationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _getLocationAndNumbers();
    });
  }

  // Defines the list of emergencies shown on the page.
  void _populateEmergencyDatabase() {
    // HIGH PRIORITY
    _emergencyDatabase['heart_attack'] = EmergencyData(
        id: 'heart_attack',
        title: 'Heart Attack',
        icon: Icons.favorite,
        color: Colors.red,
        isHighPriority: true,
        description:
            'Signs include chest pain, shortness of breath, nausea, sweating.');
    _emergencyDatabase['stroke'] = EmergencyData(
        id: 'stroke',
        title: 'Stroke',
        icon: Icons.psychology,
        color: Colors.deepOrange,
        isHighPriority: true,
        description:
            'Use FAST: Face drooping, Arm weakness, Speech difficulty, Time to call.');
    _emergencyDatabase['severe_bleeding'] = EmergencyData(
        id: 'severe_bleeding',
        title: 'Severe Bleeding',
        icon: Icons.bloodtype,
        color: Colors.red.shade700,
        isHighPriority: true,
        description:
            'Apply direct pressure to the wound and call for help immediately.');
    _emergencyDatabase['unconscious'] = EmergencyData(
        id: 'unconscious',
        title: 'Unconscious Person',
        icon: Icons.airline_seat_flat_angled,
        color: Colors.purple,
        isHighPriority: true,
        description:
            'Check for breathing. Place in recovery position if breathing.');
    _emergencyDatabase['poisoning'] = EmergencyData(
        id: 'poisoning',
        title: 'Poisoning',
        icon: Icons.warning_rounded,
        color: Colors.deepPurple,
        isHighPriority: true,
        description:
            'Call poison control immediately. Dont induce vomiting unless instructed.');
    _emergencyDatabase['burns'] = EmergencyData(
        id: 'burns',
        title: 'Severe Burns',
        icon: Icons.local_fire_department,
        color: Colors.orange.shade800,
        isHighPriority: true,
        description:
            'Cool with running water for 10-20 minutes. Dont use ice or creams.');
    _emergencyDatabase['choking'] = EmergencyData(
        id: 'choking',
        title: 'Choking',
        icon: Icons.no_food,
        color: Colors.red.shade500,
        isHighPriority: true,
        description:
            'Perform abdominal thrusts (Heimlich maneuver) if person cannot breathe.');
    _emergencyDatabase['anaphylaxis'] = EmergencyData(
        id: 'anaphylaxis',
        title: 'Severe Allergic Reaction',
        icon: Icons.coronavirus,
        color: Colors.red.shade600,
        isHighPriority: true,
        description:
            'Use epinephrine auto-injector if available. Call emergency services.');
    // MEDIUM PRIORITY
    _emergencyDatabase['chest_pain'] = EmergencyData(
        id: 'chest_pain',
        title: 'Chest Pain',
        icon: Icons.monitor_heart,
        color: Colors.pink,
        isHighPriority: false,
        description:
            'Can be serious. Seek medical advice if severe or persistent.');
    _emergencyDatabase['breathing'] = EmergencyData(
        id: 'breathing',
        title: 'Breathing Difficulty',
        icon: Icons.air,
        color: Colors.blue,
        isHighPriority: false,
        description:
            'Help person sit upright. Call emergency if severe or worsening.');
    _emergencyDatabase['broken_bone'] = EmergencyData(
        id: 'broken_bone',
        title: 'Broken Bone',
        icon: Icons.healing,
        color: Colors.amber.shade700,
        isHighPriority: false,
        description:
            'Immobilize the injured area. Dont attempt to realign the bone.');
    _emergencyDatabase['head_injury'] = EmergencyData(
        id: 'head_injury',
        title: 'Head Injury',
        icon: Icons.face,
        color: Colors.indigo,
        isHighPriority: false,
        description:
            'Monitor for confusion, vomiting, or loss of consciousness. Seek medical help.');
    _emergencyDatabase['seizure'] = EmergencyData(
        id: 'seizure',
        title: 'Seizure',
        icon: Icons.electric_bolt,
        color: Colors.purple.shade700,
        isHighPriority: false,
        description:
            'Clear area of hazards. Time the seizure. Call emergency if longer than 5 minutes.');
    _emergencyDatabase['minor_burns'] = EmergencyData(
        id: 'minor_burns',
        title: 'Minor Burns',
        icon: Icons.whatshot,
        color: Colors.orange,
        isHighPriority: false,
        description:
            'Cool with cold running water for 10-20 minutes. Cover with clean bandage.');
    _emergencyDatabase['heat_exhaustion'] = EmergencyData(
        id: 'heat_exhaustion',
        title: 'Heat Exhaustion',
        icon: Icons.thermostat,
        color: Colors.orange.shade600,
        isHighPriority: false,
        description:
            'Move to cool place. Drink water. Seek help if symptoms worsen.');
    _emergencyDatabase['frostbite'] = EmergencyData(
        id: 'frostbite',
        title: 'Frostbite',
        icon: Icons.ac_unit,
        color: Colors.lightBlue,
        isHighPriority: false,
        description:
            'Warm affected area gradually. Dont rub the area or use direct heat.');
    _emergencyDatabase['sprain'] = EmergencyData(
        id: 'sprain',
        title: 'Sprain or Strain',
        icon: Icons.accessibility_new,
        color: Colors.green.shade700,
        isHighPriority: false,
        description:
            'Rest, ice, compression, and elevation. Seek medical help if severe.');
    _emergencyDatabase['snake_bite'] = EmergencyData(
        id: 'snake_bite',
        title: 'Snake Bite',
        icon: Icons.pest_control,
        color: Colors.brown,
        isHighPriority: false,
        description:
            'Keep victim calm and immobile. Dont cut or suck the wound. Seek medical help.');
    _emergencyDatabase['eye_injury'] = EmergencyData(
        id: 'eye_injury',
        title: 'Eye Injury',
        icon: Icons.visibility,
        color: Colors.cyan.shade700,
        isHighPriority: false,
        description:
            'Dont touch, rub, or apply pressure. Seek immediate medical attention.');
  }

  // Tries to get the current location and determines the country code to set emergency numbers.
  Future<void> _getLocationAndNumbers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });
    try {
      final locationString = await _locationService.getCurrentLocation();
      if (!mounted) return;

      // Update UI based on location result (permission denied, error, or success).
      if (locationString.contains("Location access denied")) {
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
          _countryCode = "DEFAULT"; // Fallback country
          _updateEmergencyNumbers();
        });
      } else if (locationString.startsWith("Unable") ||
          locationString.startsWith("Could not")) {
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _countryCode = "DEFAULT";
          _updateEmergencyNumbers();
        });
      } else {
        // If location found, try to guess country and update numbers.
        final determinedCountryCode =
            await _determineCountryFromLocation(locationString);
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _countryCode = determinedCountryCode;
          _updateEmergencyNumbers();
        });
      }
    } catch (e) {
      // Handle errors during location fetching.
      debugPrint("Error in _getLocationAndNumbers: $e");
      if (mounted) {
        setState(() {
          _locationInfo = "Location Error";
          _isLoadingLocation = false;
          _countryCode = "DEFAULT";
          _updateEmergencyNumbers(); // Still update numbers to default on error
        });
      }
    }
  }

  // Simple heuristic to guess country code from location string (needs improvement for reliability).
  Future<String> _determineCountryFromLocation(String location) async {
    // This is very basic! A real app might use reverse geocoding API for accuracy.
    String locLower = location.toLowerCase();
    if (locLower.contains("usa") || locLower.contains("united states"))
      return "US";
    if (locLower.contains("uk") || locLower.contains("united kingdom"))
      return "UK";
    if (locLower.contains("india")) return "IN";
    if (locLower.contains("australia")) return "AU";
    if (locLower.contains("canada")) return "CA";
    return "DEFAULT"; // Fallback if country isn't easily identified
  }

  // Updates the displayed emergency number based on the determined country code and selected service.
  void _updateEmergencyNumbers() {
    Map<String, String> countryNumbers =
        _emergencyNumbers[_countryCode] ?? _emergencyNumbers["DEFAULT"]!;
    setState(() {
      // Set the active number based on selected service, fallback to 'general', then hardcoded '112'.
      _activeEmergencyNumber = countryNumbers[_selectedEmergencyService] ??
          countryNumbers["general"] ??
          "112";
    });
  }

  // Shows the bottom sheet asking if the assessment is for "Me" or "Someone Else".
  void _showDistressPersonDialog(String emergencyType) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Get AI First Response for:",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
                _emergencyDatabase[emergencyType]?.title ??
                    'Selected Emergency',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),
            Text("Who needs assistance?",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: _buildDistressPersonOption(
                        context: context,
                        title: "Me",
                        icon: Icons.person_outline,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAssessment(emergencyType, isSelf: true);
                        })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildDistressPersonOption(
                        context: context,
                        title: "Someone Else",
                        icon: Icons.people_outline,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAssessment(emergencyType, isSelf: false);
                        })),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper widget for the "Me" / "Someone Else" options in the bottom sheet.
  Widget _buildDistressPersonOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // Navigates to the assessment page, passing the emergency type, self/other flag, and location.
  void _navigateToAssessment(String emergencyType, {required bool isSelf}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyAssessmentPage(
          emergencyType: emergencyType,
          isSelf: isSelf,
          locationInfo: _locationInfo,
        ),
      ),
    );
  }

  // Shows a dialog allowing the user to select which emergency service number to display/call.
  void _showEmergencyServiceDialog() {
    final Map<String, String> services =
        _emergencyNumbers[_countryCode] ?? _emergencyNumbers["DEFAULT"]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Emergency Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: services.entries.map((entry) {
              // Format the service key (e.g., 'non_urgent') into a user-friendly title ("Non Urgent").
              String serviceTitle = entry.key
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((word) =>
                      '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
                  .join(' ');
              return RadioListTile<String>(
                title: Text(serviceTitle),
                subtitle: Text(entry.value), // Show the actual number.
                value: entry.key,
                groupValue: _selectedEmergencyService,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedEmergencyService = value;
                    });
                    _updateEmergencyNumbers(); // Update the displayed number based on selection.
                    Navigator.pop(context); // Close the dialog.
                  }
                },
                secondary: _getEmergencyServiceIcon(
                    entry.key), // Show an appropriate icon.
                activeColor: Theme.of(context).colorScheme.primary,
                selected: _selectedEmergencyService == entry.key,
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'))
        ],
      ),
    );
  }

  // Returns an icon based on the emergency service key.
  Icon _getEmergencyServiceIcon(String serviceKey) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (serviceKey) {
      case 'general':
        return Icon(Icons.local_hospital_outlined, color: colorScheme.error);
      case 'ambulance':
        return Icon(Icons.emergency_outlined, color: Colors.green.shade600);
      case 'non_urgent':
        return Icon(Icons.medical_services_outlined,
            color: Colors.teal.shade600);
      default:
        return Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  // Initiates the phone call using url_launcher after confirmation.
  Future<void> _callEmergency() async {
    HapticFeedback.heavyImpact();
    final Uri phoneUri = Uri(scheme: 'tel', path: _activeEmergencyNumber);

    // Check if the device can actually make calls before showing dialog.
    if (!await canLaunchUrl(phoneUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Cannot make calls from this device to $_activeEmergencyNumber'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
      return;
    }

    // Show confirmation dialog.
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [
            Icon(Icons.call_outlined, color: Colors.red.shade700),
            const SizedBox(width: 10),
            const Text('Confirm Emergency Call')
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                  text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge,
                children: <TextSpan>[
                  const TextSpan(
                      text: 'You are about to call the emergency number: '),
                  TextSpan(
                      text: _activeEmergencyNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const TextSpan(
                      text:
                          '.\n\nOnly proceed if this is a genuine emergency.'),
                ],
              )),
              const SizedBox(height: 12), const Divider(),
              const SizedBox(height: 12),
              const Text('Current Location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              // Inform user if location is unavailable so they can state it verbally.
              Text(_locationInfo.contains("denied") ||
                      _locationInfo.contains("Unable")
                  ? "Location unavailable - please state verbally."
                  : _locationInfo),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL')),
            ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('CALL NOW'),
              onPressed: () async {
                Navigator.pop(context); // Close dialog first.
                try {
                  await launchUrl(phoneUri);
                } // Launch the call.
                catch (e) {
                  debugPrint("Error launching call URL: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error launching call: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
  }

  // Opens the current location (if available) in a map app.
  Future<void> _showMapLocation() async {
    HapticFeedback.lightImpact();
    try {
      final result = await _locationService.openLocationInMap();
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map application.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  @override
  void dispose() {
    // Clean up timers and controllers.
    _animationController.dispose();
    _pulseTimer?.cancel();
    _refreshLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool flashState =
        (_pulseTimer?.tick ?? 0) % 2 == 0; // Used for flashing effect.
    // Format the selected service name for display.
    String emergencyServiceName = _selectedEmergencyService
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Care'),
        elevation: 1.0,
        backgroundColor:
            Theme.of(context).colorScheme.error, // Red app bar for urgency.
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      drawer: const DrawerMenu(currentRoute: '/emergency'),
      body: Column(
        children: [
          // The prominent red bar at the top for calling services.
          _buildEmergencyCallBar(flashState, emergencyServiceName),
          // The scrollable list of emergency situation tiles.
          Expanded(child: _buildEmergencyList()),
        ],
      ),
    );
  }

  // Builds the top red bar with the pulsing icon, number, call button, and location.
  Widget _buildEmergencyCallBar(bool flashState, String serviceName) {
    final theme = Theme.of(context);
    return Container(
      // Styling for the call bar.
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              flashState
                  ? theme.colorScheme.error.withOpacity(0.8)
                  : theme.colorScheme.error,
              theme.colorScheme.error.withOpacity(0.9)
            ]),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
      child: Column(children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pulsing icon container.
            ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.onError,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: theme.colorScheme.error.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 3)
                      ]),
                  child: Icon(Icons.call_outlined,
                      color: theme.colorScheme.error, size: 36),
                )),
            const SizedBox(width: 16),
            // Service name (dropdown) and number.
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  // Allows tapping the service name to change it.
                  onTap: _showEmergencyServiceDialog,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(serviceName,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onError)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down,
                              color: theme.colorScheme.onError.withOpacity(0.7),
                              size: 20),
                        ],
                      )),
                ),
                // The actual emergency number.
                Text(_activeEmergencyNumber,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onError,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(blurRadius: 1, color: Colors.black38)
                        ])),
              ],
            )),
          ],
        ),
        const SizedBox(height: 20),
        // The main "CALL" button.
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('CALL EMERGENCY SERVICES'),
              onPressed: _callEmergency,
              style: ElevatedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  backgroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 4),
            )),
        const SizedBox(height: 16),
        // Location display area.
        GestureDetector(
          // Allow tapping location to open map (if available).
          onTap: _isLoadingLocation || _locationPermissionDenied
              ? null
              : _showMapLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
                color: theme.colorScheme.onError.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(
                    _locationPermissionDenied
                        ? Icons.location_disabled_outlined
                        : Icons.location_on_outlined,
                    color: _locationPermissionDenied
                        ? Colors.orange.shade300
                        : theme.colorScheme.onError.withOpacity(0.7),
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT LOCATION',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onError.withOpacity(0.8),
                            letterSpacing: 0.5)),
                    Text(
                        _isLoadingLocation
                            ? "Refreshing location..."
                            : _locationInfo,
                        style: TextStyle(
                            fontSize: 13, color: theme.colorScheme.onError),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Show loading indicator or map icon.
                if (_isLoadingLocation)
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.onError.withOpacity(0.7),
                          strokeWidth: 2))
                else if (!_locationPermissionDenied)
                  Icon(Icons.map_outlined,
                      color: theme.colorScheme.onError.withOpacity(0.7),
                      size: 18),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // Builds the scrollable list of emergency situation tiles.
  Widget _buildEmergencyList() {
    final List<EmergencyData> emergencies = _emergencyDatabase.values.toList();
    // Sort emergencies: High priority first, then alphabetically.
    emergencies.sort((a, b) {
      if (a.isHighPriority == b.isHighPriority)
        return a.title.compareTo(b.title);
      return a.isHighPriority ? -1 : 1; // High priority comes first (-1).
    });

    // Group into high and other priorities for sectioning.
    final highPriority = emergencies.where((e) => e.isHighPriority).toList();
    final otherPriority = emergencies.where((e) => !e.isHighPriority).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      children: [
        // Section for high priority emergencies.
        if (highPriority.isNotEmpty) ...[
          _buildPriorityHeader(
              'CRITICAL EMERGENCIES', Theme.of(context).colorScheme.error),
          ...highPriority.map(
              (emergency) => _buildEmergencyTile(emergency)), // Generate tiles
        ],
        // Section for other emergencies.
        if (otherPriority.isNotEmpty) ...[
          SizedBox(
              height: highPriority.isNotEmpty
                  ? 24
                  : 0), // Add spacing if both sections exist.
          _buildPriorityHeader('OTHER COMMON SITUATIONS',
              Theme.of(context).colorScheme.secondary),
          ...otherPriority.map(
              (emergency) => _buildEmergencyTile(emergency)), // Generate tiles
        ],
      ],
    );
  }

  // Helper widget for the section headers (e.g., "CRITICAL EMERGENCIES").
  Widget _buildPriorityHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
      child: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1)),
    );
  }

  // Builds a single tappable tile representing an emergency type.
  Widget _buildEmergencyTile(EmergencyData emergency) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: emergency.isHighPriority
          ? 3
          : 1.5, // Make high priority stand out more.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Add a subtle border for high priority items.
        side: emergency.isHighPriority
            ? BorderSide(
                color: theme.colorScheme.error.withOpacity(0.3), width: 1)
            : BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _showDistressPersonDialog(
            emergency.id), // Show Me/Someone Else dialog on tap.
        borderRadius:
            BorderRadius.circular(12), // Match card shape for ripple effect.
        splashColor: emergency.color.withOpacity(0.1),
        hoverColor: emergency.color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: emergency.color.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: Icon(emergency.icon, color: emergency.color, size: 28),
              ),
              const SizedBox(width: 16),
              // Title and Description
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emergency.title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: emergency.isHighPriority
                              ? theme.colorScheme.error
                              : null)),
                  const SizedBox(height: 4),
                  Text(emergency.description,
                      style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              const SizedBox(width: 8),
              // Forward arrow indicator
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple helper extension for capitalizing words in a string.
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    String processed = replaceAll('_', ' ');
    if (processed.isEmpty) return "";
    return "${processed[0].toUpperCase()}${processed.substring(1).toLowerCase()}";
  }
}
