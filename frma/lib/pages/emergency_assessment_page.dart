// lib/pages/emergency_assessment_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Keep if needed elsewhere, though not used in *this* file
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../models/emergency_assessment_data.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/profile_provider.dart';

/// Guides the user through a series of questions for a specific emergency type.
/// Collects answers and patient info (if applicable) to generate first aid advice.
class EmergencyAssessmentPage extends StatefulWidget {
  final String emergencyType; // ID matching one in emergencies.json
  final bool isSelf; // Is the assessment for the user or someone else?
  final String locationInfo; // Initial location string

  const EmergencyAssessmentPage({
    Key? key,
    required this.emergencyType,
    required this.isSelf,
    required this.locationInfo,
  }) : super(key: key);

  @override
  State<EmergencyAssessmentPage> createState() =>
      _EmergencyAssessmentPageState();
}

class _EmergencyAssessmentPageState extends State<EmergencyAssessmentPage> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  // Holds the configuration (questions, advice) for the current emergency type.
  EmergencyAssessmentData? _assessmentConfig;
  List<EmergencyQuestion> _assessmentQuestions =
      []; // Combined list (patient + assessment)
  List<String> _dos = []; // Advice: Things to do.
  List<String> _donts = []; // Advice: Things not to do.
  String _emergencyDescription = ''; // General description of the emergency.

  // Stores user's answers, keyed by question ID.
  final Map<String, dynamic> _answers = {};
  // Stores patient info gathered if assessment is not for self.
  final Map<String, dynamic> _patientData = {'is_self': false};

  // Controls the flow through the assessment UI.
  int _currentQuestionIndex = 0; // Index within the *current stage*.
  int _assessmentStage =
      0; // 0: intro, 1: patient info, 2: assessment, 3: results
  bool _isLoading = true; // Shows loading indicator when fetching data.
  bool _isSubmitting = false; // Shows indicator when sending to AI.
  bool _showEmergencyCallButton =
      false; // Display call button for high priority cases.

  // Stores the final AI-generated instructions.
  String? _aiInstructions;

  // UI and other state variables
  String _errorMessage = ''; // Displays loading or submission errors.
  String _updatedLocationInfo = ''; // Can be updated in the background.
  double _progressValue = 0.0; // For the progress bar (0.0 to 1.0).

  // Patient Info Form Controllers (only used if !widget.isSelf)
  final _patientNameController = TextEditingController();
  final _patientAgeController = TextEditingController();
  String _patientGender = ''; // State for patient gender radio buttons.
  final _patientConditionsController = TextEditingController();
  final _patientAllergiesController = TextEditingController();
  final _patientMedicationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updatedLocationInfo = widget.locationInfo; // Start with initial location.
    _initializePatientData(); // Set up the patient data map based on isSelf.
    _loadEmergencyData(); // Load questions/advice from JSON.
    _updateLocationInBackground(); // Try to get a more precise location.
  }

  @override
  void dispose() {
    // Dispose controllers to free resources.
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _patientConditionsController.dispose();
    _patientAllergiesController.dispose();
    _patientMedicationsController.dispose();
    super.dispose();
  }

  // Sets initial structure for patient data collection.
  void _initializePatientData() {
    _patientData['is_self'] = widget.isSelf;
    if (!widget.isSelf) {
      _patientData['name'] = '';
      _patientData['age'] = null;
      _patientData['gender'] = '';
      _patientData['medical_conditions'] = '';
      _patientData['allergies'] = '';
      _patientData['medications'] = '';
      _patientGender = ''; // Also reset local UI state for gender
    }
  }

  // Fetches and parses the emergency configuration from the asset JSON file.
  Future<void> _loadEmergencyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Load the whole JSON file content.
      final String jsonString =
          await rootBundle.loadString('assets/data/emergencies.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> emergenciesList = jsonData['emergencies'];

      // Find the specific emergency data based on the ID passed to the widget.
      final emergencyJson = emergenciesList.firstWhere(
          (e) => e['id'] == widget.emergencyType,
          orElse: () => null);

      if (emergencyJson == null) {
        throw Exception('Emergency type "${widget.emergencyType}" not found.');
      }

      // Parse the found JSON into our data models.
      _assessmentConfig = EmergencyAssessmentData.fromJson(emergencyJson);
      _assessmentQuestions = List.from(_assessmentConfig!.questions);
      // If assessing someone else, prepend the patient info questions.
      if (!widget.isSelf) {
        _assessmentQuestions.insertAll(0, _getPatientInfoQuestions());
      }
      _dos = _assessmentConfig!.advice.dos;
      _donts = _assessmentConfig!.advice.donts;
      _emergencyDescription = _assessmentConfig!.advice.description;
      _showEmergencyCallButton = _assessmentConfig!.isHighPriority;

      setState(() {
        _isLoading = false;
        _updateProgressValue(); // Set initial progress.
      });
    } catch (e) {
      debugPrint('Error loading emergency data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load assessment data: ${e.toString()}';
      });
    }
  }

  // Tries to get a more accurate location in the background without blocking the UI.
  Future<void> _updateLocationInBackground() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _updatedLocationInfo = location);
    } catch (e) {
      // Don't show error to user, just log it. Initial location is still available.
      debugPrint("Failed to update location in background: $e");
    }
  }

  // Defines the sequence of questions used to gather patient info.
  List<EmergencyQuestion> _getPatientInfoQuestions() {
    // These are conceptual questions mapped to UI elements later.
    return [
      EmergencyQuestion(
          id: 'patient_info_intro',
          question: 'Patient Information',
          type: 'info',
          content:
              'Please provide basic information about the person needing assistance.'),
      EmergencyQuestion(
          id: 'patient_name',
          question: 'Patient\'s Name (Optional)',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_age', question: 'Approximate Age (Years)', type: 'text'),
      EmergencyQuestion(
          id: 'patient_gender',
          question: 'Gender',
          type: 'multiple_choice',
          options: [
            {'text': 'Male', 'value': 'Male'},
            {'text': 'Female', 'value': 'Female'},
            {'text': 'Other', 'value': 'Other'},
            {'text': 'Unknown', 'value': 'Unknown'}
          ]),
      EmergencyQuestion(
          id: 'patient_conditions',
          question: 'Known Major Medical Conditions (Optional)',
          description: 'e.g., Diabetes, Heart Problems',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_allergies',
          question: 'Known Allergies (Optional)',
          description: 'e.g., Penicillin, Nuts',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_meds',
          question: 'Current Medications (Optional)',
          description: 'List names if known',
          type: 'text'),
    ];
  }

  // Calculates the progress bar value based on the current stage and question index.
  void _updateProgressValue() {
    if (_assessmentQuestions.isEmpty) {
      _progressValue = 0.0;
      return;
    }

    int totalQuestions = _assessmentQuestions.length;
    int patientQuestionsCount =
        widget.isSelf ? 0 : _getPatientInfoQuestions().length;
    // Calculate the effective overall index based on stage.
    int currentEffectiveIndex = 0;
    if (_assessmentStage == 0)
      currentEffectiveIndex = 0; // Intro
    else if (_assessmentStage == 1)
      currentEffectiveIndex = _currentQuestionIndex; // Patient Info stage
    else if (_assessmentStage == 2)
      currentEffectiveIndex =
          patientQuestionsCount + _currentQuestionIndex; // Assessment stage
    else if (_assessmentStage == 3)
      currentEffectiveIndex = totalQuestions; // Results

    _progressValue = (currentEffectiveIndex / totalQuestions).clamp(0.0, 1.0);
  }

  // Checks if the current question should be skipped based on answers to previous questions.
  bool _shouldSkipQuestion(EmergencyQuestion question) {
    if (question.condition == null) return false; // No condition, don't skip.
    Map<String, dynamic> condition = question.condition!;
    String dependsOn = condition['dependsOn'];
    dynamic expectedValue = condition['equals'];
    // If the dependent question hasn't been answered yet, don't skip.
    if (!_answers.containsKey(dependsOn)) return false;
    // Skip if the answer to the dependent question doesn't match the expected value.
    return _answers[dependsOn] != expectedValue;
  }

  // Handles moving to the next logical step (question or stage).
  void _nextQuestion(dynamic answer) {
    HapticFeedback.selectionClick(); // Provide feedback

    // Determine the absolute index in the combined question list.
    int currentAbsoluteIndex = _currentQuestionIndex;
    int patientQuestionsCount =
        widget.isSelf ? 0 : _getPatientInfoQuestions().length;
    if (!widget.isSelf && _assessmentStage == 2) {
      currentAbsoluteIndex += patientQuestionsCount;
    }

    // Basic bounds check.
    if (currentAbsoluteIndex < 0 ||
        currentAbsoluteIndex >= _assessmentQuestions.length) {
      debugPrint(
          "Error: Invalid index $currentAbsoluteIndex in _nextQuestion. Submitting.");
      _submitAssessment();
      return;
    }

    // Save the answer for the current question.
    final currentQuestion = _assessmentQuestions[currentAbsoluteIndex];
    if (_assessmentStage == 1) {
      // Patient Info Stage
      // Map UI controller values to the _patientData map based on question ID.
      String questionId = currentQuestion.id;
      if (questionId == 'patient_name')
        _patientData['name'] = _patientNameController.text.trim();
      else if (questionId == 'patient_age')
        _patientData['age'] = int.tryParse(_patientAgeController.text.trim());
      else if (questionId == 'patient_gender')
        _patientData['gender'] =
            answer; // Answer is the selected gender string.
      else if (questionId == 'patient_conditions')
        _patientData['medical_conditions'] =
            _patientConditionsController.text.trim();
      else if (questionId == 'patient_allergies')
        _patientData['allergies'] = _patientAllergiesController.text.trim();
      else if (questionId == 'patient_meds')
        _patientData['medications'] = _patientMedicationsController.text.trim();
      // Also save to general answers map for potential condition/jump logic if needed.
      _answers[questionId] = answer;
    } else if (_assessmentStage == 2) {
      // Main Assessment Stage
      _answers[currentQuestion.id] = answer;
    }

    // Check if the answer triggers a jump to a different question.
    if (currentQuestion.jumps != null) {
      for (var jump in currentQuestion.jumps!) {
        if (jump['whenAnswerIs'] == answer) {
          int targetIndex = _assessmentQuestions
              .indexWhere((q) => q.id == jump['toQuestion']);
          if (targetIndex != -1) {
            // Calculate the index relative to the *start* of the assessment stage (stage 2).
            int targetStageRelativeIndex = targetIndex - patientQuestionsCount;
            if (widget.isSelf)
              targetStageRelativeIndex =
                  targetIndex; // No patient questions offset if self

            // Ensure the jump target is within the assessment stage bounds.
            int assessmentQuestionsCount =
                _assessmentConfig?.questions.length ?? 0;
            if (targetStageRelativeIndex >= 0 &&
                targetStageRelativeIndex < assessmentQuestionsCount) {
              setState(() {
                _assessmentStage = 2; // Ensure we are in the assessment stage.
                _currentQuestionIndex =
                    targetStageRelativeIndex; // Set index relative to assessment start.
                _updateProgressValue();
              });
              return; // Jump executed.
            } else {
              debugPrint(
                  "Warning: Jump target '${jump['toQuestion']}' is outside the main assessment questions. Continuing sequentially.");
            }
          } else {
            debugPrint(
                "Warning: Jump target question ID '${jump['toQuestion']}' not found.");
          }
        }
      }
    }

    // --- Stage Progression Logic ---
    // If just finished the Intro stage (Stage 0)
    if (_assessmentStage == 0) {
      setState(() {
        _assessmentStage = widget.isSelf
            ? 2
            : 1; // Go to Assessment if self, else Patient Info.
        _currentQuestionIndex =
            0; // Start at the first question of the new stage.
        _updateProgressValue();
      });
      return;
    }
    // If just finished the Patient Info stage (Stage 1)
    else if (_assessmentStage == 1 &&
        _currentQuestionIndex >= patientQuestionsCount - 1) {
      setState(() {
        _assessmentStage = 2; // Move to the main Assessment stage.
        _currentQuestionIndex = 0; // Start at the first assessment question.
        _updateProgressValue();
      });
      // Need to find the first *non-skipped* assessment question
      int nextStageIndex = 0;
      int assessmentQuestionsCount = _assessmentConfig?.questions.length ?? 0;
      while (nextStageIndex < assessmentQuestionsCount) {
        int nextAbsoluteIndex = nextStageIndex + patientQuestionsCount;
        if (nextAbsoluteIndex < _assessmentQuestions.length &&
            !_shouldSkipQuestion(_assessmentQuestions[nextAbsoluteIndex])) {
          setState(() {
            _currentQuestionIndex = nextStageIndex;
            _updateProgressValue();
          });
          return; // Found the first question
        }
        nextStageIndex++;
      }
      // If all assessment questions are skipped (unlikely), submit.
      _submitAssessment();
      return;
    }

    // --- Question Progression within the current stage ---
    // Determine the last index for the *current* stage.
    int currentMaxIndexInStage = 0;
    if (_assessmentStage == 1)
      currentMaxIndexInStage = patientQuestionsCount - 1;
    else if (_assessmentStage == 2)
      currentMaxIndexInStage =
          (_assessmentQuestions.length - patientQuestionsCount) - 1;

    // If we are already at the last question of the current stage, submit.
    if (_currentQuestionIndex >= currentMaxIndexInStage) {
      _submitAssessment();
      return;
    }

    // Find the next question index within the current stage, skipping over any conditional questions.
    int nextStageIndex = _currentQuestionIndex + 1;
    while (nextStageIndex <= currentMaxIndexInStage) {
      int nextAbsoluteIndex = nextStageIndex;
      // Adjust absolute index if we are in the assessment stage (Stage 2) for a non-self assessment.
      if (!widget.isSelf && _assessmentStage == 2) {
        nextAbsoluteIndex += patientQuestionsCount;
      }
      // Check if the question at the absolute index should be skipped.
      if (nextAbsoluteIndex < _assessmentQuestions.length &&
          !_shouldSkipQuestion(_assessmentQuestions[nextAbsoluteIndex])) {
        // Found the next valid question. Update state.
        setState(() {
          _currentQuestionIndex =
              nextStageIndex; // Index relative to the current stage.
          _updateProgressValue();
        });
        return; // Stop searching.
      }
      nextStageIndex++; // Check the next index in the stage.
    }

    // If the loop finishes, it means all remaining questions in this stage were skipped. Submit.
    _submitAssessment();
  }

  // Handles moving back to the previous question or stage.
  void _previousQuestion() {
    HapticFeedback.selectionClick();

    // Find the previous non-skipped question *within the current stage*.
    int prevStageIndex = _currentQuestionIndex - 1;
    while (prevStageIndex >= 0) {
      int prevAbsoluteIndex = prevStageIndex;
      if (!widget.isSelf && _assessmentStage == 2) {
        prevAbsoluteIndex += _getPatientInfoQuestions().length;
      }
      if (prevAbsoluteIndex >= 0 &&
          prevAbsoluteIndex < _assessmentQuestions.length &&
          !_shouldSkipQuestion(_assessmentQuestions[prevAbsoluteIndex])) {
        // Found a previous valid question in this stage.
        setState(() {
          _currentQuestionIndex = prevStageIndex;
          _updateProgressValue();
        });
        return;
      }
      prevStageIndex--;
    }

    // If no previous question found in the current stage, try moving to the previous stage.
    if (_assessmentStage == 2 && !widget.isSelf) {
      // Move from Assessment (Stage 2) back to the *last* question of Patient Info (Stage 1).
      setState(() {
        _assessmentStage = 1;
        // Find last non-skipped patient info question (or default to last index).
        int lastPatientInfoIndex = _getPatientInfoQuestions().length - 1;
        while (lastPatientInfoIndex >= 0 &&
            _shouldSkipQuestion(_assessmentQuestions[lastPatientInfoIndex])) {
          lastPatientInfoIndex--;
        }
        _currentQuestionIndex = (lastPatientInfoIndex >= 0)
            ? lastPatientInfoIndex
            : _getPatientInfoQuestions().length - 1;
        _updateProgressValue();
      });
    } else if (_assessmentStage == 1 ||
        (_assessmentStage == 2 && widget.isSelf)) {
      // Move from Patient Info (Stage 1) or Assessment (Stage 2, if self) back to Intro (Stage 0).
      setState(() {
        _assessmentStage = 0;
        _currentQuestionIndex = 0;
        _updateProgressValue();
      });
    }
    // Cannot go back from Stage 0.
  }

  // Formats answers and patient data, then sends to the AI service.
  Future<void> _submitAssessment() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    try {
      // Consolidate patient data (either from profile or collected info).
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      Map<String, dynamic> finalPatientData;
      if (widget.isSelf) {
        // Pull data from the ProfileProvider.
        finalPatientData = {
          'is_self': true,
          'name': profileProvider.name.isEmpty ? 'Self' : profileProvider.name,
          'age': profileProvider.age,
          'gender': profileProvider.gender,
          'weight_kg':
              profileProvider.weight > 0 ? profileProvider.weight : null,
          'height_cm':
              profileProvider.height > 0 ? profileProvider.height : null,
          'blood_type': profileProvider.bloodType.isEmpty
              ? null
              : profileProvider.bloodType,
          'medical_conditions': profileProvider.medicalConditions
              .where((c) => c.selected)
              .map((c) => c.name)
              .toList(),
          'allergies': profileProvider.allergies,
          'medications': profileProvider.medications
              .map((m) => '${m.name} (${m.dosage}, ${m.frequency})')
              .toList(),
        };
      } else {
        // Use the data collected in the patient info stage.
        finalPatientData = Map.from(_patientData);
      }

      // Format the collected answers nicely for the AI prompt.
      String formattedAnswers = _answers.entries.map((entry) {
        final questionText = _assessmentQuestions
            .firstWhere((q) => q.id == entry.key,
                orElse: () => EmergencyQuestion(
                    id: entry.key, question: entry.key, type: 'unknown'))
            .question;
        return "Q: $questionText\nA: ${entry.value?.toString() ?? 'Not answered'}";
      }).join('\n\n');

      // Construct the detailed prompt for the AI.
      final prompt = """
**Emergency Assessment Analysis Request**
**Emergency Type:** ${_assessmentConfig?.title ?? widget.emergencyType.toUpperCase()}
**Patient Information:**
${finalPatientData.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) => "- ${e.key.replaceAll('_', ' ').capitalize()}: ${e.value}").join('\n')}
**Assessment Answers:**
$formattedAnswers
**Location Context:** $_updatedLocationInfo
**Instructions Requested:**
Based *only* on the information provided above, generate clear, concise, step-by-step first aid instructions suitable for a layperson. Prioritize immediate life-saving actions. Be direct and avoid overly technical jargon. Do *not* provide a diagnosis. Start the response directly with the instructions using numbered or bulleted points.
""";

      debugPrint("--- AI Prompt ---\n$prompt\n--- End AI Prompt ---");

      // Send the request via ApiService.
      final result = await _apiService.sendMedicalQuestion(
          // Using sendMedicalQuestion endpoint for flexibility.
          question: prompt.trim(),
          messageHistory: [], // No chat history needed for this specific prompt.
          maxTokens: 768, // Allow potentially longer instructions.
          temperature: 0.3);

      // Update UI with results.
      if (mounted) {
        setState(() {
          _aiInstructions =
              result['answer'] ?? 'Error: No instructions received.';
          _assessmentStage = 3; // Move to results stage.
          _isSubmitting = false;
        });
      }
    } catch (e) {
      // Handle errors during submission.
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _assessmentStage = 3; // Show results stage even on error.
          _errorMessage =
              e is ApiServiceException ? e.message : 'Failed: ${e.toString()}';
          _aiInstructions = "Error retrieving instructions:\n$_errorMessage";
        });
      }
    }
  }

  // Uses url_launcher to initiate a phone call to emergency services (e.g., 911).
  Future<void> _callEmergency() async {
    HapticFeedback.heavyImpact();
    // Adapt the number if needed for different regions, though 911 is common.
    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch call')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error calling: $e')));
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    // Ask for confirmation before user navigates back mid-assessment.
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          backgroundColor: Theme.of(context)
              .colorScheme
              .error, // Use error color for emphasis.
          foregroundColor: Theme.of(context).colorScheme.onError,
          elevation: 2.0,
        ),
        body: _buildBody(), // Dynamically builds content based on stage.
        // Show call button bar only for high-priority emergencies.
        bottomNavigationBar:
            _showEmergencyCallButton ? _buildEmergencyCallBar() : null,
      ),
    );
  }

  // Confirms if the user wants to exit the assessment prematurely.
  Future<bool> _onWillPop() async {
    // Only prompt if assessment is in progress (stages 1 or 2).
    if (_assessmentStage > 0 && _assessmentStage < 3) {
      bool shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit Assessment?'),
              content: const Text('Progress will be lost if you exit now.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ) ??
          false; // Default to false if dialog is dismissed.
      return shouldPop;
    }
    // Allow popping freely from intro or results stage.
    return true;
  }

  // Generates the AppBar title based on the loaded assessment config or emergency type.
  String _getAppBarTitle() {
    String title = _assessmentConfig?.title ??
        widget.emergencyType.replaceAll('_', ' ').capitalize();
    return '$title Assessment';
  }

  // Main widget switcher based on the current assessment stage.
  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty && _assessmentStage != 3)
      return _buildErrorView(); // Show error unless on results page
    if (_assessmentConfig == null && _assessmentStage != 3)
      return _buildErrorView(
          message: "Configuration missing for this emergency type.");

    switch (_assessmentStage) {
      case 0:
        return _buildIntroInformation(); // Show Do's/Don'ts and start button.
      case 1:
        return _buildPatientInfoForm(); // Show patient info questions (if !isSelf).
      case 2:
        return _assessmentQuestions.isEmpty // Show assessment questions.
            ? const Center(child: Text('No assessment questions defined.'))
            : _buildQuestionCard();
      case 3:
        return _buildAssessmentResults(); // Show AI instructions or error.
      default:
        return const Center(child: Text('Invalid assessment stage.'));
    }
  }

  // Displays an error message if loading fails.
  Widget _buildErrorView({String? message}) {
    final theme = Theme.of(context);
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 60),
              const SizedBox(height: 16),
              Text('Error Loading Assessment',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message ?? _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  onPressed: () =>
                      Navigator.maybePop(context), // Try to pop back
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceVariant))
            ])));
  }

  // Displays the initial information (Do's, Don'ts, description) and start button.
  Widget _buildIntroInformation() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              // Title and description box
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_assessmentConfig!.title.toUpperCase(),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    Text(_emergencyDescription,
                        style: theme.textTheme.bodyLarge),
                  ])),
          const SizedBox(height: 24),
          Text('WHAT TO DO',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
          const SizedBox(height: 12),
          ..._dos.map((item) => _buildListItem(item, Icons.check_circle,
              Colors.green)), // Build list items for Do's
          const SizedBox(height: 24),
          Text('WHAT NOT TO DO',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          ..._donts.map((item) => _buildListItem(item, Icons.cancel,
              theme.colorScheme.error)), // Build list items for Don'ts
          const SizedBox(height: 32),
          // Information box about the assessment process.
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Text(
                    'This assessment asks questions to understand the situation better and provide relevant first aid suggestions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Text(
                    widget.isSelf
                        ? 'Your saved profile information may be used.'
                        : 'You will be asked for basic patient information.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
              ])),
          const SizedBox(height: 32),
          // Start Assessment Button
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('START ASSESSMENT'),
                onPressed: () =>
                    _nextQuestion(null), // Trigger moving to the next stage
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              )),
          const SizedBox(height: 24),
          // Show direct call button and disclaimer if high priority
          if (_showEmergencyCallButton) _buildDirectCallButton(),
          const SizedBox(height: 16),
          if (_showEmergencyCallButton) _buildPriorityDisclaimer(),
        ]));
  }

  // Helper to create styled list items for Do's and Don'ts.
  Widget _buildListItem(String text, IconData icon, Color color) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ]));
  }

  // Builds the "Call Emergency Services Directly" button.
  Widget _buildDirectCallButton() {
    final theme = Theme.of(context);
    return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _callEmergency,
          icon: Icon(Icons.call, color: theme.colorScheme.error),
          label: Text('CALL EMERGENCY SERVICES DIRECTLY',
              style: TextStyle(color: theme.colorScheme.error)),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16)),
        ));
  }

  // Builds the high-priority situation disclaimer text.
  Widget _buildPriorityDisclaimer() {
    final theme = Theme.of(context);
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.priority_high, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'If life-threatening, call emergency services immediately.',
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 14))),
        ]));
  }

  // Builds the section for gathering patient info (if !isSelf).
  Widget _buildPatientInfoForm() {
    final theme = Theme.of(context);
    // Safety check for index bounds.
    if (_assessmentStage != 1 ||
        _currentQuestionIndex >= _getPatientInfoQuestions().length) {
      return _buildErrorView(message: "Invalid state for patient info form.");
    }
    final question = _assessmentQuestions[_currentQuestionIndex];
    int displayIndex =
        _currentQuestionIndex; // Index within the patient info stage.

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color: theme
                  .colorScheme.primary, // Use primary color for info gathering
              minHeight: 8,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          // Show progress within the patient info stage.
          Text(
              'Patient Information (${displayIndex + 1}/${_getPatientInfoQuestions().length})',
              style: TextStyle(
                  fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          // Display the current patient info question.
          Text(question.question,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (question.description != null)
            Text(question.description!,
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          // Input widget specific to the question ID.
          Expanded(child: _buildPatientInfoInput(question)),
          // Show navigation buttons (only 'Back' is possible here).
          if (!_isSubmitting) _buildNavigationButtons(isPatientInfoStage: true),
        ]));
  }

  // Renders the correct input widget based on the conceptual patient info question ID.
  Widget _buildPatientInfoInput(EmergencyQuestion question) {
    final theme = Theme.of(context);
    // Map conceptual question IDs to actual input fields.
    switch (question.id) {
      case 'patient_info_intro':
        return _buildInfoNotice(question);
      case 'patient_name':
        return TextFormField(
            controller: _patientNameController,
            decoration: const InputDecoration(
                labelText: 'Name', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_age':
        return TextFormField(
            controller: _patientAgeController,
            decoration: const InputDecoration(
                labelText: 'Age (years)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_gender':
        return Column(
            // Use radio buttons for gender.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (question.options ?? []).map((option) {
              return RadioListTile<String>(
                  title: Text(option['text']),
                  value: option['value'],
                  groupValue: _patientGender,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _patientGender =
                          value); // Update local state for radio button group.
                      Future.delayed(
                          const Duration(milliseconds: 250),
                          () => _nextQuestion(
                              value)); // Move next after short delay.
                    }
                  },
                  activeColor: theme.colorScheme.primary,
                  contentPadding: EdgeInsets.zero);
            }).toList());
      case 'patient_conditions':
        return TextFormField(
            controller: _patientConditionsController,
            decoration: const InputDecoration(
                labelText: 'Known Conditions', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_allergies':
        return TextFormField(
            controller: _patientAllergiesController,
            decoration: const InputDecoration(
                labelText: 'Known Allergies', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_meds':
        return TextFormField(
            controller: _patientMedicationsController,
            decoration: const InputDecoration(
                labelText: 'Current Medications', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      default:
        return Center(
            child: Text('Unknown patient info field: ${question.id}'));
    }
  }

  // Builds the main card displaying the current assessment question and answer options.
  Widget _buildQuestionCard() {
    final theme = Theme.of(context);
    // Calculate the correct index in the combined list (_assessmentQuestions).
    int questionListIndex = _currentQuestionIndex;
    if (!widget.isSelf && _assessmentStage == 2) {
      questionListIndex += _getPatientInfoQuestions().length;
    }
    // Safety check.
    if (questionListIndex < 0 ||
        questionListIndex >= _assessmentQuestions.length) {
      return _buildErrorView(message: "Invalid question index.");
    }
    final currentQuestion = _assessmentQuestions[questionListIndex];

    // Calculate display numbers (relative to the assessment part only).
    int displayQuestionNumber = widget.isSelf
        ? (_currentQuestionIndex + 1)
        : (_currentQuestionIndex + 1);
    int totalDisplayQuestions = _assessmentConfig?.questions.length ??
        0; // Total in just the assessment part.

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Progress Bar and Question Counter
          Column(children: [
            LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: theme.colorScheme.surfaceVariant,
                color: theme.colorScheme
                    .error, // Use error color for assessment stage progress.
                minHeight: 8,
                borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Question $displayQuestionNumber of $totalDisplayQuestions',
                  style: TextStyle(
                      fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
              // Display emergency type tag.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.3))),
                child: Text(_assessmentConfig!.title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error)),
              )
            ]),
          ]),
          const SizedBox(height: 24),
          // Question Text
          Text(currentQuestion.question,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (currentQuestion.description != null)
            Text(currentQuestion.description!,
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          // Dynamically build the answer widget based on question type.
          Expanded(child: _buildAnswerWidget(currentQuestion)),
          // Show navigation or submitting indicator.
          if (!_isSubmitting) _buildNavigationButtons(),
          if (_isSubmitting) _buildSubmittingIndicator(),
        ]));
  }

  // Determines which answer input widget to build based on the question type.
  Widget _buildAnswerWidget(EmergencyQuestion question) {
    switch (question.type) {
      case 'multiple_choice':
        return _buildMultipleChoiceQuestion(question);
      case 'boolean':
        return _buildBooleanQuestion(question);
      case 'slider':
        return _buildSliderQuestion(question);
      case 'text':
        return _buildTextQuestion(question);
      case 'info':
        return _buildInfoNotice(question);
      default:
        return Center(
            child: Text('Unsupported question type: ${question.type}'));
    }
  }

  // --- Widgets for Specific Question Types ---

  // Builds radio buttons or cards for multiple choice questions.
  Widget _buildMultipleChoiceQuestion(EmergencyQuestion question) {
    final theme = Theme.of(context);
    final List<dynamic> options = question.options ?? [];
    // Check if a specific display style is requested (e.g., 'radio').
    final bool useRadio = question.toJson()['display'] == 'radio';

    if (useRadio) {
      // Build RadioListTiles if 'display: radio' is specified.
      String? currentAnswer = _answers[question.id]?.toString();
      return StatefulBuilder(builder: (context, setRadioState) {
        return ListView(
            // Use ListView for potentially many radio options.
            shrinkWrap: true,
            children: options.map((option) {
              final String optionValue = option['value'].toString();
              return RadioListTile<String>(
                  title: Text(option['text']),
                  value: optionValue,
                  groupValue: currentAnswer,
                  onChanged: (value) {
                    if (value != null) {
                      setRadioState(() => currentAnswer =
                          value); // Update radio selection visually.
                      Future.delayed(
                          const Duration(milliseconds: 200),
                          () => _nextQuestion(option[
                              'value'])); // Move next after slight delay.
                    }
                  },
                  activeColor: theme.colorScheme
                      .error, // Use error color for assessment stage.
                  subtitle: option['description'] != null
                      ? Text(option['description'])
                      : null);
            }).toList());
      });
    } else {
      // Default: Build clickable cards for each option.
      return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () => _nextQuestion(
                            option['value']), // Trigger next question on tap.
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option['text'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                              if (option['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(option['description'],
                                    style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant))
                              ],
                            ]))));
          });
    }
  }

  // Builds Yes/No buttons for boolean questions.
  Widget _buildBooleanQuestion(EmergencyQuestion question) {
    final theme = Theme.of(context);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () => _nextQuestion(true), // Send 'true' on Yes.
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Yes', style: TextStyle(fontSize: 18))),
      const SizedBox(height: 16),
      ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () => _nextQuestion(false), // Send 'false' on No.
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('No', style: TextStyle(fontSize: 18))),
    ]);
  }

  // Builds a slider input. **FIXED** state handling.
  Widget _buildSliderQuestion(EmergencyQuestion question) {
    final double min = question.min ?? 0.0;
    final double max = question.max ?? 10.0;
    // Ensure divisions is at least 1 if max > min.
    final int divisions = question.divisions ??
        ((max > min) ? (max - min).clamp(1, 100).toInt() : 1);
    // Get initial value from stored answers or question default.
    final double initialValue =
        (_answers[question.id] as double?) ?? question.defaultValue ?? min;

    // Use StatefulBuilder to manage the slider's transient state locally.
    return StatefulBuilder(builder: (context, setState) {
      // **FIX:** Manage currentValue within the StatefulBuilder's scope.
      double currentValue = initialValue.clamp(min, max);

      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Display current value prominently.
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _getSliderColor(currentValue, min, max).withOpacity(0.1),
                shape: BoxShape.circle),
            child: Text('${currentValue.toInt()}',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getSliderColor(currentValue, min, max)))),
        const SizedBox(height: 16),
        // Optional labels for min/max based on description.
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(question.description?.split(',')[0].trim() ?? 'Min',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          Text(question.description?.split(',').last.trim() ?? 'Max',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red.shade700))
        ]),
        // The actual Slider widget.
        Slider(
            value: currentValue,
            min: min,
            max: max,
            divisions: divisions,
            label: '${currentValue.toInt()}',
            activeColor: _getSliderColor(currentValue, min, max),
            // **FIX:** Update the local currentValue using the builder's setState.
            onChanged: (newValue) => setState(() => currentValue = newValue)),
        const SizedBox(height: 32),
        // Button to confirm the slider value and move next.
        ElevatedButton(
            // **FIX:** Pass the final currentValue from the builder's state.
            onPressed: _isSubmitting ? null : () => _nextQuestion(currentValue),
            style: ElevatedButton.styleFrom(
                backgroundColor: _getSliderColor(currentValue, min, max),
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white),
            child: const Text('Next')),
      ]);
    });
  }

  // Dynamically determines slider thumb/track color based on value percentage.
  Color _getSliderColor(double value, double min, double max) {
    if (max <= min)
      return Colors.blue; // Avoid division by zero, return default.
    final double percentage = (value - min) / (max - min);
    if (percentage < 0.3) return Colors.green;
    if (percentage < 0.7) return Colors.orange;
    return Colors.red;
  }

  // Builds a multi-line text input field.
  Widget _buildTextQuestion(EmergencyQuestion question) {
    final TextEditingController textController =
        TextEditingController(text: _answers[question.id]?.toString() ?? '');
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(
        controller: textController,
        decoration: InputDecoration(
            hintText: question.description ?? 'Enter details...',
            border: const OutlineInputBorder()),
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) =>
            _nextQuestion(v), // Allow submitting via keyboard action.
      ),
      const SizedBox(height: 24),
      ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () => _nextQuestion(
                  textController.text.trim()), // Submit trimmed text.
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50)),
          child: const Text('Next')),
    ]);
  }

  // Builds a display card for informational "questions".
  Widget _buildInfoNotice(EmergencyQuestion question) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine color and icon based on noticeType.
    Color noticeColor = colorScheme.primary;
    IconData noticeIcon = Icons.info_outline;
    switch (question.noticeType?.toLowerCase()) {
      case 'warning':
        noticeColor = Colors.orange;
        noticeIcon = Icons.warning_amber_outlined;
        break;
      case 'danger':
        noticeColor = colorScheme.error;
        noticeIcon = Icons.dangerous_outlined;
        break;
      case 'success':
        noticeColor = Colors.green;
        noticeIcon = Icons.check_circle_outline;
        break;
    }
    // Don't show nav buttons for the patient info intro card.
    bool isPatientIntro = question.id == 'patient_info_intro';

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: noticeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: noticeColor.withOpacity(0.3))),
          child: Column(children: [
            Icon(noticeIcon, color: noticeColor, size: 48),
            const SizedBox(height: 16),
            if (question.content != null)
              Text(question.content!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center)
          ])),
      const Spacer(), // Push button to bottom
      // Only show nav buttons if it's not the patient intro card.
      if (!isPatientIntro)
        ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () =>
                    _nextQuestion(true), // Answer doesn't matter for info type.
            style: ElevatedButton.styleFrom(
                backgroundColor: noticeColor,
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white),
            child: const Text('Continue')),
      if (!isPatientIntro)
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'))),
      // Special "Next" button for the patient info intro card.
      if (isPatientIntro)
        Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: ElevatedButton(
                onPressed: () => _nextQuestion(true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Next'))),
    ]);
  }

  // Builds the Back button (if applicable for the current stage/index).
  Widget _buildNavigationButtons({bool isPatientInfoStage = false}) {
    bool canGoBack = false;
    // Can go back within Patient Info stage if not the first question.
    if (_assessmentStage == 1)
      canGoBack = _currentQuestionIndex > 0;
    // Can always go back from the main assessment stage (to patient info or intro).
    else if (_assessmentStage == 2) canGoBack = true;

    if (canGoBack) {
      return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(children: [
            TextButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back')),
            const Spacer(), // Pushes button to the left
          ]));
    }
    // Don't show Back button on the first question of Stage 1 or any part of Stage 0.
    return const SizedBox.shrink();
  }

  // Simple loading indicator shown during AI submission.
  Widget _buildSubmittingIndicator() {
    return const Center(
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating instructions...')
            ])));
  }

  // Builds the final results screen showing AI instructions or errors.
  Widget _buildAssessmentResults() {
    final theme = Theme.of(context);
    final bool hasError =
        _aiInstructions != null && _aiInstructions!.startsWith("Error");

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Column(children: [
            // Centered status icon and title.
            Icon(hasError ? Icons.error_outline : Icons.check_circle_outline,
                size: 64,
                color: hasError ? theme.colorScheme.error : Colors.green),
            const SizedBox(height: 16),
            Text(
                hasError
                    ? 'Error Generating Instructions'
                    : 'Assessment Complete',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasError ? theme.colorScheme.error : null)),
          ])),
          const SizedBox(height: 32),
          // Card containing the AI instructions or error message.
          Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              hasError
                                  ? Icons.report_problem_outlined
                                  : Icons.integration_instructions_outlined,
                              color: hasError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              size: 28),
                          const SizedBox(width: 12),
                          Text(
                              hasError
                                  ? 'Error Details'
                                  : 'First Aid Instructions',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))
                        ]),
                        const Divider(height: 24),
                        SelectableText(
                            // Allows user to copy instructions.
                            _aiInstructions ?? 'Loading instructions...',
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                color:
                                    hasError ? theme.colorScheme.error : null)),
                      ]))),
          const SizedBox(height: 32),
          // Action buttons: Go Home, Call Emergency.
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                    onPressed: () => Navigator.of(context).popUntil((route) =>
                        route.isFirst), // Pop back to the home screen.
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 16)))),
            const SizedBox(width: 16),
            Expanded(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Emergency'),
                    onPressed: _callEmergency,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16)))),
          ]),
          const SizedBox(height: 16),
          // Share/Copy Button.
          Center(
              child: TextButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share/Copy Instructions'),
                  onPressed: _shareAssessmentResults)),
          const SizedBox(height: 24),
          // Standard disclaimer.
          _buildDisclaimer(),
        ]));
  }

  // Formats results and copies to clipboard.
  void _shareAssessmentResults() {
    if (_aiInstructions == null ||
        _aiInstructions!.isEmpty ||
        _aiInstructions!.startsWith("Error")) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid instructions to share.')));
      return;
    }
    try {
      final shareText = StringBuffer();
      shareText.writeln(
          'EMERGENCY ASSESSMENT - ${_assessmentConfig?.title.toUpperCase() ?? widget.emergencyType.toUpperCase()}');
      shareText.writeln('Location: $_updatedLocationInfo');
      // Include answers if available.
      if (_answers.isNotEmpty) {
        shareText.writeln('\n--- ASSESSMENT ANSWERS ---');
        _answers.forEach((key, value) {
          final qText = _assessmentQuestions
              .firstWhere((q) => q.id == key,
                  orElse: () =>
                      EmergencyQuestion(id: key, question: key, type: ''))
              .question;
          shareText.writeln("Q: $qText\nA: ${value?.toString() ?? 'N/A'}");
        });
      }
      shareText.writeln('\n--- AI GENERATED INSTRUCTIONS ---');
      shareText.writeln(_aiInstructions);
      shareText.writeln(
          '\nDisclaimer: Provided by Health Assistant app. Not medical advice.');

      Clipboard.setData(ClipboardData(text: shareText.toString()));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Instructions copied to clipboard')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to prepare sharing data: $e')));
    }
  }

  // Builds the standard disclaimer shown at the end.
  Widget _buildDisclaimer() {
    final theme = Theme.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  'Assessment & instructions are informational only, not a substitute for professional medical advice. Call emergency services in life-threatening situations.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12)))
        ]));
  }

  // Builds the prominent "Call Emergency Services" bar shown at the bottom for high-priority cases.
  Widget _buildEmergencyCallBar() {
    final theme = Theme.of(context);
    return SafeArea(
      // Ensures content isn't hidden by notches/system UI.
      child: Container(
        color: theme.colorScheme.error, // Use error color for high visibility.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ElevatedButton(
          onPressed: _callEmergency,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, // Contrasting button color.
            foregroundColor: theme.colorScheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.call, size: 24),
              SizedBox(width: 10),
              Text('CALL EMERGENCY SERVICES',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extension for simple string capitalization.
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    // Simple capitalization for single words or snake_case.
    String processed = replaceAll('_', ' ');
    if (processed.isEmpty) return "";
    return "${processed[0].toUpperCase()}${processed.substring(1).toLowerCase()}";
  }
}
