import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// A model representing detailed information about a medical emergency condition.
class EmergencyCondition {
  /// Unique identifier for the emergency condition.
  final String id;

  /// Title summarizing the emergency condition.
  final String title;

  /// Detailed description explaining the condition.
  final String description;

  /// Severity level indicating urgency (e.g., 'high', 'medium', 'low').
  final String severity;

  /// Common symptoms associated with the condition.
  final List<String> symptoms;

  /// Recommended actions to take when the condition occurs.
  final List<String> dos;

  /// Actions to avoid to prevent further harm.
  final List<String> donts;

  /// Questions designed to assess the severity of the condition.
  final List<Map<String, dynamic>> assessmentQuestions;

  /// Immediate steps required in urgent situations.
  final List<String> urgentActions;

  EmergencyCondition({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.symptoms,
    required this.dos,
    required this.donts,
    required this.assessmentQuestions,
    required this.urgentActions,
  });

  /// Constructs an instance from a JSON map, using default values for missing fields.
  factory EmergencyCondition.fromJson(Map<String, dynamic> json) {
    return EmergencyCondition(
      id: json['id'] ?? 'unknown_id',
      title: json['title'] ?? 'Unknown Title',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'medium',
      symptoms:
          json['symptoms'] != null ? List<String>.from(json['symptoms']) : [],
      dos: json['dos'] != null ? List<String>.from(json['dos']) : [],
      donts: json['donts'] != null ? List<String>.from(json['donts']) : [],
      assessmentQuestions: json['assessment_questions'] != null
          ? List<Map<String, dynamic>>.from(json['assessment_questions'])
          : [],
      urgentActions: json['urgent_actions'] != null
          ? List<String>.from(json['urgent_actions'])
          : [],
    );
  }
}

/// Singleton service that loads and provides access to medical emergency data.
class MedicalKnowledgeService {
  // Private constructor for singleton pattern.
  MedicalKnowledgeService._internal();
  static final MedicalKnowledgeService _instance =
      MedicalKnowledgeService._internal();

  /// Factory constructor to return the singleton instance.
  factory MedicalKnowledgeService() => _instance;

  /// Internal storage for emergency conditions keyed by their IDs.
  Map<String, EmergencyCondition> _emergencyConditions = {};
  bool _isInitialized = false;

  /// Loads emergency data from JSON asset, initializing the service once.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final String data =
          await rootBundle.loadString('assets/data/emergencies.json');
      final Map<String, dynamic> jsonData = json.decode(data);
      final List<dynamic> emergencies = jsonData['emergencies'] ?? [];

      for (final emergency in emergencies) {
        if (emergency is Map<String, dynamic>) {
          final condition = EmergencyCondition.fromJson(emergency);
          _emergencyConditions[condition.id] = condition;
        }
      }

      _isInitialized = true;
      debugPrint(
          'Medical Knowledge Service initialized with ${_emergencyConditions.length} conditions');
    } catch (e) {
      debugPrint('Error initializing Medical Knowledge Service: $e');
      _createFallbackDataset();
    }
  }

  /// Creates a minimal fallback dataset if JSON loading fails.
  void _createFallbackDataset() {
    _emergencyConditions = {
      'heart_attack': EmergencyCondition(
        id: 'heart_attack',
        title: 'Heart Attack',
        description:
            'A heart attack occurs when blood flow to part of the heart is blocked.',
        severity: 'high',
        symptoms: ['Chest pain', 'Shortness of breath', 'Sweating', 'Nausea'],
        dos: [
          'Call emergency services immediately',
          'Stay calm',
          'Take aspirin if not allergic'
        ],
        donts: ['Don\'t leave the person alone', 'Don\'t delay seeking help'],
        assessmentQuestions: [],
        urgentActions: [
          'Call emergency services immediately',
          'Help the person sit comfortably'
        ],
      ),
      'stroke': EmergencyCondition(
        id: 'stroke',
        title: 'Stroke',
        description:
            'A stroke occurs when blood supply to part of the brain is interrupted.',
        severity: 'high',
        symptoms: [
          'Sudden numbness',
          'Confusion',
          'Trouble speaking',
          'Severe headache'
        ],
        dos: [
          'Call emergency services immediately',
          'Note when symptoms started'
        ],
        donts: ['Don\'t give food or drink', 'Don\'t delay medical attention'],
        assessmentQuestions: [],
        urgentActions: ['Call emergency services immediately'],
      ),
    };
    _isInitialized = true;
    debugPrint(
        'Created fallback medical knowledge dataset with ${_emergencyConditions.length} conditions');
  }

  /// Returns a list of all loaded emergency conditions.
  List<EmergencyCondition> getAllEmergencyConditions() =>
      _emergencyConditions.values.toList();

  /// Filters emergency conditions by severity level.
  List<EmergencyCondition> getEmergencyConditionsBySeverity(String severity) =>
      _emergencyConditions.values
          .where((c) => c.severity.toLowerCase() == severity.toLowerCase())
          .toList();

  /// Convenience method to get only high severity emergencies.
  List<EmergencyCondition> getHighPriorityEmergencies() =>
      getEmergencyConditionsBySeverity('high');

  /// Retrieves a specific emergency condition by its ID.
  EmergencyCondition? getEmergencyCondition(String id) =>
      _emergencyConditions[id];

  /// Returns assessment questions for a given emergency ID, or empty if not found.
  List<Map<String, dynamic>> getAssessmentQuestions(String emergencyId) =>
      _emergencyConditions[emergencyId]?.assessmentQuestions ?? [];

  /// Provides actions to do and not do for an emergency ID.
  Map<String, List<String>> getEmergencyActions(String emergencyId) {
    final condition = _emergencyConditions[emergencyId];
    return {
      'dos': condition?.dos ?? [],
      'donts': condition?.donts ?? [],
    };
  }

  /// Lists urgent actions for a specific emergency ID.
  List<String> getUrgentActions(String emergencyId) =>
      _emergencyConditions[emergencyId]?.urgentActions ?? [];

  /// Searches conditions by title, description, or symptoms matching the query.
  List<EmergencyCondition> searchEmergencyConditions(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _emergencyConditions.values.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.symptoms.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  /// Provides UI-related info (title, description, color, icon) based on severity.
  Map<String, dynamic> getSeverityInfo(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return {
          'title': 'High Severity',
          'description': 'Requires immediate medical attention',
          'color': 0xFFFF0000,
          'icon': 'warning'
        };
      case 'medium':
        return {
          'title': 'Medium Severity',
          'description': 'May require prompt medical attention',
          'color': 0xFFFF9800,
          'icon': 'warning_amber'
        };
      case 'low':
        return {
          'title': 'Low Severity',
          'description': 'May be manageable with home care',
          'color': 0xFF4CAF50,
          'icon': 'info'
        };
      default:
        return {
          'title': 'Unknown Severity',
          'description': 'Consult a healthcare professional',
          'color': 0xFF9E9E9E,
          'icon': 'help'
        };
    }
  }
}
