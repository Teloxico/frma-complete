import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Data model for a selectable medical condition in the user's profile.
class MedicalCondition {
  final String name;
  bool selected;

  MedicalCondition({required this.name, this.selected = false});

  Map<String, dynamic> toJson() => {'name': name, 'selected': selected};

  factory MedicalCondition.fromJson(Map<String, dynamic> json) =>
      MedicalCondition(
        name: json['name'] ?? 'Unknown Condition',
        selected: json['selected'] ?? false,
      );
}

// Data model for a medication entry, including dosage and frequency.
class Medication {
  final String name;
  final String dosage;
  final String frequency;

  Medication(
      {required this.name, required this.dosage, required this.frequency});

  Map<String, dynamic> toJson() =>
      {'name': name, 'dosage': dosage, 'frequency': frequency};

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        name: json['name'] ?? 'Unknown Medication',
        dosage: json['dosage'] ?? '',
        frequency: json['frequency'] ?? '',
      );
}

// Data model for an emergency contact, with name, relationship, and phone.
class EmergencyContact {
  final String name;
  final String relationship;
  final String phoneNumber;

  EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phoneNumber': phoneNumber,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] ?? 'Unknown Contact',
        relationship: json['relationship'] ?? '',
        phoneNumber: json['phoneNumber'] ?? '',
      );
}

