import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/config/experiment_config.dart';
import 'package:research_chatbot/models/chat_session.dart';
import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/models/telemetry.dart';
import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/providers/telemetry_provider.dart';
import 'package:research_chatbot/screens/chat_screen.dart';
import 'package:research_chatbot/screens/start_screen.dart';
import 'package:research_chatbot/services/session_persistence_service.dart';

/// 자동 저장: 대화·기록이 바뀌면 저장되고, 페이지가 다시 열리면 이어서 진행할 수 있다.
void main() {
  SessionSnapshot sample({bool exported = false, bool lostReply = true}) {
    final t0 = DateTime(2026, 9, 27, 18, 0);
    return SessionSnapshot(
      savedAt: DateTime.now(),
      condition: ExperimentCondition.control,
      station: 'B',
      turnCounter: 2,
      exported: exported,
      session: ChatSession(
        id: 's-restore',
        title: '블록체인',
        createdAt: t0,
        messages: [
          Message(id: 'u1', role: MessageRole.user, content: '블록체인 알려줘', timestamp: t0),
          Message(id: 'm1', role: MessageRole.model, content: '블록체인은…', timestamp: t0),
          Message(id: 'u2', role: MessageRole.user, content: '더 자세히', timestamp: t0),
          if (lostReply)
            Message(id: 'm2', role: MessageRole.model, content: '', isStreaming: true),
        ],
      ),
      telemetry: SessionTelemetry(
        participant: ParticipantInfo(name: 'P002', displayName: '박도현', startedAt: t0),
        turns: [
          TurnRecord(turn: 1, sentAt: t0, userText: '블록체인 알려줘', route: 'freeform'),
          TurnRecord(turn: 2, sentAt: t0, userText: '더 자세히', route: 'freeform'),
        ],
        llmCalls: [
          LlmCallRecord(
            id: 'c1', turn: 1, agent: 'freeform', model: 'gemini-3.5-flash',
            location: 'global', streaming: true, startedAt: t0, completedAt: t0,
            prompt: '블록체인 알려줘', responseText: '블록체인은…', totalTokenCount: 100,
          ),
        ],
        uiEvents: [UiEvent(type: 'experiment.start', timestamp: t0)],
      ),
    );
  }

  test('스냅샷은 JSON으로 왕복해도 같은 내용이다', () {
    final s = sample();
    final back = SessionSnapshot.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(back.condition, ExperimentCondition.control);
    expect(back.turnCounter, 2);
    expect(back.session.messages.length, 4);
    expect(back.session.messages[3].isStreaming, isTrue);
    expect(back.telemetry.participant?.displayName, '박도현');
    expect(back.telemetry.turns.length, 2);
    expect(back.telemetry.llmCalls.single.totalTokenCount, 100);
    expect(back.telemetry.uiEvents.single.type, 'experiment.start');
    expect(back.isResumable, isTrue);
    expect(sample(exported: true).isResumable, isFalse);
  });

  testWidgets('저장본이 있으면 시작 화면에 이어서 진행 카드가 뜨고, 누르면 대화가 복원된다',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SessionPersistenceService().save(sample());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StartScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resume-card')), findsOneWidget);
    expect(find.textContaining('박도현'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resume-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(ExperimentConfig.isControl, isTrue);
    final session = container.read(activeSessionProvider)!;
    // 끊길 때 응답 중이던 빈 말풍선은 사라지고, 응답 유실 안내가 붙는다.
    expect(session.messages.where((m) => m.isStreaming), isEmpty);
    expect(session.messages.last.role, MessageRole.system);
    expect(session.messages.last.meta['kind'], 'restored');
    expect(session.messages.where((m) => m.role == MessageRole.user).length, 2);
    final tele = container.read(telemetryProvider);
    expect(tele.participant?.name, 'P002');
    expect(tele.uiEvents.map((e) => e.type), contains('session.restored'));
  });

  testWidgets('저장 버튼을 누른 세션은 복구 카드가 뜨지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SessionPersistenceService().save(sample(exported: true));
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: StartScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-card')), findsNothing);
  });

  testWidgets('세션이 바뀌면 스냅샷이 자동으로 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StartScreen()),
    ));
    await tester.enterText(find.byKey(const ValueKey('participant-name')), 'P05');
    await tester.tap(find.text('그룹 A'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();

    // 실제 전송 없이 세션에 메시지를 넣는다 (LLM 호출 없이 저장 경로만 확인).
    container.read(chatSessionsProvider.notifier).addSession(
          ChatSession(id: 'live', title: 't', messages: [
            Message(role: MessageRole.user, content: '안녕'),
          ]),
        );
    await tester.pump(const Duration(milliseconds: 600));

    final saved = await SessionPersistenceService().load();
    expect(saved, isNotNull);
    expect(saved!.session.messages.single.content, '안녕');
    expect(saved.participant?.name, 'P05');
    expect(saved.condition, ExperimentCondition.treatment);
  });
}
