import 'package:flutter_test/flutter_test.dart';

import 'package:research_chatbot/models/chat_session.dart';
import 'package:research_chatbot/models/instructional_design.dart';
import 'package:research_chatbot/models/learner_profile.dart';
import 'package:research_chatbot/models/learning_state.dart';
import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/models/state_change_event.dart';
import 'package:research_chatbot/models/telemetry.dart';
import 'package:research_chatbot/services/session_export_service.dart';

/// 내보내기 v3가 세션·학습 상태·텔레메트리를 빠짐없이 싣고,
/// 요약(단계별 소요·턴별 읽기/작성 시간)을 올바르게 계산하는지 확인한다.
void main() {
  final t0 = DateTime(2026, 9, 25, 14, 0, 0);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  final syllabus = [
    Step(step: 1, topic: '기초', objective: '기초 이해'),
    Step(step: 2, topic: '심화', objective: '심화 이해'),
  ];

  ChatSession session() => ChatSession(
        id: 's1',
        title: '파이썬 배우고 싶어',
        createdAt: at(1),
        messages: [
          Message(
            id: 'u1',
            role: MessageRole.user,
            content: '파이썬 배우고 싶어',
            timestamp: at(5),
            meta: const {'turn': 1},
          ),
          Message(
            id: 'm1',
            role: MessageRole.model,
            content: '좋아요',
            timestamp: at(8),
            meta: const {'agent': 'analyst', 'turn': 1},
          ),
          Message(
            id: 'sys',
            role: MessageRole.system,
            content: '오류',
            timestamp: at(9),
            meta: const {'kind': 'error', 'flow': 'tutor'},
          ),
        ],
        stateChanges: [
          StateChangeEvent(
            id: 'e1',
            timestamp: at(10),
            type: StateChangeType.syllabusGenerated,
            changes: {'stepCount': 2, 'steps': []},
          ),
          StateChangeEvent(
            id: 'e2',
            timestamp: at(70),
            type: StateChangeType.stepAdvanced,
            changes: {'from': 0, 'to': 1},
          ),
          StateChangeEvent(
            id: 'e3',
            timestamp: at(130),
            type: StateChangeType.courseCompleted,
            changes: {'completedAtStep': 1},
          ),
        ],
      );

  LearningState finalState() => LearningState(
        learnerProfile: LearnerProfile(subject: '파이썬', goal: '기초', level: LearnerLevel.beginner),
        instructionalDesign: InstructionalDesign(syllabus: syllabus),
        isCourseCompleted: true,
        currentStepIndex: 1,
      );

  SessionTelemetry telemetry() => SessionTelemetry(
        participant: ParticipantInfo(name: 'P07', startedAt: t0, station: 'A'),
        environment: const {'platform': 'test'},
        turns: [
          TurnRecord(
            turn: 1,
            sentAt: at(5),
            userText: '파이썬 배우고 싶어',
            compose: ComposeMeta(firstKeyAt: at(3), editCount: 9, maxLength: 9),
            previousResponseCompletedAt: t0,
            route: 'analyst',
            stepIndexBefore: 0,
            responseStartedAt: at(5),
            firstChunkAt: at(6),
            responseCompletedAt: at(8),
            responseChars: 3,
          ),
          TurnRecord(
            turn: 2,
            sentAt: at(60),
            userText: '다음',
            route: 'tutor',
            intent: 'inClass',
            stepIndexBefore: 0,
            stepIndexAfter: 1,
          ),
          TurnRecord(
            turn: 3,
            sentAt: at(120),
            userText: '끝',
            route: 'tutor',
            stepIndexBefore: 1,
          ),
        ],
        llmCalls: [
          LlmCallRecord(
            id: 'c1',
            turn: 1,
            agent: 'analyst',
            model: 'gemini-2.5-flash',
            location: 'us-central1',
            startedAt: at(5),
            completedAt: at(7),
            promptTokenCount: 100,
            candidatesTokenCount: 20,
            totalTokenCount: 120,
            prompt: 'p',
            responseText: '{}',
          ),
          LlmCallRecord(
            id: 'c2',
            turn: 2,
            agent: 'tutor',
            model: 'gemini-3.5-flash',
            location: 'global',
            streaming: true,
            startedAt: at(60),
            firstChunkAt: at(61),
            completedAt: at(65),
            chunkCount: 12,
            totalTokenCount: 300,
            prompt: '다음',
            error: 'boom',
          ),
        ],
        flowEvents: [
          FlowEvent(name: 'intent', data: const {'value': 'inClass'}, turn: 2),
          FlowEvent(name: 'tutor.error', data: const {'error': 'boom'}, turn: 2),
        ],
        uiEvents: [
          UiEvent(type: 'visibility', data: const {'state': 'hidden'}, timestamp: at(20)),
          UiEvent(type: 'visibility', data: const {'state': 'visible'}, timestamp: at(35)),
          UiEvent(type: 'scroll', timestamp: at(40)),
          UiEvent(type: 'jump_to_bottom', timestamp: at(41)),
        ],
        exportCount: 1,
      );

  test('최상위 섹션이 모두 실린다', () {
    final data = SessionExportService().buildExportData(
      session(),
      finalState(),
      telemetry(),
    );
    expect(data['exportVersion'], '3.0');
    for (final key in [
      'experiment',
      'participant',
      'environment',
      'session',
      'summary',
      'finalLearningState',
      'turns',
      'messages',
      'llmCalls',
      'flowEvents',
      'stateChanges',
      'uiEvents',
      'timeline',
    ]) {
      expect(data.containsKey(key), isTrue, reason: key);
    }
    expect((data['participant'] as Map)['name'], 'P07');
    expect((data['participant'] as Map)['station'], 'A');
    // system 메시지·stepAdvanced·courseCompleted가 더 이상 걸러지지 않는다.
    expect((data['messages'] as List).length, 3);
    expect((data['stateChanges'] as List).length, 3);
    expect((data['llmCalls'] as List).length, 2);
  });

  test('턴 요약: 읽기·작성·지연 시간이 계산된다', () {
    final data = SessionExportService().buildExportData(
      session(),
      finalState(),
      telemetry(),
    );
    final turn1 = (data['turns'] as List).first as Map;
    expect(turn1['tSinceStartMs'], 5000);
    expect(turn1['readingMs'], 3000); // t0 → firstKeyAt(3s)
    expect(turn1['composeMs'], 2000); // firstKeyAt(3s) → sentAt(5s)
    expect(turn1['sinceResponseMs'], 5000);
    expect(turn1['timeToFirstChunkMs'], 1000);
    expect(turn1['latencyMs'], 3000);
  });

  test('요약: 단계별 소요 시간·턴 수, 토큰, 오류, 탭 이탈이 집계된다', () {
    final data = SessionExportService().buildExportData(
      session(),
      finalState(),
      telemetry(),
    );
    final summary = data['summary'] as Map;
    expect(summary['turnCount'], 3);
    expect((summary['routes'] as Map)['tutor'], 2);
    expect((summary['messages'] as Map)['system'], 1);

    final calls = summary['llmCalls'] as Map;
    expect(calls['count'], 2);
    expect(calls['errors'], 1);
    expect((calls['tokens'] as Map)['total'], 420);
    expect(((calls['byAgent'] as Map)['tutor'] as Map)['count'], 1);
    expect(summary['errors'], 1);

    final steps = (summary['course'] as Map)['stepTimeline'] as List;
    expect(steps.length, 2);
    expect((steps[0] as Map)['durationMs'], 60000); // 10s → 70s
    expect((steps[0] as Map)['turns'], 2); // stepIndexBefore == 0 인 턴
    expect((steps[1] as Map)['durationMs'], 60000); // 70s → 130s
    expect((steps[1] as Map)['completed'], isTrue);

    final attention = summary['attention'] as Map;
    expect(attention['tabHiddenCount'], 1);
    expect(attention['tabHiddenMs'], 15000);
    expect(attention['jumpToBottomClicks'], 1);
  });
}