// Provider managing user profile state and persistence.
class ProfileProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  // Profile fields
  String _name = '';
  DateTime? _dateOfBirth;
  String _gender = '';
  double _weight = 0.0;
  double _height = 0.0;
  String _bloodType = '';
  List<MedicalCondition> _medicalConditions = [];
  List<String> _allergies = [];
  List<Medication> _medications = [];
  List<EmergencyContact> _emergencyContacts = [];

  // Preference keys
  static const String _keyPrefix = 'profile_';
  static const String _keyName = '${_keyPrefix}name';
  static const String _keyDob = '${_keyPrefix}dob';
  static const String _keyGender = '${_keyPrefix}gender';
  static const String _keyWeight = '${_keyPrefix}weight';
  static const String _keyHeight = '${_keyPrefix}height';
  static const String _keyBloodType = '${_keyPrefix}blood_type';
  static const String _keyMedicalConditions = '${_keyPrefix}medical_conditions';
  static const String _keyAllergies = '${_keyPrefix}allergies';
  static const String _keyMedications = '${_keyPrefix}medications';
  static const String _keyEmergencyContacts = '${_keyPrefix}emergency_contacts';

  // Default list of common medical conditions
  static const List<String> _defaultConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Allergies',
    'Arthritis',
    'Cancer',
    'COPD',
    'Depression',
    'Epilepsy',
    'Glaucoma',
    'HIV/AIDS',
    'Kidney Disease',
    'Liver Disease',
    'Migraine',
    'Multiple Sclerosis',
    'Osteoporosis',
    "Parkinson's Disease",
    'Thyroid Disorder'
  ];

  ProfileProvider(this.prefs) {
    _loadProfile(); // Initialize state from storage
  }

  // Public getters for profile fields
  String get name => _name;
  DateTime? get dateOfBirth => _dateOfBirth;
  String get gender => _gender;
  double get weight => _weight;
  double get height => _height;
  String get bloodType => _bloodType;
  List<MedicalCondition> get medicalConditions =>
      List.unmodifiable(_medicalConditions);
  List<String> get allergies => List.unmodifiable(_allergies);
  List<Medication> get medications => List.unmodifiable(_medications);
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);

  // Computed property: age in years
  int? get age {
    if (_dateOfBirth == null) return null;
    final today = DateTime.now();
    int years = today.year - _dateOfBirth!.year;
    if (today.month < _dateOfBirth!.month ||
        (today.month == _dateOfBirth!.month && today.day < _dateOfBirth!.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  // Computed property: BMI (kg/m²)
  double? get bmi {
    if (_weight <= 0 || _height <= 0) return null;
    final m = _height / 100;
    return m > 0 ? _weight / (m * m) : null;
  }

  // BMI category based on standard ranges
  String get bmiCategory {
    final b = bmi;
    if (b == null) return 'Unknown';
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }

  // Load profile data from shared preferences
  void _loadProfile() {
    try {
      _name = prefs.getString(_keyName) ?? '';
      final dobStr = prefs.getString(_keyDob);
      _dateOfBirth = dobStr != null ? DateTime.tryParse(dobStr) : null;
      _gender = prefs.getString(_keyGender) ?? '';
      _weight = prefs.getDouble(_keyWeight) ?? 0.0;
      _height = prefs.getDouble(_keyHeight) ?? 0.0;
      _bloodType = prefs.getString(_keyBloodType) ?? '';

      _medicalConditions =
          _loadList(_keyMedicalConditions, MedicalCondition.fromJson) ??
              _getDefaultMedicalConditions();
      _allergies = prefs.getStringList(_keyAllergies) ?? [];
      _medications = _loadList(_keyMedications, Medication.fromJson) ?? [];
      _emergencyContacts =
          _loadList(_keyEmergencyContacts, EmergencyContact.fromJson) ?? [];
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      // Reset to defaults on error
      _medicalConditions = _getDefaultMedicalConditions();
      _allergies = [];
      _medications = [];
      _emergencyContacts = [];
    }
  }

  // Generic list loader for items with fromJson factory
  List<T>? _loadList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final data = prefs.getString(key);
    if (data == null) return null;
    try {
      final list = jsonDecode(data);
      if (list is List) {
        return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error decoding $key: $e');
      prefs.remove(key);
    }
    return null;
  }

  // Provide default conditions when none are saved
  List<MedicalCondition> _getDefaultMedicalConditions() =>
      _defaultConditions.map((n) => MedicalCondition(name: n)).toList();

  // Persist the full profile state
  Future<void> _saveProfile() async {
    await prefs.setString(_keyName, _name);
    if (_dateOfBirth != null) {
      await prefs.setString(_keyDob, _dateOfBirth!.toIso8601String());
    } else {
      prefs.remove(_keyDob);
    }
    await prefs.setString(_keyGender, _gender);
    await prefs.setDouble(_keyWeight, _weight);
    await prefs.setDouble(_keyHeight, _height);
    await prefs.setString(_keyBloodType, _bloodType);
    await _saveList(_keyMedicalConditions, _medicalConditions);
    await prefs.setStringList(_keyAllergies, _allergies);
    await _saveList(_keyMedications, _medications);
    await _saveList(_keyEmergencyContacts, _emergencyContacts);
  }

  // Helper to save lists of JSON-serializable items
  Future<void> _saveList<T>(String key, List<T> list) async {
    final jsonList = list
        .map((item) => (item as dynamic).toJson() as Map<String, dynamic>)
        .toList();
    await prefs.setString(key, jsonEncode(jsonList));
  }

  // Central update method: apply change, save, notify
  Future<void> _updateAndSave(VoidCallback update) async {
    update();
    await _saveProfile();
    notifyListeners();
  }

  // --- Public setters for profile fields ---
  Future<void> setName(String v) async =>
      _updateAndSave(() => _name = v.trim());
  Future<void> setDateOfBirth(DateTime? v) async =>
      _updateAndSave(() => _dateOfBirth = v);
  Future<void> setGender(String v) async => _updateAndSave(() => _gender = v);
  Future<void> setWeight(double v) async =>
      _updateAndSave(() => _weight = v >= 0 ? v : 0);
  Future<void> setHeight(double v) async =>
      _updateAndSave(() => _height = v >= 0 ? v : 0);
  Future<void> setBloodType(String v) async =>
      _updateAndSave(() => _bloodType = v);

  // Toggle or update medical conditions
  Future<void> updateMedicalCondition(String name, bool sel) async =>
      _updateAndSave(() {
        final idx = _medicalConditions.indexWhere((c) => c.name == name);
        if (idx != -1) _medicalConditions[idx].selected = sel;
      });
  Future<void> addCustomMedicalCondition(MedicalCondition c) async =>
      _updateAndSave(() {
        final idx = _medicalConditions
            .indexWhere((e) => e.name.toLowerCase() == c.name.toLowerCase());
        if (idx != -1) {
          _medicalConditions[idx].selected = c.selected;
        } else {
          _medicalConditions.add(c);
        }
      });

  // Manage allergies list
  Future<void> addAllergy(String a) async {
    final t = a.trim();
    if (t.isNotEmpty && !_allergies.contains(t)) {
      await _updateAndSave(() => _allergies.add(t));
    }
  }

  Future<void> removeAllergy(String a) async =>
      _updateAndSave(() => _allergies.remove(a));

  // Manage medications list
  Future<void> addMedication(Medication m) async =>
      _updateAndSave(() => _medications.add(m));
  Future<void> removeMedication(int i) async =>
      i >= 0 && i < _medications.length
          ? _updateAndSave(() => _medications.removeAt(i))
          : null;
  Future<void> updateMedication(int i, Medication m) async =>
      i >= 0 && i < _medications.length
          ? _updateAndSave(() => _medications[i] = m)
          : debugPrint('Invalid med index: \$i');

  // Manage emergency contacts list
  Future<void> addEmergencyContact(EmergencyContact c) async =>
      _updateAndSave(() => _emergencyContacts.add(c));
  Future<void> removeEmergencyContact(int i) async =>
      i >= 0 && i < _emergencyContacts.length
          ? _updateAndSave(() => _emergencyContacts.removeAt(i))
          : null;
  Future<void> updateEmergencyContact(int i, EmergencyContact c) async =>
      i >= 0 && i < _emergencyContacts.length
          ? _updateAndSave(() => _emergencyContacts[i] = c)
          : debugPrint('Invalid contact index: \$i');

  /// Clears all profile data and resets to defaults.
  Future<void> clearProfile() async {
    _name = '';
    _dateOfBirth = null;
    _gender = '';
    _weight = 0.0;
    _height = 0.0;
    _bloodType = '';
    _medicalConditions = _getDefaultMedicalConditions();
    _allergies = [];
    _medications = [];
    _emergencyContacts = [];
    await prefs.remove(_keyName);
    await prefs.remove(_keyDob);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyWeight);
    await prefs.remove(_keyHeight);
    await prefs.remove(_keyBloodType);
    await prefs.remove(_keyMedicalConditions);
    await prefs.remove(_keyAllergies);
    await prefs.remove(_keyMedications);
    await prefs.remove(_keyEmergencyContacts);
    notifyListeners();
  }
}
