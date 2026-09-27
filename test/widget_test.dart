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

  testWidgets('설정 화면: 조건을 고르지 않으면 넘어갈 수 없다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('setup-confirm')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(StartScreen), findsNothing);
  });

  testWidgets('설정 화면: 대조군을 고르면 조건이 바뀌고 시작 화면으로 간다',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대조군 (순수 모델)'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('station-field')), 'B');
    await tester.tap(find.byKey(const ValueKey('setup-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(StartScreen), findsOneWidget);
    expect(ExperimentConfig.isControl, isTrue);
    expect(ExperimentConfig.conditionSource, 'setup');
    expect(ExperimentConfig.station, 'B');
    // 참가자 화면에는 조건이 드러나지 않는다.
    expect(find.textContaining('대조군'), findsNothing);
    expect(find.textContaining('처치군'), findsNothing);
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
