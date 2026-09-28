// Analyst 프롬프트 A/B: 같은 발화를 여러 번 호출해 추출 결과를 비교한다. (정규 테스트 아님)
import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart' show Schema;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:research_chatbot/config/agent_prompts.dart';
import 'package:research_chatbot/models/learner_profile.dart';
import 'package:research_chatbot/models/instructional_design.dart';
import 'package:research_chatbot/models/learning_state.dart';

void main() {
  test('analyst A/B', () async {
    final token = Platform.environment['VERTEX_TOKEN']!;
    final label = Platform.environment['AB_LABEL'] ?? '?';
    final reps = int.parse(Platform.environment['AB_REPS'] ?? '3');
    Schema fields(Schema Function(String) f) => Schema.object(properties: {
          'subject': f('subject'), 'goal': f('goal'), 'level': f('level'), 'tone_preference': f('tone_preference'),
        }, optionalProperties: ['subject', 'goal', 'level', 'tone_preference']);
    final schema = Schema.object(properties: {
      'extracted_info': Schema.object(properties: {
        'subject': Schema.string(description: '학습 주제'),
        'goal': Schema.string(description: '학습 목표'),
        'level': Schema.enumString(enumValues: ['beginner', 'intermediate', 'expert'], description: '학습자 수준'),
        'tone_preference': Schema.enumString(enumValues: ['kind', 'formal', 'casual'], description: '선호 말투'),
      }, optionalProperties: ['subject', 'goal', 'level', 'tone_preference']),
      'explicit_fields': fields((k) => Schema.boolean(description: '$k가 명시적으로 언급됨')),
      'field_confidence': fields((k) => Schema.number(description: '$k 명시 확신도 (0.0~1.0)')),
      'response': Schema.string(description: '사용자에게 보여줄 응답'),
    });
    final empty = LearningState(learnerProfile: LearnerProfile(), instructionalDesign: InstructionalDesign.empty());
    final withSubject = LearningState(
        learnerProfile: LearnerProfile(subject: '블록체인'), instructionalDesign: InstructionalDesign.empty());
    final cases = [
      (empty, '블록체인에 대해 학습하려고 해. 관련된 내용을 알려줄래?'),
      (withSubject, '방금 퀴즈를 풀었는데, 내가 애초에 처음 공부해봐서. 다양한 내용들을 배우고 싶어'),
      (withSubject, '갠념을 학습하고 싶다니깐. 비트코인이랑 관련 있는거지?'),
      (empty, '하이루'),
      (empty, '파이썬 배우고 싶어'),
    ];
    final url = Uri.parse('https://us-central1-aiplatform.googleapis.com/v1/projects/addie-tutor/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent');
    for (final (st, u) in cases) {
      final outs = <String>[];
      for (var i = 0; i < reps; i++) {
        final res = await http.post(url,
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [{'role': 'user', 'parts': [{'text': AgentPrompts.analyst(st, u)}]}],
              'generationConfig': {'responseMimeType': 'application/json', 'responseSchema': schema.toJson(), 'temperature': 0.0},
            }));
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        final j = jsonDecode(d['candidates'][0]['content']['parts'].map((p) => p['text']).join()) as Map;
        String f(String k) {
          final e = (j['explicit_fields'] as Map?)?[k] == true;
          final c = (j['field_confidence'] as Map?)?[k];
          final pass = e && (c is num ? c >= 0.6 : false);
          final v = (j['extracted_info'] as Map?)?[k];
          return pass ? '$k=$v' : '';
        }
        outs.add(['subject', 'goal', 'level', 'tone_preference'].map(f).where((x) => x.isNotEmpty).join(', '));
      }
      // ignore: avoid_print
      print('[$label] "${u.length > 28 ? u.substring(0, 28) : u}" → 통과: ${outs.map((o) => '{$o}').join(' / ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
