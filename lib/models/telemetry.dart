import 'package:uuid/uuid.dart';

/// 실험 참가자 정보. 시작 화면에서 이름을 받고 시작 버튼을 누른 시각을 기록한다.
class ParticipantInfo {
  final String name;

  /// 시작 버튼을 누른 시각. 모든 상대 시간(`tSinceStartMs`)의 기준점이다.
  final DateTime startedAt;

  /// 현장 PC 식별자 (`?pc=A`). 없으면 null.
  final String? station;

  const ParticipantInfo({
    required this.name,
    required this.startedAt,
    this.station,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'station': station,
      };
}

/// LLM 호출 1건의 기록. 처치군은 한 턴에 2~4회, 대조군은 1회 발생한다.
class LlmCallRecord {
  final String id;

  /// 호출이 속한 사용자 턴 번호 (설계 백그라운드 호출은 트리거된 턴 번호).
  final int? turn;

  /// intent | analyst | feedback | tutor | freeform | stepProgress |
  /// designer.research | designer.structure
  final String agent;
  final String model;
  final String location;
  final bool streaming;

  final DateTime startedAt;
  final DateTime? firstChunkAt;
  final DateTime completedAt;
  final int chunkCount;

  final int? promptTokenCount;
  final int? candidatesTokenCount;
  final int? totalTokenCount;
  final int? thoughtsTokenCount;
  final int? toolUsePromptTokenCount;

  final String? finishReason;
  final String? finishMessage;
  final String? error;

  /// 시스템 프롬프트 원문(튜터는 매 턴 재빌드되므로 턴별로 다르다).
  final String? systemInstruction;

  /// 이번 호출의 사용자 측 입력(단발 에이전트는 프롬프트 전문, 스트리밍은 발화).
  final String prompt;

  /// 스트리밍 호출에 함께 보낸 대화 이력 길이.
  final int historyLength;
  final int historyChars;

  /// 모델이 돌려준 원문(JSON 에이전트는 raw JSON 문자열).
  final String? responseText;

  final List<String> searchQueries;
  final List<String> sources;

  LlmCallRecord({
    String? id,
    this.turn,
    required this.agent,
    required this.model,
    required this.location,
    this.streaming = false,
    required this.startedAt,
    this.firstChunkAt,
    required this.completedAt,
    this.chunkCount = 0,
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
    this.thoughtsTokenCount,
    this.toolUsePromptTokenCount,
    this.finishReason,
    this.finishMessage,
    this.error,
    this.systemInstruction,
    required this.prompt,
    this.historyLength = 0,
    this.historyChars = 0,
    this.responseText,
    this.searchQueries = const [],
    this.sources = const [],
  }) : id = id ?? const Uuid().v4();

  int get durationMs => completedAt.difference(startedAt).inMilliseconds;

  int? get timeToFirstChunkMs =>
      firstChunkAt?.difference(startedAt).inMilliseconds;

  LlmCallRecord copyWith({
    int? turn,
    List<String>? searchQueries,
    List<String>? sources,
  }) =>
      LlmCallRecord(
        id: id,
        turn: turn ?? this.turn,
        agent: agent,
        model: model,
        location: location,
        streaming: streaming,
        startedAt: startedAt,
        firstChunkAt: firstChunkAt,
        completedAt: completedAt,
        chunkCount: chunkCount,
        promptTokenCount: promptTokenCount,
        candidatesTokenCount: candidatesTokenCount,
        totalTokenCount: totalTokenCount,
        thoughtsTokenCount: thoughtsTokenCount,
        toolUsePromptTokenCount: toolUsePromptTokenCount,
        finishReason: finishReason,
        finishMessage: finishMessage,
        error: error,
        systemInstruction: systemInstruction,
        prompt: prompt,
        historyLength: historyLength,
        historyChars: historyChars,
        responseText: responseText,
        searchQueries: searchQueries ?? this.searchQueries,
        sources: sources ?? this.sources,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'turn': turn,
        'agent': agent,
        'model': model,
        'location': location,
        'streaming': streaming,
        'startedAt': startedAt.toIso8601String(),
        'firstChunkAt': firstChunkAt?.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'durationMs': durationMs,
        'timeToFirstChunkMs': timeToFirstChunkMs,
        'chunkCount': chunkCount,
        'usage': {
          'promptTokenCount': promptTokenCount,
          'candidatesTokenCount': candidatesTokenCount,
          'totalTokenCount': totalTokenCount,
          'thoughtsTokenCount': thoughtsTokenCount,
          'toolUsePromptTokenCount': toolUsePromptTokenCount,
        },
        'finishReason': finishReason,
        'finishMessage': finishMessage,
        'error': error,
        'systemInstruction': systemInstruction,
        'systemInstructionChars': systemInstruction?.length,
        'prompt': prompt,
        'promptChars': prompt.length,
        'historyLength': historyLength,
        'historyChars': historyChars,
        'responseText': responseText,
        'responseChars': responseText?.length,
        'searchQueries': searchQueries,
        'sources': sources,
      };
}

/// 오케스트레이션 흐름 이벤트. 예전에는 `debugPrint`로만 찍히던 라우팅·판정 로그다.
class FlowEvent {
  final String id;
  final DateTime timestamp;
  final int? turn;
  final String name;
  final Map<String, dynamic> data;

