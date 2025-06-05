// lib/models/emergency_assessment_data.dart

// Represents a single question in an assessment flow.
class EmergencyQuestion {
  final String id;
  final String question; // The actual question text displayed to the user.
  final String? description; // Optional extra details about the question.
  final String
      type; // Type determines how the question is displayed (e.g., 'slider', 'boolean').
  final List<Map<String, dynamic>>? options; // Options for 'multiple_choice'.
  final double? min; // For 'slider' type.
  final double? max; // For 'slider' type.
  final int? divisions; // For 'slider' type.
  final double? defaultValue; // For 'slider' type.
  final Map<String, dynamic>?
      condition; // For conditional visibility { "dependsOn": "id", "equals": value }.
  final List<Map<String, dynamic>>?
      jumps; // For branching logic { "whenAnswerIs": value, "toQuestion": "id" }.
  final String? noticeType; // For 'info' type styling (warning, danger, etc.).
  final String? content; // For 'info' type text content.

  EmergencyQuestion({
    required this.id,
    required this.question,
    this.description,
    required this.type,
    this.options,
    this.min,
    this.max,
    this.divisions,
    this.defaultValue,
    this.condition,
    this.jumps,
    this.noticeType,
    this.content,
  });

  // Creates an EmergencyQuestion from JSON data.
  // Handles defaults and calculates slider divisions if needed.
  factory EmergencyQuestion.fromJson(Map<String, dynamic> json) {
    int? calculatedDivisions;
    // Automatically calculate slider divisions if min/max are present but divisions are not.
    if (json['type'] == 'slider' &&
        json['max'] != null &&
        json['min'] != null &&
        json['divisions'] == null) {
      double maxVal = (json['max'] as num).toDouble();
      double minVal = (json['min'] as num).toDouble();
      if (maxVal > minVal) {
        calculatedDivisions = (maxVal - minVal).toInt();
      }
    }

    return EmergencyQuestion(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      question: json['text'] as String? ??
          'Missing question text', // Maps 'text' key from JSON.
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'info',
      options: json['options'] != null
          ? List<Map<String, dynamic>>.from(json['options'] as List)
          : null,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      divisions: calculatedDivisions ?? (json['divisions'] as int?),
      defaultValue: (json['defaultValue'] as num?)?.toDouble(),
      condition: json['condition'] != null
          ? Map<String, dynamic>.from(json['condition'] as Map)
          : null,
      jumps: json['jumps'] != null
          ? List<Map<String, dynamic>>.from(json['jumps'] as List)
          : null,
      noticeType: json['noticeType'] as String?,
      content: json['content'] as String?,
    );
  }

  // Converts this question back into JSON.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'text': question, // Maps back to 'text' for JSON consistency.
      'type': type,
    };
    if (description != null) data['description'] = description;
    if (options != null) data['options'] = options;
    if (min != null) data['min'] = min;
    if (max != null) data['max'] = max;
    // Only include divisions if it wasn't the default calculated value.
    if (divisions != null &&
        (max == null || min == null || divisions != (max! - min!).toInt())) {
      data['divisions'] = divisions;
    }
    if (defaultValue != null) data['defaultValue'] = defaultValue;
    if (condition != null) data['condition'] = condition;
    if (jumps != null) data['jumps'] = jumps;
    if (noticeType != null) data['noticeType'] = noticeType;
    if (content != null) data['content'] = content;
    return data;
  }
}

// Holds the Do's, Don'ts, and a general description for an emergency situation.
class EmergencyAdvice {
  final List<String> dos;
  final List<String> donts;
  final String description;

  EmergencyAdvice({
    required this.dos,
    required this.donts,
    required this.description,
  });

  // Creates advice info from relevant fields in the main emergency JSON object.
  factory EmergencyAdvice.fromJson(Map<String, dynamic> json) {
    return EmergencyAdvice(
      dos: json['dos'] != null ? List<String>.from(json['dos'] as List) : [],
      donts:
          json['donts'] != null ? List<String>.from(json['donts'] as List) : [],
      description: json['description'] as String? ?? 'No description provided.',
    );
  }

  // Converts advice back to JSON.
  Map<String, dynamic> toJson() {
    return {
      'dos': dos,
      'donts': donts,
      'description': description,
    };
  }
}

// Defines the overall structure for a specific emergency assessment, including questions and advice.
class EmergencyAssessmentData {
  final String id;
  final String title;
  final List<EmergencyQuestion> questions;
  final EmergencyAdvice advice;
  final bool isHighPriority;
  final String? color; // e.g., "#FF0000"
  final String? icon; // e.g., "favorite"

  EmergencyAssessmentData({
    required this.id,
    required this.title,
    required this.questions,
    required this.advice,
    this.isHighPriority = false,
    this.color,
    this.icon,
  });

  // Creates the full assessment data from a JSON object representing one emergency type.
  factory EmergencyAssessmentData.fromJson(Map<String, dynamic> json) {
    return EmergencyAssessmentData(
      id: json['id'] as String? ?? 'unknown_emergency',
      title: json['title'] as String? ?? 'Unknown Emergency',
      questions: (json['questions'] as List? ?? [])
          .map((q) => EmergencyQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      advice:
          EmergencyAdvice.fromJson(json), // Creates advice from the same JSON.
      isHighPriority: json['highPriority'] as bool? ?? false,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
    );
  }

  // Converts assessment data back to JSON, flattening the advice fields.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': advice.description,
      'color': color,
      'icon': icon,
      'highPriority': isHighPriority,
      'dos': advice.dos,
      'donts': advice.donts,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
