import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:research_chatbot/config/experiment_config.dart';
import 'package:research_chatbot/providers/chat_provider.dart';
import 'package:research_chatbot/providers/telemetry_provider.dart';
import 'package:research_chatbot/screens/chat_screen.dart';
import 'package:research_chatbot/screens/start_screen.dart';
import 'package:research_chatbot/services/participant_registry_service.dart';

/// 시트 조회 모드: 번호+이름이 배정표와 맞아야 시작되고, 조건은 시트에서 온다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 가짜 Apps Script: P001/홍길동 → 비교(control), P002/김철수 → 처치.
  ParticipantRegistryService fakeRegistry({List<Uri>? seen}) {
    final client = MockClient((req) async {
      seen?.add(req.url);
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'ok': true, 'fileUrl': 'drive://x'}), 200);
      }
      final q = req.url.queryParameters;
      if (q['action'] == 'start') return http.Response(jsonEncode({'ok': true}), 200);
      final table = {
        'P001': ('홍길동', 'control'),
        'P002': ('김철수', 'treatment'),
      };
      final row = table[q['pid']?.toUpperCase()];
      if (row == null) return http.Response(jsonEncode({'ok': false, 'reason': 'not_found'}), 200);
      if (row.$1 != q['name']) {
        return http.Response(jsonEncode({'ok': false, 'reason': 'name_mismatch'}), 200);
      }
      return http.Response(jsonEncode({'ok': true, 'condition': row.$2, 'pid': q['pid']}), 200);
    });
    return ParticipantRegistryService(client: client, baseUrl: 'https://script.test/exec');
  }

  Future<ProviderContainer> pump(WidgetTester tester, ParticipantRegistryService registry) async {
    final container = ProviderContainer(overrides: [
      participantRegistryServiceProvider.overrideWithValue(registry),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StartScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('조회 모드에서는 그룹 버튼이 없고 이름 칸이 있다', (tester) async {
    await pump(tester, fakeRegistry());
    expect(find.byKey(const ValueKey('group-selector')), findsNothing);
    expect(find.byKey(const ValueKey('participant-display-name')), findsOneWidget);
    expect(find.textContaining('처치'), findsNothing);
  });

  testWidgets('번호와 이름이 맞지 않으면 시작하지 않고 안내를 보여 준다', (tester) async {
    await pump(tester, fakeRegistry());
    await tester.enterText(find.byKey(const ValueKey('participant-name')), 'P001');
    await tester.enterText(find.byKey(const ValueKey('participant-display-name')), '아무개');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byKey(const ValueKey('start-error')), findsOneWidget);
  });

  testWidgets('맞으면 시트의 조건으로 시작하고 시작 행을 기록한다', (tester) async {
    final seen = <Uri>[];
    final container = await pump(tester, fakeRegistry(seen: seen));
    await tester.enterText(find.byKey(const ValueKey('participant-name')), 'p001');
    await tester.enterText(find.byKey(const ValueKey('participant-display-name')), '홍길동');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(ExperimentConfig.isControl, isTrue);
    expect(ExperimentConfig.conditionSource, 'start');
    final p = container.read(telemetryProvider).participant;
    expect(p?.name, 'p001');
    expect(p?.displayName, '홍길동');
    expect(seen.map((u) => u.queryParameters['action']), containsAll(['lookup', 'start']));
  });

  test('lookup은 네트워크 오류를 참가자용 문구로 바꾼다', () async {
    final registry = ParticipantRegistryService(
      client: MockClient((_) async => throw Exception('offline')),
      baseUrl: 'https://script.test/exec',
    );
    final r = await registry.lookup(pid: 'P001', name: '홍길동');
    expect(r.ok, isFalse);
    expect(r.reason, 'network');
    expect(r.message, contains('연결'));
  });
}