  FlowEvent({
    String? id,
    DateTime? timestamp,
    this.turn,
    required this.name,
    required this.data,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'turn': turn,
        'name': name,
        'data': data,
      };
}

/// 학습자 행동·브라우저 이벤트 (탭 이탈, 창 크기, 스크롤, 버튼 클릭 등).
class UiEvent {
  final String id;
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic> data;

  UiEvent({
    String? id,
    DateTime? timestamp,
    required this.type,
    this.data = const {},
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'data': data,
      };
}

/// 입력창에서 넘어오는 작성 행동 메타. 메시지 전송 시 함께 전달된다.
class ComposeMeta {
  /// 직전 전송 이후 입력창이 처음 포커스를 받은 시각.
  final DateTime? focusedAt;

  /// 직전 전송 이후 첫 글자가 입력된 시각.
  final DateTime? firstKeyAt;

  /// 텍스트 변경 이벤트 수(타이핑·삭제·붙여넣기 모두 포함).
  final int editCount;

  /// 작성 도중 도달한 최대 글자 수(지웠다 다시 쓴 흔적을 남긴다).
  final int maxLength;

  const ComposeMeta({
    this.focusedAt,
    this.firstKeyAt,
    this.editCount = 0,
    this.maxLength = 0,
  });

  Map<String, dynamic> toJson() => {
        'focusedAt': focusedAt?.toIso8601String(),
        'firstKeyAt': firstKeyAt?.toIso8601String(),
        'editCount': editCount,
        'maxLength': maxLength,
      };
}

/// 사용자 턴 1개의 요약. 전송 시각부터 응답 완료까지의 흐름을 한 행으로 모은다.
class TurnRecord {
  final int turn;
  final DateTime sentAt;
  final String userText;
  final ComposeMeta compose;

  /// 직전 튜터 응답이 끝난 시각(첫 턴은 실험 시작 시각).
  final DateTime? previousResponseCompletedAt;

  /// analyst | design | tutor | feedback | freeform | ignored.designing
  final String? route;
  final String? intent;
  final int? stepIndexBefore;
  final int? stepIndexAfter;
  final DateTime? responseStartedAt;
  final DateTime? firstChunkAt;
  final DateTime? responseCompletedAt;
  final int? responseChars;
  final List<String> llmCallIds;
  final String? error;

  const TurnRecord({
    required this.turn,
    required this.sentAt,
    required this.userText,
    this.compose = const ComposeMeta(),
    this.previousResponseCompletedAt,
    this.route,
    this.intent,
    this.stepIndexBefore,
    this.stepIndexAfter,
    this.responseStartedAt,
    this.firstChunkAt,
    this.responseCompletedAt,
    this.responseChars,
    this.llmCallIds = const [],
    this.error,
  });

