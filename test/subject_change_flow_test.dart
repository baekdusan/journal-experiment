import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// 주제가 바뀌면 이전 목표를 비우는 수정(2026-09-28 P003 버그)이
/// 대화 흐름을 막지 않는지, LLM 호출을 가짜로 바꿔 오케스트레이터를 실제로 돌려 확인한다.

LlmCallRecord _call(String agent) => LlmCallRecord(
      agent: agent,
      model: 'fake',
      location: 'fake',
      startedAt: DateTime(2026),
      completedAt: DateTime(2026),
      prompt: '',
    );

/// 발화별로 미리 정한 추출 결과를 돌려주는 Analyst.
class FakeAgent extends ConversationalAgentService {
  final Map<String, AnalystResult> script;
  final List<String> seen = [];
  FakeAgent(this.script);

  @override
  Future<AnalystResult> runAnalyst(LearningState state, String userText) async {
    seen.add(userText);
    return script[userText] ?? AnalystResult(response: '무엇을 배우고 싶으세요?');
  }
}

class FakeDesigner extends SyllabusDesignerService {
  final List<LearnerProfile> requests = [];

  @override
  Future<
      ({
        List<Step> syllabus,
        List<String> searchQueries,
        List<String> sources,
        String draft,
        List<LlmCallRecord> calls,
      })> generate(LearnerProfile profile, {String? redesignRequest}) async {
    requests.add(profile);
    return (
      syllabus: [
        Step(step: 1, topic: '${profile.subject} 1단계', objective: '목표 1'),
        Step(step: 2, topic: '${profile.subject} 2단계', objective: '목표 2'),
      ],
      searchQueries: <String>[],
      sources: <String>[],
      draft: 'draft',
      calls: [_call('designer.research')],
    );
  }
}

class FakeGemini extends GeminiService {
  @override
  Stream<String> streamResponse(
    List<Message> history,
    String userText, {
    String? systemInstruction,
    void Function(List<String> searchQueries, List<String> sources)? onGrounding,
    String agent = 'tutor',
    void Function(LlmCallRecord call)? onCallComplete,
  }) async* {
    yield '튜터 응답';
    onCallComplete?.call(_call(agent));
  }
}

class FakeStepProgress extends StepProgressService {
  @override
  Future<StepProgressResult> evaluate({
    required Step currentStep,
    required List<String> recentHistory,
  }) async =>
      StepProgressResult(stepCompleted: false, confidence: 0.0, call: _call('stepProgress'));
}

class FakeIntent extends IntentClassifierService {
  @override
  Future<IntentClassification> classify(String userText, {String? previousTutorMessage}) async =>
      IntentClassification(intent: IntentResult.inClass, call: _call('intent'));
}

