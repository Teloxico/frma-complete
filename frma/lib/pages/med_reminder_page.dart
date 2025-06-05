// lib/pages/med_reminder_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../providers/profile_provider.dart';
import '../widgets/drawer_menu.dart';

// Medication reminder model without notification functionality
class MedicationReminder {
  final int id;
  final String medicationName;
  TimeOfDay reminderTime;
  List<bool> daysOfWeek;
  bool isActive;
  String dosage;
  String notes;

  MedicationReminder({
    required this.id,
    required this.medicationName,
    required this.reminderTime,
    required this.daysOfWeek,
    required this.dosage,
    this.notes = '',
    this.isActive = true,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationName': medicationName,
      'reminderTimeHour': reminderTime.hour,
      'reminderTimeMinute': reminderTime.minute,
      'daysOfWeek': daysOfWeek,
      'isActive': isActive,
      'dosage': dosage,
      'notes': notes,
    };
  }

  // Create from JSON
  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'],
      medicationName: json['medicationName'],
      reminderTime: TimeOfDay(
        hour: json['reminderTimeHour'],
        minute: json['reminderTimeMinute'],
      ),
      daysOfWeek: List<bool>.from(json['daysOfWeek']),
      isActive: json['isActive'],
      dosage: json['dosage'],
      notes: json['notes'] ?? '',
    );
  }
}

class MedicationReminderPage extends StatefulWidget {
  const MedicationReminderPage({Key? key}) : super(key: key);

  @override
  State<MedicationReminderPage> createState() => _MedicationReminderPageState();
}

