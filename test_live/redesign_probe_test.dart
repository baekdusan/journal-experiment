// 재설계 경로 탐침: 수업 중 발화가 의도 분류 → 피드백 판정을 거쳐 재설계로 가는지 실제 모델로 확인. (정규 테스트 아님)
import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart' show Schema;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:research_chatbot/config/agent_prompts.dart';
import 'package:research_chatbot/models/instructional_design.dart';
import 'package:research_chatbot/models/learner_profile.dart';
import 'package:research_chatbot/models/learning_state.dart';

void main() {
  test('redesign probe', () async {
    final token = Platform.environment['VERTEX_TOKEN']!;
    final url = Uri.parse('https://us-central1-aiplatform.googleapis.com/v1/projects/addie-tutor/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent');
    Future<Map> call(String prompt, Schema schema, double t) async {
      final r = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
            'generationConfig': {'responseMimeType': 'application/json', 'responseSchema': schema.toJson(), 'temperature': t}}));
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return jsonDecode(d['candidates'][0]['content']['parts'].map((p) => p['text']).join()) as Map;
    }
    final state = LearningState(
      learnerProfile: LearnerProfile(subject: '블록체인', goal: '블록체인의 기본 개념 이해', level: LearnerLevel.beginner),
      instructionalDesign: InstructionalDesign.empty().copyWith(syllabus: [
        Step(step: 1, topic: '블록체인의 정의와 등장 배경', objective: '블록체인이 무엇인지 설명할 수 있다'),
        Step(step: 2, topic: '블록과 해시', objective: '블록 구조와 해시 연결을 이해한다'),
        Step(step: 3, topic: '합의 알고리즘', objective: 'PoW와 PoS를 비교할 수 있다'),
      ]),
      currentStepIndex: 1,
    );
    const prevTutor = '블록은 거래 기록 묶음과 이전 블록의 해시로 이뤄져요. 그럼 블록 안의 데이터를 바꾸면 해시는 어떻게 될까요?';
    final intentSchema = Schema.object(properties: {'intent': Schema.enumString(enumValues: ['out_of_class', 'in_class'], description: '사용자 발화 의도 분류')});
    final fbSchema = Schema.object(properties: {
      'profile_update': Schema.object(properties: {
        'level': Schema.enumString(enumValues: ['beginner', 'intermediate', 'expert'], description: '수준 변경 요청'),
        'tone_preference': Schema.enumString(enumValues: ['kind', 'formal', 'casual'], description: '말투 변경 요청'),
      }, optionalProperties: ['level', 'tone_preference']),
      'response': Schema.string(description: '피드백 수용 응답'),
      'needs_redesign': Schema.boolean(description: '재설계 필요 여부'),
      'explicit_change': Schema.boolean(description: '변경 요청이 명시적으로 존재'),
      'redesign_request': Schema.string(description: '재설계에 반영할 구체적 요청'),
    }, optionalProperties: ['redesign_request']);
    final utterances = [
      '너무 어려워. 더 쉬운 내용으로 수업 계획을 처음부터 다시 짜줘',
      '해시는 이미 알아. 커리큘럼을 바꿔서 스마트 컨트랙트 위주로 해줘',
      '그럼 이제 합의 알고리즘에 대해 설명해줘',
      '이 단계는 건너뛰고 다음으로 가자',
      '말투 좀 더 편하게 해줘',
    ];
    for (final u in utterances) {
      final i = await call(AgentPrompts.intentClassifier(u, prevTutor), intentSchema, 0.0);
      var line = '"$u"\n    의도=${i['intent']}';
      if (i['intent'] == 'out_of_class') {
        final history = ['Tutor: $prevTutor'];
        final f = await call(AgentPrompts.feedback(state, u, history), fbSchema, 0.3);
        final go = f['needs_redesign'] == true && f['explicit_change'] == true;
        line += ' → 피드백: 재설계필요=${f['needs_redesign']} 명시변경=${f['explicit_change']} → ${go ? '★ 재설계 실행' : '재설계 안 함'}';
      } else {
        line += ' → 튜터가 수업 안에서 처리';
      }
      // ignore: avoid_print
      print(line);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
