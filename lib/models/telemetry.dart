import 'package:uuid/uuid.dart';

/// 실험 참가자 정보. 시작 화면에서 이름을 받고 시작 버튼을 누른 시각을 기록한다.
class ParticipantInfo {
  /// 참가자 번호(예: P007). 파일명과 시트 조회 키.
  final String name;

  /// 참가자 이름(시트 조회에 썼을 때만). 내보내기에는 남지만 파일명에는 안 쓴다.
  final String? displayName;

  /// 시작 버튼을 누른 시각. 모든 상대 시간(`tSinceStartMs`)의 기준점이다.
  final DateTime startedAt;

  /// 현장 PC 식별자 (`?pc=A`). 없으면 null.
  final String? station;

  const ParticipantInfo({
    required this.name,
    required this.startedAt,
    this.station,
    this.displayName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'startedAt': startedAt.toIso8601String(),
        'station': station,
      };

  factory ParticipantInfo.fromJson(Map<String, dynamic> j) => ParticipantInfo(
        name: j['name'] as String,
        displayName: j['displayName'] as String?,
        startedAt: DateTime.parse(j['startedAt'] as String),
        station: j['station'] as String?,
      );
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

  /// 실제 시도 횟수(1이면 재시도 없음). 429/503 등 일시 오류는 자동 재시도한다.
  final int attempts;

  /// 재시도로 넘어간 시도들의 오류 문자열(시도 순).
  final List<String> retryErrors;

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
    this.attempts = 1,
    this.retryErrors = const [],
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
        attempts: attempts,
        retryErrors: retryErrors,
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
        'attempts': attempts,
        'retryErrors': retryErrors,
      };