class _MedicationReminderPageState extends State<MedicationReminderPage>
    with SingleTickerProviderStateMixin {
  final List<MedicationReminder> _reminders = [];
  int _nextId = 0;

  // Tab controller - properly initialized for TabBar
  late TabController _tabController;

  // Active tab
  int _activeTabIndex = 0;

  // Filter tabs
  final List<String> _tabLabels = ['All', 'Today', 'Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with proper length
    _tabController = TabController(length: _tabLabels.length, vsync: this);

    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });

    _loadReminders();
    _populateRemindersFromProfile();
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose controller when done
    super.dispose();
  }

  // Load saved reminders from SharedPreferences
  Future<void> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedReminders = prefs.getStringList('medication_reminders');
      if (savedReminders != null) {
        setState(() {
          _reminders.clear();
          for (var reminderJson in savedReminders) {
            final reminderData = jsonDecode(reminderJson);
            _reminders.add(MedicationReminder.fromJson(reminderData));
          }

          // Find the next available ID
          if (_reminders.isNotEmpty) {
            _nextId =
                _reminders.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
          }
        });
        _sortReminders();
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
    }
  }

  // Save reminders to SharedPreferences
  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersList =
          _reminders.map((reminder) => jsonEncode(reminder.toJson())).toList();
      await prefs.setStringList('medication_reminders', remindersList);
    } catch (e) {
      debugPrint('Error saving reminders: $e');
    }
  }

  // Populate reminders from profile
  void _populateRemindersFromProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);

      // Add reminders for each medication in profile if no reminders exist yet
      if (_reminders.isEmpty && profileProvider.medications.isNotEmpty) {
        for (var medication in profileProvider.medications) {
          // Extract time information from frequency if possible
          TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);
          List<bool> daysOfWeek = List.filled(7, true); // Default to every day

          // Try to parse frequency for time or days
          if (medication.frequency.contains("morning")) {
            reminderTime = const TimeOfDay(hour: 8, minute: 0);
          } else if (medication.frequency.contains("evening")) {
            reminderTime = const TimeOfDay(hour: 19, minute: 0);
          } else if (medication.frequency.contains("night")) {
            reminderTime = const TimeOfDay(hour: 21, minute: 0);
          }

          // Create a reminder
          _addReminder(
            medicationName: medication.name,
            reminderTime: reminderTime,
            daysOfWeek: daysOfWeek,
            dosage: medication.dosage,
            notes: "Frequency: ${medication.frequency}",
          );
        }
      }
    });
  }

  // Add a new reminder
  void _addReminder({
    required String medicationName,
    required TimeOfDay reminderTime,
    required List<bool> daysOfWeek,
    required String dosage,
    String notes = '',
  }) async {
    final reminder = MedicationReminder(
      id: _nextId++,
      medicationName: medicationName,
      reminderTime: reminderTime,
      daysOfWeek: daysOfWeek,
      dosage: dosage,
      notes: notes,
    );

    setState(() {
      _reminders.add(reminder);
      _sortReminders();
    });

    // Add to profile if it doesn't exist there
    await _syncReminderWithProfile(reminder);

    // Save to persistent storage
    await _saveReminders();
  }

  // Sync a reminder with the profile medications
  Future<void> _syncReminderWithProfile(MedicationReminder reminder) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Check if medication exists in profile
    bool exists = profileProvider.medications.any(
        (m) => m.name.toLowerCase() == reminder.medicationName.toLowerCase());

    if (!exists) {
      // Add to profile
      profileProvider.addMedication(
        Medication(
          name: reminder.medicationName,
          dosage: reminder.dosage,
          frequency: reminder.notes.isNotEmpty
              ? reminder.notes
              : _formatReminderFrequency(reminder),
        ),
      );
    }
  }

  // Format days of week for frequency text
  String _formatReminderFrequency(MedicationReminder reminder) {
    String timeStr = '${reminder.reminderTime.format(context)}';

    // Format days
    final days = <String>[];
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    for (int i = 0; i < reminder.daysOfWeek.length; i++) {
      if (reminder.daysOfWeek[i]) {
        days.add(dayNames[i]);
      }
    }

    String daysStr = '';
    if (days.length == 7) {
      daysStr = 'daily';
    } else if (days.isEmpty) {
      daysStr = 'never';
    } else if (days.length == 5 &&
        reminder.daysOfWeek[1] &&
        reminder.daysOfWeek[2] &&
        reminder.daysOfWeek[3] &&
        reminder.daysOfWeek[4] &&
        reminder.daysOfWeek[5]) {
      daysStr = 'weekdays';
    } else if (days.length == 2 &&
        reminder.daysOfWeek[0] &&
        reminder.daysOfWeek[6]) {
      daysStr = 'weekends';
    } else {
      daysStr = days.join(', ');
    }

    return '$timeStr, $daysStr';
  }

  // Delete a reminder
  void _deleteReminder(int id) async {
    final index = _reminders.indexWhere((reminder) => reminder.id == id);
    if (index != -1) {
      final reminder = _reminders[index];

      setState(() {
        _reminders.removeAt(index);
      });

      // Save changes
      await _saveReminders();

      // Show undo option
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${reminder.medicationName}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _reminders.insert(index, reminder);
                _sortReminders();
              });
              await _saveReminders();
            },
          ),
        ),
      );
    }
  }

  // Toggle reminder active status
  void _toggleReminderStatus(int id) async {
    final index = _reminders.indexWhere((reminder) => reminder.id == id);
    if (index != -1) {
      final reminder = _reminders[index];

      setState(() {
        reminder.isActive = !reminder.isActive;
      });

      // Save changes
      await _saveReminders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Reminder for ${reminder.medicationName} ${reminder.isActive ? "activated" : "deactivated"}')),
      );
    }
  }

  // Sort reminders by time
  void _sortReminders() {
    _reminders.sort((a, b) {
      // First by time
      int timeCompare = (a.reminderTime.hour * 60 + a.reminderTime.minute)
          .compareTo(b.reminderTime.hour * 60 + b.reminderTime.minute);

      if (timeCompare != 0) return timeCompare;

      // Then by name
      return a.medicationName.compareTo(b.medicationName);
    });
  }

  // Check if a reminder is scheduled for today
  bool _isScheduledForToday(MedicationReminder reminder) {
    int today = DateTime.now().weekday;
    // Convert from DateTime.weekday (1=Monday) to our array (0=Sunday)
    today = today == 7 ? 0 : today;
    return reminder.daysOfWeek[today];
  }

  // Get filtered reminders based on active tab
  List<MedicationReminder> _getFilteredReminders() {
    switch (_activeTabIndex) {
      case 0: // All
        return _reminders;
      case 1: // Today
        return _reminders.where((r) => _isScheduledForToday(r)).toList();
      case 2: // Active
        return _reminders.where((r) => r.isActive).toList();
      case 3: // Inactive
        return _reminders.where((r) => !r.isActive).toList();
      default:
        return _reminders;
    }
  }

  // Show add reminder dialog
  void _showAddReminderDialog() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Check if profile has medications
    if (profileProvider.medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add medications to your profile first'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show dialog to add new reminder
    _showReminderDialog(
      title: 'Add Medication Reminder',
      onSave: (String medicationName, TimeOfDay time, List<bool> days,
          String dosage, String notes) {
        _addReminder(
          medicationName: medicationName,
          reminderTime: time,
          daysOfWeek: days,
          dosage: dosage,
          notes: notes,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder for $medicationName added')),
        );
      },
    );
  }

  // Show dialog to edit a reminder
  void _showEditReminderDialog(MedicationReminder reminder) {
    _showReminderDialog(
      title: 'Edit Medication Reminder',
      initialMedication: reminder.medicationName,
      initialTime: reminder.reminderTime,
      initialDays: reminder.daysOfWeek,
      initialDosage: reminder.dosage,
      initialNotes: reminder.notes,
      onSave: (String medicationName, TimeOfDay time, List<bool> days,
          String dosage, String notes) async {
        setState(() {
          reminder.reminderTime = time;
          reminder.daysOfWeek = days;
          reminder.dosage = dosage;
          reminder.notes = notes;
        });

        // Save changes
        await _saveReminders();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Reminder for ${reminder.medicationName} updated')),
        );
      },
    );
  }

  // Show medication detail dialog
  void _showMedicationDetail(int id) {
    final reminder = _reminders.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Reminder not found'),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reminder.medicationName),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Time'),
              subtitle: Text(reminder.reminderTime.format(context)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Days'),
              subtitle: Text(_formatDays(reminder.daysOfWeek)),
            ),
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: const Text('Dosage'),
              subtitle: Text(reminder.dosage),
            ),
            if (reminder.notes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.note),
                title: const Text('Notes'),
                subtitle: Text(reminder.notes),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditReminderDialog(reminder);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  // Generic reminder dialog for adding/editing
  void _showReminderDialog({
    required String title,
    String? initialMedication,
    TimeOfDay? initialTime,
    List<bool>? initialDays,
    String? initialDosage,
    String? initialNotes,
    required Function(String medication, TimeOfDay time, List<bool> days,
            String dosage, String notes)
        onSave,
  }) {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Set default values
    String selectedMedication =
        initialMedication ?? profileProvider.medications.first.name;
    TimeOfDay selectedTime = initialTime ?? TimeOfDay.now();
    List<bool> selectedDays = initialDays ?? List.filled(7, true);
    final dosageController = TextEditingController(text: initialDosage ?? '');
    final notesController = TextEditingController(text: initialNotes ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medication selection dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Medication',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMedication,
                  items: profileProvider.medications.map((medication) {
                    return DropdownMenuItem<String>(
                      value: medication.name,
                      child: Text(medication.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedMedication = value;

                        // Update dosage from profile
                        final med = profileProvider.medications.firstWhere(
                          (m) => m.name == value,
                          orElse: () => throw Exception('Medication not found'),
                        );
                        dosageController.text = med.dosage;
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Dosage field
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 1 tablet',
                  ),
                ),

                const SizedBox(height: 16),

                // Time picker button
                ListTile(
                  title: const Text('Reminder Time'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        selectedTime = pickedTime;
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Days of week selection
                const Text(
                  'Repeat on:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    _buildDayChip(setState, selectedDays, 0, 'Sun'),
                    _buildDayChip(setState, selectedDays, 1, 'Mon'),
                    _buildDayChip(setState, selectedDays, 2, 'Tue'),
                    _buildDayChip(setState, selectedDays, 3, 'Wed'),
                    _buildDayChip(setState, selectedDays, 4, 'Thu'),
                    _buildDayChip(setState, selectedDays, 5, 'Fri'),
                    _buildDayChip(setState, selectedDays, 6, 'Sat'),
                  ],
                ),

                const SizedBox(height: 16),

                // Notes field
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Special instructions',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dosageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a dosage')),
                  );
                  return;
                }

                onSave(
                  selectedMedication,
                  selectedTime,
                  selectedDays,
                  dosageController.text,
                  notesController.text,
                );

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Build day selection chip
  Widget _buildDayChip(StateSetter setState, List<bool> selectedDays,
      int dayIndex, String label) {
    return FilterChip(
      label: Text(label),
      selected: selectedDays[dayIndex],
      onSelected: (selected) {
        setState(() {
          selectedDays[dayIndex] = selected;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReminders = _getFilteredReminders();
    final bool hasNoMedications =
        Provider.of<ProfileProvider>(context).medications.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        bottom: TabBar(
          controller: _tabController, // Connect the controller to the TabBar
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      drawer: const DrawerMenu(currentRoute: '/medications'),
      body: hasNoMedications
          ? _buildNoMedicationsView()
          : filteredReminders.isEmpty
              ? _buildEmptyState(_tabLabels[_activeTabIndex])
              : _buildRemindersList(filteredReminders),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add),
      ),
    );
  }

  // No medications view
  Widget _buildNoMedicationsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No medications in your profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add medications to your profile first',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person),
            label: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  // Empty state when no reminders exist
  Widget _buildEmptyState(String tabName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No $tabName reminders',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to set up reminders',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddReminderDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Reminder'),
          ),
        ],
      ),
    );
  }

  // List of medication reminders
  Widget _buildRemindersList(List<MedicationReminder> reminders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        final bool isScheduledToday = _isScheduledForToday(reminder);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Dismissible(
            key: Key('reminder_${reminder.id}'),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _deleteReminder(reminder.id),
            child: InkWell(
              onTap: () => _showMedicationDetail(reminder.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: reminder.isActive
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.medication,
                        color: reminder.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reminder.medicationName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        reminder.isActive ? null : Colors.grey,
                                  ),
                                ),
                              ),
                              if (isScheduledToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: reminder.isActive
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: reminder.isActive
                                          ? Colors.green.shade800
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reminder.dosage,
                            style: TextStyle(
                              color: reminder.isActive ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reminder.reminderTime.format(context),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.event,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDays(reminder.daysOfWeek),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: reminder.isActive,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        _toggleReminderStatus(reminder.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Format days of week for display
  String _formatDays(List<bool> days) {
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDays = <String>[];

    for (int i = 0; i < days.length; i++) {
      if (days[i]) {
        selectedDays.add(dayNames[i]);
      }
    }

    if (selectedDays.length == 7) {
      return 'Every day';
    } else if (selectedDays.isEmpty) {
      return 'Never';
    } else if (selectedDays.length == 5 &&
        days[1] &&
        days[2] &&
        days[3] &&
        days[4] &&
        days[5]) {
      return 'Weekdays';
    } else if (selectedDays.length == 2 && days[0] && days[6]) {
      return 'Weekends';
    } else {
      return selectedDays.join(', ');
    }
  }
}
