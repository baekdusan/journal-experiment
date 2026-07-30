import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/models/chat_session.dart';
import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/providers/streaming_message_provider.dart';
import 'package:research_chatbot/widgets/chat_view.dart';
import 'package:research_chatbot/widgets/message_bubble.dart';

/// Gemini식 스크롤 모델 검증:
/// 질문은 화면 맨 위로 고정되고, 스트리밍은 따라 내려가지 않고,
/// 아래에 남은 내용이 있으면 "맨 아래로" 화살표가 뜬다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sessionId = 's1';
  const viewport = Size(900, 600);

  /// 화면을 넘치도록 긴 이전 대화.
  List<Message> priorConversation() => [
        for (var i = 0; i < 6; i++)
          Message(
            id: 'old$i',
            role: i.isEven ? MessageRole.user : MessageRole.model,
            content: '이전대화$i ${'내용을 채우는 긴 문장이다. ' * 12}',
          ),
      ];

  ChatSession sessionWith(List<Message> messages) =>
      ChatSession(id: sessionId, title: 't', messages: messages);

  /// 컨테이너를 직접 들고 있어야 테스트에서 세션·스트리밍 상태를 밀어넣을 수 있다.
  Future<ProviderContainer> pumpView(WidgetTester tester) async {
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(chatSessionsProvider.notifier).addSession(
          sessionWith(priorConversation()),
        );
    container.read(activeSessionIdProvider.notifier).set(sessionId);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ChatView())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// 실제 전송처럼 사용자 메시지를 세션에 덧붙인다.
  void sendQuestion(ProviderContainer container, String id, String text) {
    final current = container.read(activeSessionProvider)!;
    container.read(chatSessionsProvider.notifier).updateSession(
          current.copyWith(
            messages: [
              ...current.messages,
              Message(id: id, role: MessageRole.user, content: text),
            ],
          ),
        );
  }

  /// 스트리밍 자리(빈 model 메시지) 추가 + 청크 누적.
  void streamAnswer(ProviderContainer container, String id, String content) {
    final current = container.read(activeSessionProvider)!;
    if (!current.messages.any((m) => m.id == id)) {
      container.read(chatSessionsProvider.notifier).updateSession(
            current.copyWith(
              messages: [
                ...current.messages,
                Message(
                  id: id,
                  role: MessageRole.model,
                  content: '',
                  isStreaming: true,
                ),
              ],
            ),
          );
      container.read(streamingMessageProvider.notifier).start(id);
    }
    container.read(streamingMessageProvider.notifier).appendChunk(content);
  }

  Finder bubbleFor(String id) => find.byWidgetPredicate(
        (w) => w is MessageBubble && w.message.id == id,
      );

  double scrollOffset(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView)).controller!.offset;

  testWidgets('질문을 보내면 그 말풍선이 화면 맨 위로 올라간다', (tester) async {
    final container = await pumpView(tester);

    sendQuestion(container, 'q', '새질문내용');
    await tester.pumpAndSettle();

    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    final bubbleTop = tester.getTopLeft(bubbleFor('q')).dy;

    // 뷰포트 맨 위에서 _pinTopInset(12) 만큼만 내려온 자리에 붙는다.
    expect(bubbleTop - listTop, closeTo(12, 3));

    // 이전 대화는 위로 밀려 화면에서 사라진다.
    expect(bubbleFor('old0'), findsNothing);
  });

  testWidgets('스트리밍 중에는 자동으로 따라 내려가지 않는다', (tester) async {
    final container = await pumpView(tester);

    sendQuestion(container, 'q', '새질문내용');
    await tester.pumpAndSettle();
    final pinnedOffset = scrollOffset(tester);

    // 화면을 넘칠 만큼 답변이 쌓여도 스크롤 위치는 그대로여야 한다.
    for (var i = 0; i < 5; i++) {
      streamAnswer(container, 'a', '답변청크$i ${'설명을 이어가는 문장이다. ' * 20}');
      await tester.pumpAndSettle();
    }

    expect(scrollOffset(tester), closeTo(pinnedOffset, 1));
    // 질문 말풍선도 맨 위에 그대로 남아 있다.
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    expect(tester.getTopLeft(bubbleFor('q')).dy - listTop, closeTo(12, 3));
  });

  testWidgets('아래에 내용이 남으면 화살표가 뜨고, 누르면 맨 아래로 내려간다', (tester) async {
    final container = await pumpView(tester);

    sendQuestion(container, 'q', '새질문내용');
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      streamAnswer(container, 'a', '답변청크$i ${'설명을 이어가는 문장이다. ' * 20}');
    }
    await tester.pumpAndSettle();

    final button = find.byTooltip('맨 아래로');
    expect(button, findsOneWidget);

    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    expect(opacity(), 1.0, reason: '읽지 않은 내용이 아래에 남아 있으면 보인다');

    await tester.tap(button);
    await tester.pumpAndSettle();

    // 답변의 끝이 화면 안으로 들어왔고, 화살표는 사라진다.
    final controller = tester.widget<ListView>(find.byType(ListView)).controller!;
    final position = controller.position;
    expect(position.pixels, greaterThan(0));
    expect(opacity(), 0.0, reason: '바닥에 닿으면 더 내려갈 곳이 없다');
  });

  testWidgets('답변이 짧으면 화살표가 뜨지 않는다', (tester) async {
    final container = await pumpView(tester);

    sendQuestion(container, 'q', '새질문내용');
    await tester.pumpAndSettle();
    streamAnswer(container, 'a', '짧은답변이다.');
    await tester.pumpAndSettle();

    // 스트리밍 종료 → 확보했던 여백이 회수되고 화살표도 내려간다.
    final current = container.read(activeSessionProvider)!;
    container.read(chatSessionsProvider.notifier).updateSession(
          current.copyWith(
            messages: [
              ...current.messages.where((m) => m.id != 'a'),
              Message(id: 'a', role: MessageRole.model, content: '짧은답변이다.'),
            ],
          ),
        );
    container.read(streamingMessageProvider.notifier).clear();
    await tester.pumpAndSettle();

    final opacity = tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byTooltip('맨 아래로'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity, 0.0);
  });
}