/// 앱에서는 화면이 이 provider들을 구독해 살려 두므로, 테스트에서도 같은 구독을 건다.
/// (구독이 없으면 자동 폐기돼 "Ref after disposed" 오류가 난다.)
ProviderContainer _container([List<Override> overrides = const []]) {
  final c = ProviderContainer(overrides: overrides);
  c.listen(learningStateProvider, (_, __) {});
  c.listen(chatSessionsProvider, (_, __) {});
  c.listen(activeSessionIdProvider, (_, __) {});
  c.listen(activeSessionProvider, (_, __) {});
  c.listen(isProcessingProvider, (_, __) {});
  return c;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExperimentConfig.setCondition(ExperimentCondition.treatment);
  });

  AnalystResult extracted({String? subject, String? goal, LearnerLevel? level}) => AnalystResult(
        response: '분석 응답',
        subject: subject,
        goal: goal,
        level: level,
        fieldConfidence: const {},
        call: _call('analyst'),
      );

  /// '해시 함수' 수업을 방금 마친 상태를 만든다 (P003의 24턴 직전과 같은 상태).
  Future<({ProviderContainer c, FakeAgent agent, FakeDesigner designer})> completedCourse(
    Map<String, AnalystResult> script,
  ) async {
    final agent = FakeAgent(script);
    final designer = FakeDesigner();
    final c = _container([
      conversationalAgentServiceProvider.overrideWithValue(agent),
      syllabusDesignerServiceProvider.overrideWithValue(designer),
      geminiServiceProvider.overrideWithValue(FakeGemini()),
      stepProgressServiceProvider.overrideWithValue(FakeStepProgress()),
      intentClassifierServiceProvider.overrideWithValue(FakeIntent()),
    ]);
    addTearDown(c.dispose);
    final ls = c.read(learningStateProvider.notifier);
    await Future<void>.delayed(Duration.zero); // prefs 로드 대기
    await ls.updateFromExtractedInfo(
      subject: '해시 함수',
      goal: '해시 함수가 무엇인지 아는 것',
      level: LearnerLevel.beginner,
    );
    await ls.setSyllabus([Step(step: 1, topic: '해시', objective: 'o')]);
    await ls.markCourseCompleted();
    c.read(chatControllerProvider.notifier).startExperiment('PTEST');
    // startExperiment가 학습 상태를 초기화하므로 다시 세팅한다.
    await Future<void>.delayed(Duration.zero);
    await ls.updateFromExtractedInfo(
      subject: '해시 함수',
      goal: '해시 함수가 무엇인지 아는 것',
      level: LearnerLevel.beginner,
    );
    await ls.setSyllabus([Step(step: 1, topic: '해시', objective: 'o')]);
    await ls.markCourseCompleted();
    return (c: c, agent: agent, designer: designer);
  }

  /// 백그라운드 설계 + 자동 수업 시작까지 끝날 때까지 기다린다.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('상태 갱신 (learning_state_provider)', () {
    test('주제만 바뀌면 이전 목표가 비워진다', () async {
      final c = _container();
      addTearDown(c.dispose);
      final ls = c.read(learningStateProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await ls.updateFromExtractedInfo(
          subject: '해시 함수', goal: '해시 함수 이해', level: LearnerLevel.beginner);
      await ls.updateFromExtractedInfo(subject: '블록체인');
      final p = c.read(learningStateProvider).learnerProfile;
      expect(p.subject, '블록체인');
      expect(p.goal, isNull);
      expect(p.level, LearnerLevel.beginner, reason: '수준은 학습자 정보라 유지');
      expect(p.isLearnerProfileFilled, isFalse);
    });

    test('주제와 목표가 함께 바뀌면 새 목표가 들어간다', () async {
      final c = _container();
      addTearDown(c.dispose);
      final ls = c.read(learningStateProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await ls.updateFromExtractedInfo(
          subject: '해시 함수', goal: '해시 함수 이해', level: LearnerLevel.beginner);
      await ls.updateFromExtractedInfo(subject: '블록체인', goal: '블록체인 원리 이해');
      expect(c.read(learningStateProvider).learnerProfile.goal, '블록체인 원리 이해');
    });

    test('같은 주제를 다시 말하면 목표가 유지된다 (회귀 방지)', () async {
      final c = _container();
      addTearDown(c.dispose);
      final ls = c.read(learningStateProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await ls.updateFromExtractedInfo(
          subject: '블록체인', goal: '블록체인 원리 이해', level: LearnerLevel.beginner);
      await ls.updateFromExtractedInfo(subject: '블록체인');
      expect(c.read(learningStateProvider).learnerProfile.goal, '블록체인 원리 이해');
    });

    test('주제 없이 수준만 바뀌면 목표가 유지된다', () async {
      final c = _container();
      addTearDown(c.dispose);
      final ls = c.read(learningStateProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await ls.updateFromExtractedInfo(
          subject: '블록체인', goal: '블록체인 원리 이해', level: LearnerLevel.beginner);
      await ls.updateFromExtractedInfo(level: LearnerLevel.intermediate);
      expect(c.read(learningStateProvider).learnerProfile.goal, '블록체인 원리 이해');
    });
  });

  group('대화 흐름 (ChatController, LLM은 가짜)', () {
    test('수업 완료 후 주제만 바꾸면 설계 없이 되묻고, 다음 턴에 목표를 받으면 새 목표로 설계한다',
        () async {
      final s = await completedCourse({
        '블록체인 알려줘': extracted(subject: '블록체인'),
        '기본 원리를 알고 싶어': extracted(goal: '블록체인의 기본 원리 이해'),
      });
      final ctrl = s.c.read(chatControllerProvider.notifier);

      // 턴 1: 주제만 바뀜
      await ctrl.sendMessage('블록체인 알려줘');
      await settle();
      var st = s.c.read(learningStateProvider);
      expect(st.learnerProfile.subject, '블록체인');
      expect(st.learnerProfile.goal, isNull, reason: '옛 목표(해시 함수)가 남으면 안 된다');
      expect(st.isCourseCompleted, isFalse, reason: '새 주제로 넘어갔으니 완료 상태는 풀린다');
      expect(s.designer.requests, isEmpty, reason: '목표가 없으니 설계를 시작하지 않는다');
      final msgs1 = s.c.read(activeSessionProvider)!.messages;
      expect(msgs1.last.role, MessageRole.model, reason: 'Analyst 응답이 화면에 나간다');
      expect(msgs1.last.content, '분석 응답');

      // 턴 2: 목표를 말함 → Analyst로 라우팅 → 설계 시작
      await ctrl.sendMessage('기본 원리를 알고 싶어');
      await settle();
      expect(s.agent.seen, ['블록체인 알려줘', '기본 원리를 알고 싶어'],
          reason: '둘째 턴도 Analyst로 가야 한다 (튜터·피드백으로 새면 안 됨)');
      expect(s.designer.requests, hasLength(1), reason: '설계는 정확히 한 번');
      expect(s.designer.requests.single.subject, '블록체인');
      expect(s.designer.requests.single.goal, '블록체인의 기본 원리 이해');
      st = s.c.read(learningStateProvider);
      expect(st.instructionalDesign.syllabus.first.topic, '블록체인 1단계');
      expect(st.isDesigning, isFalse);
      final msgs2 = s.c.read(activeSessionProvider)!.messages;
      expect(msgs2.where((m) => m.role == MessageRole.system), isEmpty, reason: '오류 없음');
      expect(msgs2.last.content, '튜터 응답', reason: '설계 후 자동으로 수업이 시작된다');
    });

    test('주제와 목표를 한 턴에 말하면 추가 질문 없이 바로 새 목표로 설계한다', () async {
      final s = await completedCourse({
        '스마트 컨트랙트 작동 원리': extracted(
            subject: '스마트 컨트랙트', goal: '스마트 컨트랙트의 작동 원리 이해'),
      });
      await s.c.read(chatControllerProvider.notifier).sendMessage('스마트 컨트랙트 작동 원리');
      await settle();
      expect(s.designer.requests, hasLength(1));
      expect(s.designer.requests.single.goal, '스마트 컨트랙트의 작동 원리 이해',
          reason: 'P003 36턴: 예전에는 해시 함수 목표로 설계됐다');
    });

    test('수업 완료 후 새 주제를 말하지 않으면 설계도, 목표 변경도 없다', () async {
      final s = await completedCourse({
        '혹시 다른 수업도 돼?': extracted(),
      });
      await s.c.read(chatControllerProvider.notifier).sendMessage('혹시 다른 수업도 돼?');
      await settle();
      final st = s.c.read(learningStateProvider);
      expect(s.designer.requests, isEmpty);
      expect(st.learnerProfile.goal, '해시 함수가 무엇인지 아는 것');
      expect(st.isCourseCompleted, isTrue);
    });
  });
}
