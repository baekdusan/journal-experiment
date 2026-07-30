import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:research_chatbot/models/message.dart';
import 'package:research_chatbot/widgets/message_bubble.dart';

/// 채팅 영역의 텍스트 선택이 메시지·문단 경계를 넘어가는지 검증한다.
///
/// `MarkdownBody(selectable: true)`는 블록마다 독립적인 `SelectableText`를 만들어
/// 문단 하나를 넘는 드래그가 불가능하다. chat_view의 `SelectionArea`로 묶고
/// 버블 쪽 selectable을 끄는 구성이 유지되는지를 확인한다.
void main() {
  Widget harness(List<Message> messages, {ValueChanged<SelectedContent?>? onSel}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: onSel,
            child: ListView(
              children: [
                for (final m in messages) MessageBubble(message: m),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('AI 메시지는 블록별 SelectableText를 만들지 않는다', (tester) async {
    await tester.pumpWidget(harness([
      Message(
        id: 'a',
        role: MessageRole.model,
        content: '첫 번째 문단이다.\n\n두 번째 문단이다.',
      ),
    ]));

    // SelectableText가 있으면 그 블록이 독립 선택 영역이 되어 드래그가 갇힌다.
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  /// 문단이 둘인 AI 응답 + 사용자 발화 + 다음 AI 응답.
  List<Message> conversation() => [
        Message(
          id: 'a',
          role: MessageRole.model,
          content: '첫째문단내용\n\n둘째문단내용',
        ),
        Message(id: 'b', role: MessageRole.user, content: '사용자발화내용'),
        Message(id: 'c', role: MessageRole.model, content: '셋째응답내용'),
      ];

  testWidgets('드래그가 문단과 메시지 경계를 넘어 확장된다', (tester) async {
    SelectedContent? selected;
    await tester.pumpWidget(
      harness(conversation(), onSel: (content) => selected = content),
    );
    await tester.pumpAndSettle();

    // 첫 메시지 첫 문단 → 마지막 메시지까지 한 번에 드래그.
    final start = tester.getTopLeft(
          find.textContaining('첫째문단내용', findRichText: true),
        ) +
        const Offset(2, 6);
    final end = tester.getBottomRight(
          find.textContaining('셋째응답내용', findRichText: true),
        ) -
        const Offset(2, 6);

    // 마우스 드래그여야 선택이 된다. 터치 드래그는 ListView 스크롤로 해석된다
    // (실험은 웹/데스크톱 환경이므로 마우스가 실제 사용 조건이다).
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final text = selected?.plainText ?? '';
    expect(text, contains('첫째문단내용'));
    expect(text, contains('둘째문단내용')); // 문단 경계 통과
    expect(text, contains('사용자발화내용')); // 메시지 경계 통과
    expect(text, contains('셋째응답내용'));
  });

  testWidgets('전체 선택이 대화 전체를 덮는다', (tester) async {
    SelectedContent? selected;
    await tester.pumpWidget(
      harness(conversation(), onSel: (content) => selected = content),
    );
    await tester.pumpAndSettle();

    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll();
    await tester.pumpAndSettle();

    final text = selected?.plainText ?? '';
    expect(text, contains('첫째문단내용'));
    expect(text, contains('둘째문단내용'));
    expect(text, contains('사용자발화내용'));
    expect(text, contains('셋째응답내용'));
  });
}