  TurnRecord copyWith({
    String? route,
    String? intent,
    int? stepIndexBefore,
    int? stepIndexAfter,
    DateTime? responseStartedAt,
    DateTime? firstChunkAt,
    DateTime? responseCompletedAt,
    int? responseChars,
    List<String>? llmCallIds,
    String? error,
  }) =>
      TurnRecord(
        turn: turn,
        sentAt: sentAt,
        userText: userText,
        compose: compose,
        previousResponseCompletedAt: previousResponseCompletedAt,
        route: route ?? this.route,
        intent: intent ?? this.intent,
        stepIndexBefore: stepIndexBefore ?? this.stepIndexBefore,
        stepIndexAfter: stepIndexAfter ?? this.stepIndexAfter,
        responseStartedAt: responseStartedAt ?? this.responseStartedAt,
        firstChunkAt: firstChunkAt ?? this.firstChunkAt,
        responseCompletedAt: responseCompletedAt ?? this.responseCompletedAt,
        responseChars: responseChars ?? this.responseChars,
        llmCallIds: llmCallIds ?? this.llmCallIds,
        error: error ?? this.error,
      );

  int? _ms(DateTime? from, DateTime? to) =>
      (from == null || to == null) ? null : to.difference(from).inMilliseconds;

  Map<String, dynamic> toJson(DateTime? experimentStartedAt) => {
        'turn': turn,
        'sentAt': sentAt.toIso8601String(),
        'tSinceStartMs': _ms(experimentStartedAt, sentAt),
        'userText': userText,
        'userChars': userText.length,
        'route': route,
        'intent': intent,
        'stepIndexBefore': stepIndexBefore,
        'stepIndexAfter': stepIndexAfter,
        'compose': compose.toJson(),
        'previousResponseCompletedAt':
            previousResponseCompletedAt?.toIso8601String(),
        // 직전 응답 완료 → 첫 글자 입력: 읽고 생각한 시간
        'readingMs': _ms(previousResponseCompletedAt, compose.firstKeyAt),
        // 첫 글자 입력 → 전송: 작성 시간
        'composeMs': _ms(compose.firstKeyAt, sentAt),
        // 직전 응답 완료 → 전송: 턴 간 간격 전체
        'sinceResponseMs': _ms(previousResponseCompletedAt, sentAt),
        'responseStartedAt': responseStartedAt?.toIso8601String(),
        'firstChunkAt': firstChunkAt?.toIso8601String(),
        'responseCompletedAt': responseCompletedAt?.toIso8601String(),
        // 전송 → 첫 토큰 표시: 학습자가 체감한 대기
        'timeToFirstChunkMs': _ms(sentAt, firstChunkAt),
        // 전송 → 응답 완료: 턴 전체 지연
        'latencyMs': _ms(sentAt, responseCompletedAt),
        'responseChars': responseChars,
        'llmCallIds': llmCallIds,
        'error': error,
      };
}

/// 세션 하나에 누적되는 텔레메트리 전체. 내보내기 시 세션·학습 상태와 합쳐진다.
class SessionTelemetry {
  final ParticipantInfo? participant;
  final Map<String, dynamic> environment;
  final List<TurnRecord> turns;
  final List<LlmCallRecord> llmCalls;
  final List<FlowEvent> flowEvents;
  final List<UiEvent> uiEvents;
  final int exportCount;

  const SessionTelemetry({
    this.participant,
    this.environment = const {},
    this.turns = const [],
    this.llmCalls = const [],
    this.flowEvents = const [],
    this.uiEvents = const [],
    this.exportCount = 0,
  });

  SessionTelemetry copyWith({
    ParticipantInfo? participant,
    Map<String, dynamic>? environment,
    List<TurnRecord>? turns,
    List<LlmCallRecord>? llmCalls,
    List<FlowEvent>? flowEvents,
    List<UiEvent>? uiEvents,
    int? exportCount,
  }) =>
      SessionTelemetry(
        participant: participant ?? this.participant,
        environment: environment ?? this.environment,
        turns: turns ?? this.turns,
        llmCalls: llmCalls ?? this.llmCalls,
        flowEvents: flowEvents ?? this.flowEvents,
        uiEvents: uiEvents ?? this.uiEvents,
        exportCount: exportCount ?? this.exportCount,
      );
}
