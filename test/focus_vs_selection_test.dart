import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/models/chat_session.dart';
import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/widgets/chat_input.dart';
import 'package:research_chatbot/widgets/message_bubble.dart';

/// 응답 대기 중 학습자가 이전 답변을 드래그해 두었을 때,
/// 생성이 끝나며 입력창이 포커스를 되찾는 것이 그 선택을 지우는지 확인한다.
///
/// 두 기능이 최근에 함께 들어왔다 — 대화 전체 선택(SelectionArea)과
/// 처리 종료 시 포커스 복귀. 서로 간섭하면 학습자가 인용하려고 잡아둔 텍스트가
/// 스트리밍 종료와 동시에 사라진다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처리 종료 시 포커스 복귀가 학습자의 텍스트 선택을 지우지 않는다', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 700)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SelectedContent? selected;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = ChatSession(id: 's1', title: 't', messages: [
      Message(id: 'a', role: MessageRole.model, content: '첫째답변내용 ${'설명 문장이다. ' * 6}'),
      Message(id: 'b', role: MessageRole.user, content: '사용자발화내용'),
    ]);
    container.read(chatSessionsProvider.notifier).addSession(session);
    container.read(activeSessionIdProvider.notifier).set('s1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SelectionArea(
                    onSelectionChanged: (c) => selected = c,
                    child: ListView(
                      children: [
                        for (final m in session.messages) MessageBubble(message: m),
                      ],
                    ),
                  ),
                ),
                const ChatInput(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1) 처리 시작 → 입력창 잠김
    container.read(isProcessingProvider.notifier).set(true);
    await tester.pumpAndSettle();

    // 2) 대기하는 동안 학습자가 이전 답변을 드래그해 선택한다 (마우스)
    final start = tester.getTopLeft(
          find.textContaining('첫째답변내용', findRichText: true),
        ) +
        const Offset(2, 6);
    final end = start + const Offset(220, 0);
    final drag = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await drag.moveTo(end);
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    final beforeText = selected?.plainText ?? '';
    expect(beforeText, isNotEmpty, reason: '드래그로 선택이 실제로 만들어져야 한다');

    // 3) 처리 종료 → 입력창이 포커스를 되찾는다
    container.read(isProcessingProvider.notifier).set(false);
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.enabled, isTrue, reason: '입력은 다시 열려야 한다');
    // 선택을 잡고 있는 동안에는 포커스를 뺏지 않는다 — 다음 클릭/타이핑이
    // 자연스럽게 입력창으로 돌아간다.
    expect(input.focusNode?.hasFocus, isFalse,
        reason: '학습자가 선택을 잡고 있으면 포커스를 가져오지 않는다');

    // 핵심 질문: 선택이 살아남았는가?
    // SelectionArea는 선택이 지워질 때 onSelectionChanged(null)을 호출한다.
    debugPrint('[selection] before="$beforeText"');
    debugPrint('[selection] after="${selected?.plainText}"');

    expect(
      selected?.plainText ?? '',
      beforeText,
      reason: '포커스 복귀가 학습자의 선택을 지우면 안 된다',
    );
  });
}
