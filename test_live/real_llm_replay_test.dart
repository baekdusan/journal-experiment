// 실제 LLM 재현 하네스 — 정규 `flutter test`에는 포함되지 않는다 (test/ 밖).
//
//   VERTEX_TOKEN=$(...) flutter test test_live/real_llm_replay_test.dart
//
// 앱의 ChatController·AgentPrompts·상태 관리·게이트 로직은 그대로 쓰고,
// LLM 호출만 같은 프롬프트·모델·location·스키마·temperature로 Vertex AI REST에 보낸다.
// (firebase_ai는 브라우저에서만 초기화되므로 VM 테스트에서는 REST로 대체한다.)
// 서비스별 스키마·파싱은 lib/services/*의 사본이다. 서비스를 고치면 여기도 맞춘다.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart' show Schema;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/config/agent_prompts.dart';
import 'package:research_chatbot/config/ai_models.dart';
import 'package:research_chatbot/config/experiment_config.dart';
import 'package:research_chatbot/models/instructional_design.dart';
import 'package:research_chatbot/models/learner_profile.dart';
import 'package:research_chatbot/models/learning_state.dart';
import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/models/telemetry.dart';
import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/providers/learning_state_provider.dart';
import 'package:research_chatbot/services/conversational_agent_service.dart';
import 'package:research_chatbot/services/gemini_service.dart';
import 'package:research_chatbot/services/intent_classifier_service.dart';
import 'package:research_chatbot/services/step_progress_service.dart';
import 'package:research_chatbot/services/syllabus_designer_service.dart';

final _token = Platform.environment['VERTEX_TOKEN'] ?? '';
const _project = 'addie-tutor';
final _log = StringBuffer();
void _say(String s) {
  _log.writeln(s);
  // ignore: avoid_print
  print(s);
}

LlmCallRecord _rec(String agent, ModelSpec spec, DateTime t0) => LlmCallRecord(
      agent: agent,
      model: spec.model,
      location: spec.location,
      startedAt: t0,
      completedAt: DateTime.now(),
      prompt: '',
    );

/// Vertex AI generateContent (REST). 429/503은 앱과 같이 1·2·4초 재시도.
Future<({String text, List<String> queries})> _vertex({
  required ModelSpec spec,
  required List<Map<String, dynamic>> contents,
  String? system,
  Map<String, dynamic>? generationConfig,
  bool googleSearch = false,
}) async {
  final host = spec.location == 'global'
      ? 'aiplatform.googleapis.com'
      : '${spec.location}-aiplatform.googleapis.com';
  final url = Uri.parse('https://$host/v1/projects/$_project/locations/${spec.location}'
      '/publishers/google/models/${spec.model}:generateContent');
  final body = {
    'contents': contents,
    if (system != null) 'systemInstruction': {'parts': [{'text': system}]},
    if (generationConfig != null) 'generationConfig': generationConfig,
    if (googleSearch) 'tools': [{'googleSearch': {}}],
  };
  for (var attempt = 1; ; attempt++) {
    final res = await http.post(url,
        headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
        body: jsonEncode(body));
    if ((res.statusCode == 429 || res.statusCode == 503) && attempt < 4) {
      await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      continue;
    }
    if (res.statusCode != 200) throw Exception('Vertex ${res.statusCode}: ${res.body}');
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cand = (d['candidates'] as List).first as Map<String, dynamic>;
    final parts = ((cand['content'] as Map?)?['parts'] as List?) ?? const [];
    final text = parts.map((p) => (p as Map)['text'] ?? '').join();
    final gm = cand['groundingMetadata'] as Map?;
    final queries = ((gm?['webSearchQueries'] as List?) ?? const []).cast<String>();
    return (text: text, queries: queries);
  }
}

Map<String, dynamic> _json(Schema schema, double temperature) => {
      'responseMimeType': 'application/json',
      'responseSchema': schema.toJson(),
      'temperature': temperature,
    };

List<Map<String, dynamic>> _user(String text) => [
      {'role': 'user', 'parts': [{'text': text}]}
    ];

String? _norm(String? v) {
  if (v == null) return null;
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return null;
  return t;
}

// ── 서비스 (프롬프트는 앱의 AgentPrompts 그대로) ─────────────────────────

