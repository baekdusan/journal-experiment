import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/config/experiment_config.dart';
import 'package:research_chatbot/main.dart';
import 'package:research_chatbot/providers/telemetry_provider.dart';
import 'package:research_chatbot/screens/chat_screen.dart';
import 'package:research_chatbot/screens/start_screen.dart';

/// 진행자 설정 화면 → 참가자 시작 화면 → 채팅 화면 흐름.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('앱은 시작 화면으로 열리고, 그룹을 고르지 않으면 시작할 수 없다',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('participant-name')), 'P07');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('start-button')),
    );
    expect(button.onPressed, isNull);
    // 화면에 처치/대조라는 말이 없다.
    expect(find.textContaining('처치'), findsNothing);
    expect(find.textContaining('대조'), findsNothing);
  });

  testWidgets('그룹 B를 고르고 시작하면 대조군으로 기록된다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('participant-name')), 'P08');
    await tester.tap(find.text('그룹 B'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(ExperimentConfig.isControl, isTrue);
    expect(ExperimentConfig.blindLabel, 'B');
    expect(ExperimentConfig.conditionSource, 'start');
    expect(container.read(telemetryProvider).participant?.name, 'P08');
  });

  testWidgets('시작 화면: 이름이 비어 있으면 시작 버튼이 비활성이다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: StartScreen())),
    );
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
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StartScreen()),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('participant-name')), ' P07 ');
    await tester.tap(find.text('그룹 A'));
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
