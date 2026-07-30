import 'package:flutter_test/flutter_test.dart';

import 'package:research_chatbot/config/agent_prompts.dart';
import 'package:research_chatbot/models/instructional_design.dart';
import 'package:research_chatbot/models/learner_profile.dart';
import 'package:research_chatbot/models/learning_state.dart';

/// 수업 완료를 학습자에게 알리는 경로를 검증한다.
///
/// 완료는 `markCourseCompleted()`가 플래그만 바꾸므로, 학습자에게 전달되는
/// 창구는 (1) 완료 직후 튜터의 마무리 발화, (2) 그 뒤 발화를 받는 Analyst
/// 두 곳뿐이다. 둘 다 완료 상태를 알고 있어야 한다.
void main() {
  LearningState state({required bool completed, int stepIndex = 3}) {
    return LearningState(
      learnerProfile: LearnerProfile(
        subject: 'SESOI',
        goal: '피험자 수를 산정하는 법을 알아보는 것',
        level: LearnerLevel.intermediate,
      ),
      instructionalDesign: InstructionalDesign(
        syllabus: [
          for (var i = 1; i <= 4; i++)
            Step(step: i, topic: '주제$i', objective: '목표$i'),
        ],
      ),
      currentStepIndex: stepIndex,
      isCourseCompleted: completed,
    );
  }

  group('Tutor systemInstruction', () {
    test('완료되면 전 단계가 ✓이고 진행 중(▶) 단계가 없다', () {
      final prompt = AgentPrompts.tutorSystem(state(completed: true));
      // 튜터링 원칙 문장에도 ✓/▶ 글자가 있으므로 목차 줄만 본다.
      final marks = RegExp(r'^([✓▶○]) \d+\. ', multiLine: true)
          .allMatches(prompt)
          .map((m) => m[1])
          .toList();
      expect(marks, ['✓', '✓', '✓', '✓']);
      expect(prompt, contains('전 단계 완료'));
    });

    test('완료되면 마무리 지침이 붙는다', () {
      final prompt = AgentPrompts.tutorSystem(state(completed: true));
      expect(prompt, contains('마무리 지침'));
      expect(prompt, contains('수업이 끝났다는 사실을 분명한 문장으로 알려라'));
    });

    test('진행 중이면 마무리 지침이 없고 현재 단계가 ▶로 표시된다', () {
      final prompt = AgentPrompts.tutorSystem(state(completed: false, stepIndex: 1));
      expect(prompt, isNot(contains('마무리 지침')));
      expect(prompt, contains('▶ 2. 주제2'));
      expect(prompt, contains('2/4'));
    });
  });

  group('Analyst 프롬프트', () {
    test('완료 후에는 끝났다고 답하라는 지시가 들어간다', () {
      final prompt = AgentPrompts.analyst(state(completed: true), '그럼 수업은 끝?');
      expect(prompt, contains('모두 마쳤다'));
      expect(prompt, contains('끝났다고 분명히 답하라'));
      expect(prompt, contains('SESOI'));
    });

    test('완료 전에는 그 블록이 없다', () {
      final prompt = AgentPrompts.analyst(state(completed: false), '통계 배우고 싶어');
      expect(prompt, isNot(contains('직전 상황')));
      expect(prompt, isNot(contains('모두 마쳤다')));
    });
  });

  test('마무리 발화 트리거는 학습자 발화가 아닌 내부 지시문이다', () {
    // 세션에 저장되지 않는 합성 user 메시지. 완료 사실을 여기서 규정하지 않고
    // systemInstruction의 마무리 지침에 맡긴다.
    expect(AgentPrompts.courseClosingCue, contains('마무리'));
  });
}
