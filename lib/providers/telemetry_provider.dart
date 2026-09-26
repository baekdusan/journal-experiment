import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/telemetry.dart';
import '../platform/web_env.dart';

part 'telemetry_provider.g.dart';

/// 세션 텔레메트리 누적기.
///
/// 메시지·학습 상태와 달리 화면을 그리지 않으므로 아무도 watch하지 않는다.
/// 내보내기 시점에 [SessionExportService]가 한 번 읽는다.
/// 시작 화면의 시작 버튼([startExperiment])에서 초기화되고 참가자가 기록된다.
@Riverpod(keepAlive: true)
class Telemetry extends _$Telemetry {
  void Function()? _disposeWindowListeners;

  @override
  SessionTelemetry build() => const SessionTelemetry();

  /// 시작 버튼: 참가자 기록 + 환경 스냅샷 + 브라우저 이벤트 구독.
  void startExperiment({required String name, String? station}) {
    _disposeWindowListeners?.call();
    state = SessionTelemetry(
      participant: ParticipantInfo(
        name: name,
        startedAt: DateTime.now(),
        station: station,
      ),
      environment: environmentSnapshot(),
    );
    _disposeWindowListeners = listenWindowEvents(
      (type, data) => recordUi(type, data),
      warnBeforeUnload: true,
    );
    recordUi('experiment.start', {'name': name, 'station': station});
  }

  void reset() {
    state = SessionTelemetry(
      participant: state.participant,
      environment: state.environment,
    );
  }

  DateTime? get startedAt => state.participant?.startedAt;

  void recordCall(LlmCallRecord call, {int? turn}) {
    final stored = turn != null && call.turn == null ? call.copyWith(turn: turn) : call;
    state = state.copyWith(llmCalls: [...state.llmCalls, stored]);
  }

  void recordFlow(String name, Map<String, dynamic> data, {int? turn}) {
    state = state.copyWith(
      flowEvents: [
        ...state.flowEvents,
        FlowEvent(name: name, data: data, turn: turn),
      ],
    );
  }

  void recordUi(String type, [Map<String, dynamic> data = const {}]) {
    state = state.copyWith(
      uiEvents: [...state.uiEvents, UiEvent(type: type, data: data)],
    );
  }

  void beginTurn(TurnRecord record) {
    state = state.copyWith(turns: [...state.turns, record]);
  }

  /// 진행 중인 턴을 갱신한다. 같은 턴 번호가 없으면 무시한다.
  void updateTurn(int turn, TurnRecord Function(TurnRecord) update) {
    final idx = state.turns.lastIndexWhere((t) => t.turn == turn);
    if (idx < 0) return;
    final turns = [...state.turns];
    turns[idx] = update(turns[idx]);
    state = state.copyWith(turns: turns);
  }

  /// 가장 최근에 완료된 학습자 대면 응답의 시각. 다음 턴의 읽기 시간 기준점.
  DateTime? get lastResponseCompletedAt {
    for (final t in state.turns.reversed) {
      if (t.responseCompletedAt != null) return t.responseCompletedAt;
    }
    return startedAt;
  }

  void markExported() {
    state = state.copyWith(exportCount: state.exportCount + 1);
  }
}
