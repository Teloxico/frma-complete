// test/models/test_models.dart

import 'package:flutter/material.dart'; // Required for IconData
import 'package:flutter_test/flutter_test.dart';

// Assuming your models are in these locations relative to the 'lib' folder
// Adjust the import paths if your file structure is different.
import '../lib/models/api_mode.dart';
import '../lib/models/emergency_assessment_data.dart';
import '../lib/models/message.dart';

void main() {
  group('ApiMode Tests', () {
    test('ApiMode.localServer properties', () {
      const mode = ApiMode.localServer;
      expect(mode.label, 'Local Server');
      expect(mode.description, 'Connect to a local Medical LLM server');
      expect(mode.icon, Icons.computer);
    });

    test('ApiMode.runPod properties', () {
      const mode = ApiMode.runPod;
      expect(mode.label, 'RunPod API');
      expect(mode.description, 'Connect to RunPod API for cloud inference');
      expect(mode.icon, Icons.cloud);
    });
  });

  group('EmergencyQuestion Tests', () {
    test('fromJson parses basic text question correctly', () {
      final json = {
        'id': 'q1',
        'text': 'What is your name?',
        'type': 'text',
        'description': 'Enter full name'
      };
      final question = EmergencyQuestion.fromJson(json);

      expect(question.id, 'q1');
      expect(question.question, 'What is your name?'); // Internal field name
      expect(question.type, 'text');
      expect(question.description, 'Enter full name');
      expect(question.options, isNull);
    });

    test('fromJson parses boolean question correctly', () {
      final json = {
        'id': 'q_bool',
        'text': 'Are you conscious?',
        'type': 'boolean',
      };
      final question = EmergencyQuestion.fromJson(json);
      expect(question.type, 'boolean');
      expect(question.question, 'Are you conscious?');
    });

    test('fromJson parses multiple choice question correctly', () {
      final json = {
        'id': 'q_mc',
        'text': 'Select color',
        'type': 'multiple_choice',
        'options': [
          {'text': 'Red', 'value': 'r'},
          {'text': 'Blue', 'value': 'b'}
        ]
      };
      final question = EmergencyQuestion.fromJson(json);
      expect(question.type, 'multiple_choice');
      expect(question.question, 'Select color');
      expect(question.options, isNotNull);
      expect(question.options!.length, 2);
      expect(question.options![0]['value'], 'r');
      expect(question.options![1]['text'], 'Blue');
    });

    test('fromJson handles missing optional fields and defaults', () {
      final json = {'id': 'q_minimal', 'text': 'Info only'};
      final question = EmergencyQuestion.fromJson(json);

      expect(question.id, 'q_minimal');
      expect(question.question, 'Info only');
      expect(question.type, 'info'); // Default type
      expect(question.description, isNull);
      expect(question.options, isNull);
      expect(question.min, isNull);
      expect(question.max, isNull);
      expect(question.divisions, isNull);
      expect(question.defaultValue, isNull);
      expect(question.condition, isNull);
      expect(question.jumps, isNull);
      expect(question.noticeType, isNull);
      expect(question.content, isNull);
    });

    test('fromJson calculates slider divisions if not provided', () {
      final json = {
        'id': 'q_slider_calc',
        'text': 'Rate pain',
        'type': 'slider',
        'min': 0.0,
        'max': 10.0
        // divisions missing
      };
      final question = EmergencyQuestion.fromJson(json);

      expect(question.type, 'slider');
      expect(question.min, 0.0);
      expect(question.max, 10.0);
      expect(question.divisions, 10); // Calculated as max - min
    });

    test('fromJson uses provided slider divisions when present', () {
      final json = {
        'id': 'q_slider_provided',
        'text': 'Rate scale',
        'type': 'slider',
        'min': 1.0,
        'max': 5.0,
        'divisions': 8 // Provided, different from calculation
      };
      final question = EmergencyQuestion.fromJson(json);
      expect(question.divisions, 8); // Uses provided value
    });

    test('fromJson handles slider divisions when max <= min', () {
      final json = {
        'id': 'q_slider_edge',
        'text': 'Rate invalid',
        'type': 'slider',
        'min': 10.0,
        'max': 5.0,
        // divisions missing
      };
      final question = EmergencyQuestion.fromJson(json);
      expect(question.divisions, isNull); // Should not calculate if max <= min
    });

    test('toJson generates correct JSON structure', () {
      final question = EmergencyQuestion(
          id: 'q_to_json',
          question: 'Test Question',
          description: 'Test Desc',
          type: 'multiple_choice',
          options: [
            {'text': 'Yes', 'value': true}
          ],
          condition: {'dependsOn': 'q1', 'equals': 'val'},
          jumps: [
            {'whenAnswerIs': true, 'toQuestion': 'q3'}
          ],
          min: 1.0, // Add fields not automatically calculated by fromJson
          max: 5.0,
          divisions: 4,
          defaultValue: 2.0,
          noticeType: 'warning',
          content: 'Be careful');

      final json = question.toJson();

      expect(json['id'], 'q_to_json');
      expect(json['text'], 'Test Question'); // Ensure it maps back to 'text'
      expect(json['description'], 'Test Desc');
      expect(json['type'], 'multiple_choice');
      expect(json['options'], isNotNull);
      expect(json['options'][0]['value'], true);
      expect(json['condition'], isNotNull);
      expect(json['condition']['dependsOn'], 'q1');
      expect(json['jumps'], isNotNull);
      expect(json['jumps'][0]['toQuestion'], 'q3');
      expect(json['min'], 1.0);
      expect(json['max'], 5.0);
      expect(json['divisions'], 4); // Includes divisions since it was provided
      expect(json['defaultValue'], 2.0);
      expect(json['noticeType'], 'warning');
      expect(json['content'], 'Be careful');
    });

    test('toJson omits calculated divisions if they match min/max diff', () {
      // Create question where divisions would naturally be max-min
      final question = EmergencyQuestion(
          id: 'q_div_omit',
          question: 'Slider',
          type: 'slider',
          min: 0.0,
          max: 10.0,
          divisions: 10 // This matches max-min, should be omitted
          );

      final json = question.toJson();
      expect(json.containsKey('divisions'),
          isFalse); // Should not include default calc
    });
  });

  group('EmergencyAdvice Tests', () {
    test('fromJson parses correctly', () {
      final json = {
        'description': 'General advice description.',
        'dos': ['Do this', 'Do that'],
        'donts': ['Don\'t do this']
      };
      final advice = EmergencyAdvice.fromJson(json);

      expect(advice.description, 'General advice description.');
      expect(advice.dos, ['Do this', 'Do that']);
      expect(advice.donts, ['Don\'t do this']);
    });

    test('fromJson handles missing lists/description', () {
      final json = {
        'id': 'some_id',
        'title': 'Some Title'
      }; // Missing advice keys
      final advice = EmergencyAdvice.fromJson(json);

      expect(advice.description, 'No description provided.');
      expect(advice.dos, isEmpty);
      expect(advice.donts, isEmpty);
    });

    test('toJson generates correct JSON', () {
      final advice = EmergencyAdvice(
        description: 'Test Desc',
        dos: ['d1'],
        donts: ['ndt1', 'ndt2'],
      );
      final json = advice.toJson();

      expect(json['description'], 'Test Desc');
      expect(json['dos'], ['d1']);
      expect(json['donts'], ['ndt1', 'ndt2']);
    });
  });

  group('EmergencyAssessmentData Tests', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'burns',
        'title': 'Minor Burns',
        'description': 'First/second degree burns.',
        'highPriority': false,
        'color': '#FFA500',
        'icon': 'whatshot',
        'dos': ['Cool with water'],
        'donts': ['Don\'t use ice'],
        'questions': [
          {'id': 'q1', 'text': 'Is skin broken?', 'type': 'boolean'}
        ]
      };
      final data = EmergencyAssessmentData.fromJson(json);

      expect(data.id, 'burns');
      expect(data.title, 'Minor Burns');
      expect(data.isHighPriority, false);
      expect(data.color, '#FFA500');
      expect(data.icon, 'whatshot');
      expect(data.advice.description, 'First/second degree burns.');
      expect(data.advice.dos, ['Cool with water']);
      expect(data.advice.donts, ['Don\'t use ice']);
      expect(data.questions.length, 1);
      expect(data.questions[0].id, 'q1');
      expect(data.questions[0].type, 'boolean');
    });

    test('fromJson handles missing optional fields and defaults', () {
      final json = {
        'id': 'generic',
        'title': 'Generic Issue',
        // Missing description, highPriority, color, icon, dos, donts, questions
      };
      final data = EmergencyAssessmentData.fromJson(json);

      expect(data.id, 'generic');
      expect(data.title, 'Generic Issue');
      expect(data.isHighPriority, false); // Default
      expect(data.color, isNull);
      expect(data.icon, isNull);
      expect(data.advice.description, 'No description provided.'); // Default
      expect(data.advice.dos, isEmpty); // Default
      expect(data.advice.donts, isEmpty); // Default
      expect(data.questions, isEmpty); // Default
    });

    test('toJson generates correct structure', () {
      final question =
          EmergencyQuestion(id: 'q1', question: 'Q1 Text', type: 'text');
      final advice =
          EmergencyAdvice(description: 'Desc', dos: ['d1'], donts: ['nd1']);
      final data = EmergencyAssessmentData(
          id: 'test_id',
          title: 'Test Title',
          questions: [question],
          advice: advice,
          isHighPriority: true,
          color: '#FF0000',
          icon: 'favorite');

      final json = data.toJson();

      expect(json['id'], 'test_id');
      expect(json['title'], 'Test Title');
      expect(json['description'], 'Desc'); // Flattened from advice
      expect(json['highPriority'], true);
      expect(json['color'], '#FF0000');
      expect(json['icon'], 'favorite');
      expect(json['dos'], ['d1']);
      expect(json['donts'], ['nd1']);
      expect(json['questions'], isNotNull);
      expect(json['questions'].length, 1);
      expect(json['questions'][0]['id'], 'q1');
      expect(json['questions'][0]['text'],
          'Q1 Text'); // Check question mapped back to 'text'
      expect(json['questions'][0]['type'], 'text');
    });
  });

  group('Message Tests', () {
    test('Constructor sets timestamp', () {
      final now = DateTime.now();
      final message = Message(text: 'Hi', isUser: true);
      // Allow a small difference for execution time
      expect(message.timestamp.difference(now).inMilliseconds, lessThan(100));
      expect(message.text, 'Hi');
      expect(message.isUser, true);
    });

    test('Constructor uses provided timestamp', () {
      final specificTime = DateTime(2024, 1, 1, 10, 30, 0);
      final message =
          Message(text: 'Test', isUser: false, timestamp: specificTime);
      expect(message.timestamp, specificTime);
    });

    test('toJson serializes correctly', () {
      final specificTime = DateTime(2024, 1, 1, 10, 30, 0);
      final message =
          Message(text: 'Hello', isUser: true, timestamp: specificTime);
      final json = message.toJson();

      expect(json['text'], 'Hello');
      expect(json['isUser'], true);
      expect(json['timestamp'], specificTime.toIso8601String());
    });

    test('fromJson deserializes correctly', () {
      final specificTime = DateTime(2024, 1, 1, 10, 30, 0);
      final json = {
        'text': 'World',
        'isUser': false,
        'timestamp': specificTime.toIso8601String()
      };
      final message = Message.fromJson(json);

      expect(message.text, 'World');
      expect(message.isUser, false);
      expect(message.timestamp, specificTime);
    });

    test('fromJson handles missing/invalid timestamp', () {
      final json = {
        'text': 'Test',
        'isUser': true,
        'timestamp': 'invalid-date'
      };
      final message = Message.fromJson(json);
      // Should default to DateTime.now() - allow minor difference
      expect(
          message.timestamp.difference(DateTime.now()).inSeconds, lessThan(2));

      final jsonMissing = {'text': 'Test 2', 'isUser': false};
      final messageMissing = Message.fromJson(jsonMissing);
      expect(messageMissing.timestamp.difference(DateTime.now()).inSeconds,
          lessThan(2));
    });

    test('fromJson handles missing text/isUser', () {
      final json = {'timestamp': DateTime.now().toIso8601String()};
      final message = Message.fromJson(json);
      expect(message.text, ''); // Default text
      expect(message.isUser, false); // Default isUser
    });
  });
}