  factory LlmCallRecord.fromJson(Map<String, dynamic> j) {
    final usage = (j['usage'] as Map?)?.cast<String, dynamic>() ?? const {};
    DateTime? dt(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    return LlmCallRecord(
      id: j['id'] as String?,
      turn: j['turn'] as int?,
      agent: j['agent'] as String,
      model: j['model'] as String,
      location: j['location'] as String,
      streaming: j['streaming'] as bool? ?? false,
      startedAt: DateTime.parse(j['startedAt'] as String),
      firstChunkAt: dt('firstChunkAt'),
      completedAt: DateTime.parse(j['completedAt'] as String),
      chunkCount: j['chunkCount'] as int? ?? 0,
      promptTokenCount: usage['promptTokenCount'] as int?,
      candidatesTokenCount: usage['candidatesTokenCount'] as int?,
      totalTokenCount: usage['totalTokenCount'] as int?,
      thoughtsTokenCount: usage['thoughtsTokenCount'] as int?,
      toolUsePromptTokenCount: usage['toolUsePromptTokenCount'] as int?,
      finishReason: j['finishReason'] as String?,
      finishMessage: j['finishMessage'] as String?,
      error: j['error'] as String?,
      systemInstruction: j['systemInstruction'] as String?,
      prompt: j['prompt'] as String? ?? '',
      historyLength: j['historyLength'] as int? ?? 0,
      historyChars: j['historyChars'] as int? ?? 0,
      responseText: j['responseText'] as String?,
      searchQueries: (j['searchQueries'] as List?)?.cast<String>() ?? const [],
      sources: (j['sources'] as List?)?.cast<String>() ?? const [],
      attempts: j['attempts'] as int? ?? 1,
      retryErrors: (j['retryErrors'] as List?)?.cast<String>() ?? const [],
    );
  }
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

  factory FlowEvent.fromJson(Map<String, dynamic> j) => FlowEvent(
        id: j['id'] as String?,
        timestamp: DateTime.parse(j['timestamp'] as String),
        turn: j['turn'] as int?,
        name: j['name'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
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

  factory UiEvent.fromJson(Map<String, dynamic> j) => UiEvent(
        id: j['id'] as String?,
        timestamp: DateTime.parse(j['timestamp'] as String),
        type: j['type'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
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

  factory ComposeMeta.fromJson(Map<String, dynamic> j) => ComposeMeta(
        focusedAt:
            j['focusedAt'] == null ? null : DateTime.parse(j['focusedAt'] as String),
        firstKeyAt:
            j['firstKeyAt'] == null ? null : DateTime.parse(j['firstKeyAt'] as String),
        editCount: j['editCount'] as int? ?? 0,
        maxLength: j['maxLength'] as int? ?? 0,
      );
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

  /// 입력창이 다시 열린 시각. 응답 완료 후 단계 판정·설계 등 후처리까지
  /// 끝난 시점이라 학습자가 실제로 기다린 시간의 끝이다.
  final DateTime? inputUnlockedAt;
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
    this.inputUnlockedAt,
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
    DateTime? inputUnlockedAt,
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
        inputUnlockedAt: inputUnlockedAt ?? this.inputUnlockedAt,
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
        'inputUnlockedAt': inputUnlockedAt?.toIso8601String(),
        // 전송 → 입력창 재개방: 학습자가 실제로 기다린 시간 (후처리 포함)
        'blockedMs': _ms(sentAt, inputUnlockedAt),
        // 응답 완료 → 입력창 재개방: 단계 판정 등 보이지 않는 후처리 시간
        'postProcessingMs': _ms(responseCompletedAt, inputUnlockedAt),
        'responseChars': responseChars,
        'llmCallIds': llmCallIds,
        'error': error,
      };

  /// [toJson]의 파생 필드(readingMs 등)는 무시하고 원 필드만 복원한다.
  factory TurnRecord.fromJson(Map<String, dynamic> j) {
    DateTime? dt(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    return TurnRecord(
      turn: j['turn'] as int,
      sentAt: DateTime.parse(j['sentAt'] as String),
      userText: j['userText'] as String? ?? '',
      compose: j['compose'] == null
          ? const ComposeMeta()
          : ComposeMeta.fromJson((j['compose'] as Map).cast<String, dynamic>()),
      previousResponseCompletedAt: dt('previousResponseCompletedAt'),
      route: j['route'] as String?,
      intent: j['intent'] as String?,
      stepIndexBefore: j['stepIndexBefore'] as int?,
      stepIndexAfter: j['stepIndexAfter'] as int?,
      responseStartedAt: dt('responseStartedAt'),
      firstChunkAt: dt('firstChunkAt'),
      responseCompletedAt: dt('responseCompletedAt'),
      inputUnlockedAt: dt('inputUnlockedAt'),
      responseChars: j['responseChars'] as int?,
      llmCallIds: (j['llmCallIds'] as List?)?.cast<String>() ?? const [],
      error: j['error'] as String?,
    );
  }
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

  Map<String, dynamic> toJson() => {
        'participant': participant?.toJson(),
        'environment': environment,
        'turns': turns.map((t) => t.toJson(participant?.startedAt)).toList(),
        'llmCalls': llmCalls.map((c) => c.toJson()).toList(),
        'flowEvents': flowEvents.map((e) => e.toJson()).toList(),
        'uiEvents': uiEvents.map((e) => e.toJson()).toList(),
        'exportCount': exportCount,
      };

  factory SessionTelemetry.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        (j[k] as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    return SessionTelemetry(
      participant: j['participant'] == null
          ? null
          : ParticipantInfo.fromJson((j['participant'] as Map).cast<String, dynamic>()),
      environment: (j['environment'] as Map?)?.cast<String, dynamic>() ?? const {},
      turns: list('turns').map(TurnRecord.fromJson).toList(),
      llmCalls: list('llmCalls').map(LlmCallRecord.fromJson).toList(),
      flowEvents: list('flowEvents').map(FlowEvent.fromJson).toList(),
      uiEvents: list('uiEvents').map(UiEvent.fromJson).toList(),
      exportCount: j['exportCount'] as int? ?? 0,
    );
  }
}
