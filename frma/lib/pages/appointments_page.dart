// lib/pages/appointments_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/drawer_menu.dart';

// Represents a single medical appointment.
class Appointment {
  final int id;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final String notes;
  bool isCompleted;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.notes = '',
    this.isCompleted = false,
  });

  // Converts this Appointment object to a JSON map for storing.
  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorName': doctorName,
        'specialty': specialty,
        'dateTime': dateTime.toIso8601String(), // Store DateTime as ISO string
        'location': location,
        'notes': notes,
        'isCompleted': isCompleted,
      };

  // Creates an Appointment object from a JSON map (e.g., when loading from storage).
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? 0,
      doctorName: json['doctorName'] ?? 'Unknown Doctor',
      specialty: json['specialty'] ?? 'Unknown Specialty',
      dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
      location: json['location'] ?? 'Unknown Location',
      notes: json['notes'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  // Checks if the appointment is within the next 24 hours and not completed.
  bool get isUpcoming {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return !isCompleted &&
        difference.isNegative == false &&
        difference.inHours <= 24;
  }

  // Checks if the appointment date/time is in the past and not completed.
  bool get isPastDue {
    return !isCompleted && dateTime.isBefore(DateTime.now());
  }
}

/// Page widget for managing medical appointments.
class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({Key? key}) : super(key: key);

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  final List<Appointment> _appointments = [];
  int _nextId = 0;
  bool _isLoading = true;
  late TabController _tabController;

  // Form controllers for adding/editing
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _doctorController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Key used for saving/loading appointments in SharedPreferences.
  static const String _appointmentsKey = 'appointments_list';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments(); // Load saved appointments on startup.
  }

  @override
  void dispose() {
    _tabController.dispose();
    _doctorController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Loads the list of appointments from SharedPreferences.
  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? appointmentsJson = prefs.getString(_appointmentsKey);

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(appointmentsJson);
        final loadedAppointments = decodedList
            .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _appointments.clear();
            _appointments.addAll(loadedAppointments);
            // Ensure new appointments get a unique ID higher than any loaded ones.
            _nextId = _appointments.isEmpty
                ? 0
                : _appointments
                        .map((a) => a.id)
                        .reduce((a, b) => a > b ? a : b) +
                    1;
            _sortAppointments();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error loading appointments'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Saves the current list of appointments to SharedPreferences.
  Future<void> _saveAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String appointmentsJson = jsonEncode(
          _appointments.map((appointment) => appointment.toJson()).toList());
      await prefs.setString(_appointmentsKey, appointmentsJson);
    } catch (e) {
      debugPrint('Error saving appointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error saving appointments'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Adds a new appointment to the list and saves.
  void _addAppointment({
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    String notes = '',
  }) {
    final newAppointment = Appointment(
      id: _nextId++, // Assign next available ID.
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      location: location,
      notes: notes,
    );
    setState(() {
      _appointments.add(newAppointment);
      _sortAppointments();
    });
    _saveAppointments();
  }

  // Removes an appointment by ID and saves.
  void _deleteAppointment(int id) {
    setState(() {
      _appointments.removeWhere((appointment) => appointment.id == id);
    });
    _saveAppointments();
  }

  // Toggles the completion status of an appointment and saves.
  void _toggleAppointmentStatus(int id) {
    setState(() {
      final index =
          _appointments.indexWhere((appointment) => appointment.id == id);
      if (index != -1) {
        _appointments[index].isCompleted = !_appointments[index].isCompleted;
        _saveAppointments(); // Save change immediately.
      }
    });
  }

  // Keeps appointments sorted by date.
  void _sortAppointments() {
    _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Displays the dialog for adding a new appointment.
  void _showAddAppointmentDialog() {
    _doctorController.clear();
    _specialtyController.clear();
    _locationController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _doctorController,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (pickedDate != null) {
                      setStateDialog(() {
                        // Use dialog's state setter.
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                        DateFormat('EEE, MMM d, yyyy').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (pickedTime != null) {
                      setStateDialog(() {
                        // Use dialog's state setter.
                        _selectedTime = pickedTime;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(_selectedTime.format(context)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
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
                if (_doctorController.text.isEmpty ||
                    _specialtyController.text.isEmpty ||
                    _locationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please fill in Doctor, Specialty, and Location'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final DateTime appointmentDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );
                _addAppointment(
                  doctorName: _doctorController.text,
                  specialty: _specialtyController.text,
                  dateTime: appointmentDateTime,
                  location: _locationController.text,
                  notes: _notesController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        elevation: 2.0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      drawer: const DrawerMenu(currentRoute: '/appointments'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming appointments tab
                _buildAppointmentsList(
                  _appointments.where((appt) => !appt.isCompleted).toList(),
                  emptyMessage: 'No upcoming appointments',
                  showUndo: true,
                ),
                // Completed appointments tab
                _buildAppointmentsList(
                  _appointments.where((appt) => appt.isCompleted).toList(),
                  emptyMessage: 'No completed appointments',
                  showUndo: true,
                ),
                // All appointments tab
                _buildAppointmentsList(
                  _appointments,
                  emptyMessage: 'No appointments added yet',
                  showUndo: true,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppointmentDialog,
        tooltip: 'Add Appointment',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the list view for displaying appointments.
  Widget _buildAppointmentsList(List<Appointment> appointments,
      {required String emptyMessage, bool showUndo = false}) {
    if (appointments.isEmpty) {
      return Center(
          child: Padding(
        // Added padding for empty state
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Tap the + button to add an appointment',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddAppointmentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Appointment'),
            ),
          ],
        ),
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: appointment.isUpcoming
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          // Allows swipe-to-delete functionality.
          child: Dismissible(
            key: Key('appointment_${appointment.id}'),
            background: Container(
              // Visual cue when swiping.
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction:
                DismissDirection.endToStart, // Only allow swipe left to delete.
            confirmDismiss: (direction) async {
              // Ask for confirmation before deleting.
              return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Deletion'),
                      content: Text(
                          'Delete appointment with ${appointment.doctorName}?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            },
            onDismissed: (direction) {
              // Store data temporarily for potential undo action.
              final deletedAppointment = appointment;
              final originalIndex = _appointments.indexOf(deletedAppointment);

              _deleteAppointment(appointment.id); // Actually delete and save.

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Appointment with ${appointment.doctorName} deleted'),
                  action: showUndo
                      ? SnackBarAction(
                          // Show undo only if enabled for the list.
                          label: 'Undo',
                          onPressed: () {
                            if (originalIndex != -1) {
                              setState(() {
                                _appointments.insert(
                                    originalIndex, deletedAppointment);
                                _sortAppointments();
                              });
                              _saveAppointments(); // Save the restored state.
                            }
                          },
                        )
                      : null,
                ),
              );
            },
            // The actual content of the appointment list item.
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: appointment.isCompleted
                    ? Colors.green
                    : appointment.isPastDue
                        ? Colors.red
                        : appointment.isUpcoming
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                child: Icon(
                    appointment.isCompleted
                        ? Icons.check
                        : Icons.calendar_month,
                    color: Colors.white),
              ),
              title: Text(
                appointment.doctorName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: appointment.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: appointment.isCompleted ? Colors.grey : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(appointment.specialty,
                      style: TextStyle(
                          color: appointment.isCompleted ? Colors.grey : null)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time,
                        size: 16,
                        color: appointment.isCompleted ? Colors.grey : null),
                    const SizedBox(width: 4),
                    Text(
                        DateFormat('E, MMM d, yyyy • h:mm a')
                            .format(appointment.dateTime),
                        style: TextStyle(
                            color:
                                appointment.isCompleted ? Colors.grey : null)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on,
                        size: 16,
                        color: appointment.isCompleted ? Colors.grey : null),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(appointment.location,
                            style: TextStyle(
                                color: appointment.isCompleted
                                    ? Colors.grey
                                    : null))),
                  ]),
                  if (appointment.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note,
                                size: 16,
                                color: appointment.isCompleted
                                    ? Colors.grey
                                    : null),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(appointment.notes,
                                    style: TextStyle(
                                        color: appointment.isCompleted
                                            ? Colors.grey
                                            : null))),
                          ]),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                    appointment.isCompleted
                        ? Icons.refresh
                        : Icons.check_circle_outline,
                    color:
                        appointment.isCompleted ? Colors.green : Colors.grey),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _toggleAppointmentStatus(appointment.id);
                },
                tooltip: appointment.isCompleted
                    ? 'Mark as not completed'
                    : 'Mark as completed',
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }
}
