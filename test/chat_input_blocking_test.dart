import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/providers/learning_state_provider.dart';
import 'package:research_chatbot/widgets/chat_input.dart';

/// 응답 생성 중 입력창 잠금과, 끝난 뒤 포커스 복귀를 검증한다.
///
/// 이전에는 전송 버튼과 엔터만 막혀 있어서, 처리 중에 친 엔터가 아무 반응 없이
/// 버려졌다. 비활성화하면 TextField가 포커스를 잃으므로 되돌려주지 않으면
/// 학습자가 매 턴 입력창을 다시 클릭해야 한다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: ChatInput())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  bool isFocused(WidgetTester tester) =>
      field(tester).focusNode?.hasFocus ?? false;

  void setProcessing(ProviderContainer c, bool value) =>
      c.read(isProcessingProvider.notifier).set(value);

  testWidgets('평소에는 입력이 열려 있고 포커스를 가진다', (tester) async {
    await pump(tester);

    expect(field(tester).enabled, isTrue);
    expect(field(tester).decoration?.hintText, '무엇이든 물어보세요');
    expect(isFocused(tester), isTrue, reason: 'autofocus');
  });

  testWidgets('처리 중에는 입력이 잠기고 안내 문구가 바뀐다', (tester) async {
    final container = await pump(tester);

    setProcessing(container, true);
    await tester.pumpAndSettle();

    expect(field(tester).enabled, isFalse);
    expect(field(tester).decoration?.hintText, '답변을 준비하는 중이에요');
    expect(isFocused(tester), isFalse, reason: '비활성 필드는 포커스를 잃는다');
  });

  testWidgets('잠긴 동안에는 타이핑이 들어가지 않는다', (tester) async {
    final container = await pump(tester);
    setProcessing(container, true);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '처리 중에 친 글자');
    await tester.pumpAndSettle();

    expect(field(tester).controller?.text ?? '', isEmpty);
  });

  testWidgets('처리가 끝나면 입력이 열리고 포커스가 되돌아온다', (tester) async {
    final container = await pump(tester);

    setProcessing(container, true);
    await tester.pumpAndSettle();
    expect(isFocused(tester), isFalse);

    setProcessing(container, false);
    await tester.pumpAndSettle();

    expect(field(tester).enabled, isTrue);
    expect(field(tester).decoration?.hintText, '무엇이든 물어보세요');
    expect(isFocused(tester), isTrue, reason: '다음 발화를 바로 칠 수 있어야 한다');
  });

  testWidgets('잠금/해제 사이클이 작성 중이던 초안을 보존한다', (tester) async {
    final container = await pump(tester);

    await tester.enterText(find.byType(TextField), '쓰다 만 문장');
    await tester.pumpAndSettle();

    setProcessing(container, true);
    await tester.pumpAndSettle();
    expect(field(tester).controller?.text, '쓰다 만 문장', reason: '잠겨도 지워지면 안 된다');

    setProcessing(container, false);
    await tester.pumpAndSettle();
    expect(field(tester).controller?.text, '쓰다 만 문장');

    // 이어서 계속 쓸 수 있어야 한다.
    await tester.enterText(find.byType(TextField), '쓰다 만 문장 이어서');
    await tester.pumpAndSettle();
    expect(field(tester).controller?.text, '쓰다 만 문장 이어서');
  });

  testWidgets('IME 조합 중에 잠겨도 이미 입력된 글자는 남는다', (tester) async {
    // 이 프로젝트는 한글 조합 처리로 버그를 겪은 이력이 있다
    // (chat_input.dart의 _submit 주석 참고). 잠금이 그 경로를 건드리지 않는지 고정한다.
    final container = await pump(tester);
    final controller = field(tester).controller!;

    controller.value = const TextEditingValue(
      text: '가',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    await tester.pumpAndSettle();

    setProcessing(container, true);
    await tester.pumpAndSettle();
    expect(controller.text, '가', reason: '조합 중이던 글자가 사라지면 안 된다');

    setProcessing(container, false);
    await tester.pumpAndSettle();
    expect(controller.text, '가');
  });

  testWidgets('설계(isDesigning) 중에도 같은 규칙이 적용된다', (tester) async {
    final container = await pump(tester);

    await container
        .read(learningStateProvider.notifier)
        .setDesigning(true);
    await tester.pumpAndSettle();
    expect(field(tester).enabled, isFalse);

    await container
        .read(learningStateProvider.notifier)
        .setDesigning(false);
    await tester.pumpAndSettle();
    expect(field(tester).enabled, isTrue);
    expect(isFocused(tester), isTrue);
  });
}
