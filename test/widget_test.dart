import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/main.dart';
import 'package:research_chatbot/providers/telemetry_provider.dart';
import 'package:research_chatbot/screens/chat_screen.dart';

/// 시작 화면: 이름을 넣어야 시작할 수 있고, 시작하면 참가자·시작 시각이 기록된다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('이름이 비어 있으면 시작 버튼이 비활성이다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('start-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('이름을 넣고 시작하면 참가자가 기록되고 채팅 화면으로 넘어간다',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.enterText(find.byKey(const ValueKey('participant-name')), ' P07 ');
    await tester.pump();

    final before = DateTime.now();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    final participant = container.read(telemetryProvider).participant;
    expect(participant, isNotNull);
    expect(participant!.name, 'P07');
    expect(participant.startedAt.isBefore(before), isFalse);
    expect(
      container.read(telemetryProvider).uiEvents.map((e) => e.type),
      contains('experiment.start'),
    );
  });
}