class LiveIntent extends IntentClassifierService {
  @override
  Future<IntentClassification> classify(String userText, {String? previousTutorMessage}) async {
    final t0 = DateTime.now();
    final schema = Schema.object(properties: {
      'intent': Schema.enumString(enumValues: ['out_of_class', 'in_class'], description: '사용자 발화 의도 분류'),
    });
    final r = await _vertex(
      spec: AiModels.extractor,
      contents: _user(AgentPrompts.intentClassifier(userText, previousTutorMessage)),
      generationConfig: _json(schema, 0.0),
    );
    final v = (jsonDecode(r.text) as Map)['intent'] as String?;
    return IntentClassification(
      intent: v == null ? IntentResult.inClass : IntentResult.fromJson(v),
      call: _rec('intent', AiModels.extractor, t0),
    );
  }
}

class LiveAgent extends ConversationalAgentService {
  final List<Map<String, dynamic>> analystLog = [];

  @override
  Future<AnalystResult> runAnalyst(LearningState state, String userText) async {
    final t0 = DateTime.now();
    Schema fields(Schema Function(String) f) => Schema.object(properties: {
          'subject': f('subject'),
          'goal': f('goal'),
          'level': f('level'),
          'tone_preference': f('tone_preference'),
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
    final r = await _vertex(
      spec: AiModels.extractor,
      contents: _user(AgentPrompts.analyst(state, userText)),
      generationConfig: _json(schema, 0.0),
    );
    final data = jsonDecode(r.text) as Map<String, dynamic>;
    final ex = (data['extracted_info'] as Map?)?.cast<String, dynamic>() ?? {};
    final exp = (data['explicit_fields'] as Map?)?.cast<String, dynamic>() ?? {};
    final cr = (data['field_confidence'] as Map?)?.cast<String, dynamic>() ?? {};
    final conf = {
      for (final k in const ['subject', 'goal', 'level', 'tone_preference'])
        k: cr[k] is num ? (cr[k] as num).toDouble().clamp(0.0, 1.0) : 0.0,
    };
    bool pass(String f) => (exp[f] as bool? ?? false) && (conf[f] ?? 0) >= 0.6; // 앱과 같은 이중 게이트
    analystLog.add({'utterance': userText, 'raw': ex, 'explicit': exp, 'conf': conf});
    return AnalystResult(
      response: data['response'] as String? ?? '',
      subject: pass('subject') ? _norm(ex['subject'] as String?) : null,
      goal: pass('goal') ? _norm(ex['goal'] as String?) : null,
      level: pass('level') && _norm(ex['level'] as String?) != null
          ? LearnerLevel.values.byName(ex['level'] as String)
          : null,
      tonePreference: pass('tone_preference') && _norm(ex['tone_preference'] as String?) != null
          ? TonePreference.values.byName(ex['tone_preference'] as String)
          : null,
      fieldConfidence: conf,
      rawExtracted: ex,
      rawExplicit: exp,
      call: _rec('analyst', AiModels.extractor, t0),
    );
  }

  @override
  Future<FeedbackResult> runFeedback(LearningState state, String userText, List<String> history) async {
    final t0 = DateTime.now();
    final schema = Schema.object(properties: {
      'profile_update': Schema.object(properties: {
        'level': Schema.enumString(enumValues: ['beginner', 'intermediate', 'expert'], description: '수준 변경 요청'),
        'tone_preference': Schema.enumString(enumValues: ['kind', 'formal', 'casual'], description: '말투 변경 요청'),
      }, optionalProperties: ['level', 'tone_preference']),
      'response': Schema.string(description: '피드백 수용 응답'),
      'needs_redesign': Schema.boolean(description: '재설계 필요 여부'),
      'explicit_change': Schema.boolean(description: '변경 요청이 명시적으로 존재'),
      'redesign_request': Schema.string(description: '재설계에 반영할 구체적 요청'),
    }, optionalProperties: ['redesign_request']);
    final r = await _vertex(
      spec: AiModels.extractor,
      contents: _user(AgentPrompts.feedback(state, userText, history)),
      generationConfig: _json(schema, 0.3),
    );
    final d = jsonDecode(r.text) as Map<String, dynamic>;
    return FeedbackResult(
      response: d['response'] as String? ?? '',
      needsRedesign: d['needs_redesign'] as bool? ?? false,
      explicitChange: d['explicit_change'] as bool? ?? false,
      redesignRequest: _norm(d['redesign_request'] as String?),
      call: _rec('feedback', AiModels.extractor, t0),
    );
  }
}

class LiveDesigner extends SyllabusDesignerService {
  final List<({LearnerProfile profile, List<String> topics})> runs = [];

  @override
  Future<({List<Step> syllabus, List<String> searchQueries, List<String> sources, String draft, List<LlmCallRecord> calls})>
      generate(LearnerProfile profile, {String? redesignRequest}) async {
    final t0 = DateTime.now();
    final research = await _vertex(
      spec: AiModels.designer,
      contents: _user(AgentPrompts.syllabusResearch(profile, redesignRequest: redesignRequest)),
      generationConfig: {'temperature': 0.3},
      googleSearch: true,
    );
    final schema = Schema.object(properties: {
      'syllabus': Schema.array(
        items: Schema.object(properties: {
          'step': Schema.integer(description: '단계 번호'),
          'topic': Schema.string(description: '단계 소주제'),
          'objective': Schema.string(description: '단계 학습 목표'),
        }),
        description: '1~5개 단계 배열',
      ),
    });
    final s = await _vertex(
      spec: AiModels.extractor,
      contents: _user(AgentPrompts.syllabusStructure(research.text)),
      generationConfig: _json(schema, 0.0),
    );
    final list = ((jsonDecode(s.text) as Map)['syllabus'] as List)
        .map((e) => Step.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    runs.add((profile: profile, topics: list.map((e) => e.topic).toList()));
    return (
      syllabus: list,
      searchQueries: research.queries,
      sources: <String>[],
      draft: research.text,
      calls: [_rec('designer.research', AiModels.designer, t0)],
    );
  }
}

class LiveStep extends StepProgressService {
  @override
  Future<StepProgressResult> evaluate({required Step currentStep, required List<String> recentHistory}) async {
    final t0 = DateTime.now();
    final schema = Schema.object(properties: {
      'step_completed': Schema.boolean(description: '현재 단계 학습목표가 충분히 다뤄져 다음 단계로 넘어가도 되는가'),
      'confidence': Schema.number(description: '판정 확신도 (0.0~1.0)'),
    });
    final r = await _vertex(
      spec: AiModels.extractor,
      contents: _user(AgentPrompts.stepProgress(currentStep: currentStep, recentHistory: recentHistory)),
      generationConfig: _json(schema, 0.0),
    );
    final d = jsonDecode(r.text) as Map<String, dynamic>;
    final c = d['confidence'];
    return StepProgressResult(
      stepCompleted: d['step_completed'] as bool? ?? false,
      confidence: (c is num ? c.toDouble() : 0.0).clamp(0.0, 1.0),
      call: _rec('stepProgress', AiModels.extractor, t0),
    );
  }
}

class LiveTutor extends GeminiService {
  @override
  Stream<String> streamResponse(
    List<Message> history,
    String userText, {
    String? systemInstruction,
    void Function(List<String> searchQueries, List<String> sources)? onGrounding,
    String agent = 'tutor',
    void Function(LlmCallRecord call)? onCallComplete,
  }) async* {
    final t0 = DateTime.now();
    final contents = [
      for (final m in history)
        {'role': m.role == MessageRole.user ? 'user' : 'model', 'parts': [{'text': m.content}]},
      {'role': 'user', 'parts': [{'text': userText}]},
    ];
    final r = await _vertex(spec: AiModels.tutor, contents: contents, system: systemInstruction, googleSearch: true);
    yield r.text;
    onCallComplete?.call(_rec(agent, AiModels.tutor, t0));
  }
}

// ── 재현 ────────────────────────────────────────────────────────────

void main() {
  test('P003 발화 재현 (실제 LLM)', () async {
    if (_token.isEmpty) {
      markTestSkipped('VERTEX_TOKEN 없음');
      return;
    }
    SharedPreferences.setMockInitialValues({});
    ExperimentConfig.setCondition(ExperimentCondition.treatment);
    final agent = LiveAgent();
    final designer = LiveDesigner();
    final c = ProviderContainer(overrides: <Override>[
      conversationalAgentServiceProvider.overrideWithValue(agent),
      syllabusDesignerServiceProvider.overrideWithValue(designer),
      geminiServiceProvider.overrideWithValue(LiveTutor()),
      stepProgressServiceProvider.overrideWithValue(LiveStep()),
      intentClassifierServiceProvider.overrideWithValue(LiveIntent()),
    ]);
    addTearDown(c.dispose);
    c.listen(learningStateProvider, (_, _) {});
    c.listen(chatSessionsProvider, (_, _) {});
    c.listen(activeSessionIdProvider, (_, _) {});
    c.listen(activeSessionProvider, (_, _) {});
    c.listen(isProcessingProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final ctrl = c.read(chatControllerProvider.notifier);
    ctrl.startExperiment('LIVE');

    var shown = 0;
    Future<void> send(String text) async {
      await ctrl.sendMessage(text);
      while (c.read(isProcessingProvider)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final msgs = c.read(activeSessionProvider)!.messages;
      for (final m in msgs.skip(shown)) {
        final who = m.role == MessageRole.user ? '학습자' : '${m.meta['agent'] ?? m.role.name}';
        _say('[$who] ${m.content.replaceAll('\n', ' ')}');
      }
      shown = msgs.length;
      final st = c.read(learningStateProvider);
      final p = st.learnerProfile;
      _say('    ⟶ 주제=${p.subject} | 목표=${p.goal} | 수준=${p.level?.name} | '
          '단계=${st.instructionalDesign.syllabus.isEmpty ? '-' : '${st.currentStepIndex + 1}/${st.totalSteps}'} | 완료=${st.isCourseCompleted}');
    }

    Future<void> finishCourse() async {
      for (var i = 0; i < 14 && !c.read(learningStateProvider).isCourseCompleted; i++) {
        await send('이해했어. 다음 단계로 넘어가자');
      }
    }

    void section(String s) => _say('\n════ $s ════');

    section('1. 처음 시작 — 목표를 몇 번 묻는가 (예전: 6턴째에 설계 시작)');
    final opening = [
      '블록체인에 대해 학습하려고 해. 관련된 내용을 알려줄래?',
      '방금 퀴즈를 풀었는데, 내가 애초에 처음 공부해봐서. 다양한 내용들을 배우고 싶어',
      '갠념을 학습하고 싶다니깐. 비트코인이랑 관련 있는거지?',
      '블록체인의특징이 뭐야? 무결성 뭐 이런 특징이 있지 않아?',
      '퀴즈를 풀어야 한다니깐',
      '블록체인이 기본적으로 어떤 원리로 동작하는지 알고 싶어',
    ];
    var designAt = 0;
    for (var i = 0; i < opening.length; i++) {
      await send(opening[i]);
      if (designer.runs.isNotEmpty) {
        designAt = i + 1;
        break;
      }
    }
    _say('    ★ 설계 시작: ${designAt == 0 ? '6턴 안에 시작 안 됨' : '$designAt턴째'}');
    _say('    ★ 커리큘럼: ${designer.runs.isEmpty ? '-' : designer.runs.last.topics}');
    await finishCourse();

    section('2. 수업 완료 후 "해시 함수" — 주제·목표가 한 번에 잡히는가');
    final before2 = designer.runs.length;
    await send('해시 함수 이런게 뭔지도 궁금해 블록체인과 관련해서');
    if (designer.runs.length == before2) await send('해시 함수가 블록체인에서 어떻게 쓰이는지 알고 싶어');
    _say('    ★ 설계 입력: 주제=${designer.runs.last.profile.subject} / 목표=${designer.runs.last.profile.goal}');
    _say('    ★ 커리큘럼: ${designer.runs.last.topics}');
    await finishCourse();

    section('3. 주제만 "블록체인"으로 — 옛 목표(해시 함수)가 남지 않는가 (예전 버그)');
    final before3 = designer.runs.length;
    await send('해시함수 말고 블록체인 학습에 중요한 또 다른 개념들은 뭐가 있어?');
    if (designer.runs.length == before3) {
      _say('    ★ 설계 보류 — 목표 확인 중 (옛 목표로 바로 설계하지 않음)');
      await send('블록체인 전반의 중요한 개념들을 알고 싶어');
    }
    _say('    ★ 설계 입력: 주제=${designer.runs.last.profile.subject} / 목표=${designer.runs.last.profile.goal}');
    _say('    ★ 커리큘럼: ${designer.runs.last.topics}');
    await finishCourse();

    section('4. "스마트 컨트랙트 작동 원리" — 커리큘럼에 해시 함수 단계가 끼지 않는가 (예전 버그)');
    final before4 = designer.runs.length;
    await send('스마트 컨트랙트 작동 원리');
    if (designer.runs.length == before4) await send('스마트 컨트랙트가 어떻게 동작하는지 알고 싶어');
    _say('    ★ 설계 입력: 주제=${designer.runs.last.profile.subject} / 목표=${designer.runs.last.profile.goal}');
    _say('    ★ 커리큘럼: ${designer.runs.last.topics}');

    _say('\n════ Analyst 원 추출값 ════');
    for (final a in agent.analystLog) {
      _say('  "${(a['utterance'] as String).substring(0, (a['utterance'] as String).length.clamp(0, 30))}" → '
          'goal=${(a['raw'] as Map)['goal']} (explicit=${(a['explicit'] as Map)['goal']}, conf=${(a['conf'] as Map)['goal']})');
    }
    File(Platform.environment['REPLAY_OUT'] ?? 'build/live_replay.txt').writeAsStringSync(_log.toString());
  }, timeout: const Timeout(Duration(minutes: 40)));
}
