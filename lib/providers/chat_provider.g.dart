// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [GeminiService]의 싱글톤 인스턴스를 제공하는 프로바이더.
///
/// `keepAlive: true` 설정으로 앱 생명주기 동안 인스턴스가 유지되어
/// 불필요한 재생성을 방지하고 연결 상태를 보존한다.

@ProviderFor(geminiService)
final geminiServiceProvider = GeminiServiceProvider._();

/// [GeminiService]의 싱글톤 인스턴스를 제공하는 프로바이더.
///
/// `keepAlive: true` 설정으로 앱 생명주기 동안 인스턴스가 유지되어
/// 불필요한 재생성을 방지하고 연결 상태를 보존한다.

final class GeminiServiceProvider
    extends $FunctionalProvider<GeminiService, GeminiService, GeminiService>
    with $Provider<GeminiService> {
  /// [GeminiService]의 싱글톤 인스턴스를 제공하는 프로바이더.
  ///
  /// `keepAlive: true` 설정으로 앱 생명주기 동안 인스턴스가 유지되어
  /// 불필요한 재생성을 방지하고 연결 상태를 보존한다.
  GeminiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geminiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geminiServiceHash();

  @$internal
  @override
  $ProviderElement<GeminiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GeminiService create(Ref ref) {
    return geminiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeminiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeminiService>(value),
    );
  }
}

String _$geminiServiceHash() => r'e5feb19f16ed3b98580dffdb3a321139b26a7d6d';

/// [IntentClassifierService]의 싱글톤 인스턴스 제공.
///
/// 사용자 발화가 "수업 내(inClass)" vs "수업 외(outOfClass)"인지 분류합니다.

@ProviderFor(intentClassifierService)
final intentClassifierServiceProvider = IntentClassifierServiceProvider._();

/// [IntentClassifierService]의 싱글톤 인스턴스 제공.
///
/// 사용자 발화가 "수업 내(inClass)" vs "수업 외(outOfClass)"인지 분류합니다.

final class IntentClassifierServiceProvider
    extends
        $FunctionalProvider<
          IntentClassifierService,
          IntentClassifierService,
          IntentClassifierService
        >
    with $Provider<IntentClassifierService> {
  /// [IntentClassifierService]의 싱글톤 인스턴스 제공.
  ///
  /// 사용자 발화가 "수업 내(inClass)" vs "수업 외(outOfClass)"인지 분류합니다.
  IntentClassifierServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'intentClassifierServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$intentClassifierServiceHash();

  @$internal
  @override
  $ProviderElement<IntentClassifierService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IntentClassifierService create(Ref ref) {
    return intentClassifierService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IntentClassifierService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IntentClassifierService>(value),
    );
  }
}

String _$intentClassifierServiceHash() =>
    r'77d08f1d3609858db2bc01368948d635faf6388a';

/// [ConversationalAgentService]의 싱글톤 인스턴스 제공.
///
/// Analyst/Tutor/Feedback 세 가지 모드의 프롬프트와 실행을 담당합니다.

@ProviderFor(conversationalAgentService)
final conversationalAgentServiceProvider =
    ConversationalAgentServiceProvider._();

/// [ConversationalAgentService]의 싱글톤 인스턴스 제공.
///
/// Analyst/Tutor/Feedback 세 가지 모드의 프롬프트와 실행을 담당합니다.

final class ConversationalAgentServiceProvider
    extends
        $FunctionalProvider<
          ConversationalAgentService,
          ConversationalAgentService,
          ConversationalAgentService
        >
    with $Provider<ConversationalAgentService> {
  /// [ConversationalAgentService]의 싱글톤 인스턴스 제공.
  ///
  /// Analyst/Tutor/Feedback 세 가지 모드의 프롬프트와 실행을 담당합니다.
  ConversationalAgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationalAgentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationalAgentServiceHash();

  @$internal
  @override
  $ProviderElement<ConversationalAgentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationalAgentService create(Ref ref) {
    return conversationalAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationalAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationalAgentService>(value),
    );
  }
}

String _$conversationalAgentServiceHash() =>
    r'c159d652b41fc123fc081f496563af7e2f7bdbeb';

/// [SyllabusDesignerService]의 싱글톤 인스턴스 제공.
///
/// 학습자 프로파일 기반으로 ADDIE 모델 커리큘럼을 생성합니다.

@ProviderFor(syllabusDesignerService)
final syllabusDesignerServiceProvider = SyllabusDesignerServiceProvider._();

/// [SyllabusDesignerService]의 싱글톤 인스턴스 제공.
///
/// 학습자 프로파일 기반으로 ADDIE 모델 커리큘럼을 생성합니다.

final class SyllabusDesignerServiceProvider
    extends
        $FunctionalProvider<
          SyllabusDesignerService,
          SyllabusDesignerService,
          SyllabusDesignerService
        >
    with $Provider<SyllabusDesignerService> {
  /// [SyllabusDesignerService]의 싱글톤 인스턴스 제공.
  ///
  /// 학습자 프로파일 기반으로 ADDIE 모델 커리큘럼을 생성합니다.
  SyllabusDesignerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syllabusDesignerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syllabusDesignerServiceHash();

  @$internal
  @override
  $ProviderElement<SyllabusDesignerService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyllabusDesignerService create(Ref ref) {
    return syllabusDesignerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyllabusDesignerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyllabusDesignerService>(value),
    );
  }
}

String _$syllabusDesignerServiceHash() =>
    r'1aa114d443cb8ca1bf04a6510cf79c06d8ebe5dd';

/// [SessionExportService]의 싱글톤 인스턴스 제공.
///
/// 채팅 세션과 상태 변화를 JSON 파일로 내보냅니다.

@ProviderFor(sessionExportService)
final sessionExportServiceProvider = SessionExportServiceProvider._();

/// [SessionExportService]의 싱글톤 인스턴스 제공.
///
/// 채팅 세션과 상태 변화를 JSON 파일로 내보냅니다.

final class SessionExportServiceProvider
    extends
        $FunctionalProvider<
          SessionExportService,
          SessionExportService,
          SessionExportService
        >
    with $Provider<SessionExportService> {
  /// [SessionExportService]의 싱글톤 인스턴스 제공.
  ///
  /// 채팅 세션과 상태 변화를 JSON 파일로 내보냅니다.
  SessionExportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionExportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionExportServiceHash();

  @$internal
  @override
  $ProviderElement<SessionExportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionExportService create(Ref ref) {
    return sessionExportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionExportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionExportService>(value),
    );
  }
}

String _$sessionExportServiceHash() =>
    r'c98ab9ebd79e4f4d62d6455bd6f17ea623addc92';

/// [WikidataClient]의 싱글톤 인스턴스 제공.
///
/// 학습 주제에 대한 개념 정보를 Wikidata에서 검색합니다.

@ProviderFor(wikidataClient)
final wikidataClientProvider = WikidataClientProvider._();

/// [WikidataClient]의 싱글톤 인스턴스 제공.
///
/// 학습 주제에 대한 개념 정보를 Wikidata에서 검색합니다.

final class WikidataClientProvider
    extends $FunctionalProvider<WikidataClient, WikidataClient, WikidataClient>
    with $Provider<WikidataClient> {
  /// [WikidataClient]의 싱글톤 인스턴스 제공.
  ///
  /// 학습 주제에 대한 개념 정보를 Wikidata에서 검색합니다.
  WikidataClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wikidataClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wikidataClientHash();

  @$internal
  @override
  $ProviderElement<WikidataClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WikidataClient create(Ref ref) {
    return wikidataClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WikidataClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WikidataClient>(value),
    );
  }
}

String _$wikidataClientHash() => r'520c6d8a89c5ca1d376d30521b5e313a9b53a45c';

/// [RagService]의 싱글톤 인스턴스 제공.
///
/// 교수설계 PDF에서 관련 이론을 벡터 검색합니다.

@ProviderFor(ragService)
final ragServiceProvider = RagServiceProvider._();

/// [RagService]의 싱글톤 인스턴스 제공.
///
/// 교수설계 PDF에서 관련 이론을 벡터 검색합니다.

final class RagServiceProvider
    extends $FunctionalProvider<RagService, RagService, RagService>
    with $Provider<RagService> {
  /// [RagService]의 싱글톤 인스턴스 제공.
  ///
  /// 교수설계 PDF에서 관련 이론을 벡터 검색합니다.
  RagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ragServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ragServiceHash();

  @$internal
  @override
  $ProviderElement<RagService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RagService create(Ref ref) {
    return ragService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RagService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RagService>(value),
    );
  }
}

String _$ragServiceHash() => r'97ab3e69d4c719fd40b99d0dc9eee0d6883e015e';

/// [StepProgressService]의 싱글톤 인스턴스 제공.
///
/// in-class 튜터 턴 종료 후 현재 단계의 학습목표 달성 여부를 판정합니다.

@ProviderFor(stepProgressService)
final stepProgressServiceProvider = StepProgressServiceProvider._();

/// [StepProgressService]의 싱글톤 인스턴스 제공.
///
/// in-class 튜터 턴 종료 후 현재 단계의 학습목표 달성 여부를 판정합니다.

final class StepProgressServiceProvider
    extends
        $FunctionalProvider<
          StepProgressService,
          StepProgressService,
          StepProgressService
        >
    with $Provider<StepProgressService> {
  /// [StepProgressService]의 싱글톤 인스턴스 제공.
  ///
  /// in-class 튜터 턴 종료 후 현재 단계의 학습목표 달성 여부를 판정합니다.
  StepProgressServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stepProgressServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stepProgressServiceHash();

  @$internal
  @override
  $ProviderElement<StepProgressService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StepProgressService create(Ref ref) {
    return stepProgressService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StepProgressService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StepProgressService>(value),
    );
  }
}

String _$stepProgressServiceHash() =>
    r'072f845bc835f654df09cda3a7f6e8a91295ad95';

/// LLM 호출(Analyst/Tutor/Feedback/Designer)이 진행 중인지 표시하는 휘발성 플래그.
///
/// `isDesigning`이 syllabus 설계 단계만 가리키는 것과 달리,
/// 이 플래그는 **모든 LLM 호출 구간**(Analyst/Tutor 스트리밍/Feedback/Design + 자동 Tutor)을 덮어
/// 사용자가 처리 중에 추가 입력을 보내 흐름이 이중 실행되는 것을 막는다.
///
/// SharedPreferences에 영속화하지 않는다 — 앱 종료 시 진행 중이던 호출은 같이 사라지므로
/// 다음 실행에 가져갈 의미가 없는 일시 상태이기 때문이다.

@ProviderFor(IsProcessing)
final isProcessingProvider = IsProcessingProvider._();

/// LLM 호출(Analyst/Tutor/Feedback/Designer)이 진행 중인지 표시하는 휘발성 플래그.
///
/// `isDesigning`이 syllabus 설계 단계만 가리키는 것과 달리,
/// 이 플래그는 **모든 LLM 호출 구간**(Analyst/Tutor 스트리밍/Feedback/Design + 자동 Tutor)을 덮어
/// 사용자가 처리 중에 추가 입력을 보내 흐름이 이중 실행되는 것을 막는다.
///
/// SharedPreferences에 영속화하지 않는다 — 앱 종료 시 진행 중이던 호출은 같이 사라지므로
/// 다음 실행에 가져갈 의미가 없는 일시 상태이기 때문이다.
final class IsProcessingProvider extends $NotifierProvider<IsProcessing, bool> {
  /// LLM 호출(Analyst/Tutor/Feedback/Designer)이 진행 중인지 표시하는 휘발성 플래그.
  ///
  /// `isDesigning`이 syllabus 설계 단계만 가리키는 것과 달리,
  /// 이 플래그는 **모든 LLM 호출 구간**(Analyst/Tutor 스트리밍/Feedback/Design + 자동 Tutor)을 덮어
  /// 사용자가 처리 중에 추가 입력을 보내 흐름이 이중 실행되는 것을 막는다.
  ///
  /// SharedPreferences에 영속화하지 않는다 — 앱 종료 시 진행 중이던 호출은 같이 사라지므로
  /// 다음 실행에 가져갈 의미가 없는 일시 상태이기 때문이다.
  IsProcessingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isProcessingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isProcessingHash();

  @$internal
  @override
  IsProcessing create() => IsProcessing();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isProcessingHash() => r'6b32c4f4c6b962fd3f0193af633c11ba56138891';

/// LLM 호출(Analyst/Tutor/Feedback/Designer)이 진행 중인지 표시하는 휘발성 플래그.
///
/// `isDesigning`이 syllabus 설계 단계만 가리키는 것과 달리,
/// 이 플래그는 **모든 LLM 호출 구간**(Analyst/Tutor 스트리밍/Feedback/Design + 자동 Tutor)을 덮어
/// 사용자가 처리 중에 추가 입력을 보내 흐름이 이중 실행되는 것을 막는다.
///
/// SharedPreferences에 영속화하지 않는다 — 앱 종료 시 진행 중이던 호출은 같이 사라지므로
/// 다음 실행에 가져갈 의미가 없는 일시 상태이기 때문이다.

abstract class _$IsProcessing extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 앱의 모든 채팅 세션을 관리하는 상태 노티파이어.
///
/// 내부적으로는 [List<ChatSession>] 형태를 유지하지만, 단일 세션 모드로 동작한다.
/// 따라서 상태에는 최대 하나의 세션만 유지된다.

@ProviderFor(ChatSessions)
final chatSessionsProvider = ChatSessionsProvider._();

/// 앱의 모든 채팅 세션을 관리하는 상태 노티파이어.
///
/// 내부적으로는 [List<ChatSession>] 형태를 유지하지만, 단일 세션 모드로 동작한다.
/// 따라서 상태에는 최대 하나의 세션만 유지된다.
final class ChatSessionsProvider
    extends $NotifierProvider<ChatSessions, List<ChatSession>> {
  /// 앱의 모든 채팅 세션을 관리하는 상태 노티파이어.
  ///
  /// 내부적으로는 [List<ChatSession>] 형태를 유지하지만, 단일 세션 모드로 동작한다.
  /// 따라서 상태에는 최대 하나의 세션만 유지된다.
  ChatSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSessionsHash();

  @$internal
  @override
  ChatSessions create() => ChatSessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ChatSession> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ChatSession>>(value),
    );
  }
}

String _$chatSessionsHash() => r'030f67eff369600d790370b3b7f9fb882c198f14';

/// 앱의 모든 채팅 세션을 관리하는 상태 노티파이어.
///
/// 내부적으로는 [List<ChatSession>] 형태를 유지하지만, 단일 세션 모드로 동작한다.
/// 따라서 상태에는 최대 하나의 세션만 유지된다.

abstract class _$ChatSessions extends $Notifier<List<ChatSession>> {
  List<ChatSession> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<ChatSession>, List<ChatSession>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ChatSession>, List<ChatSession>>,
              List<ChatSession>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 현재 화면에 표시 중인 채팅 세션의 ID를 추적하는 상태 노티파이어.
///
/// null이면 아직 세션이 선택되지 않은 상태이며,
/// 첫 메시지 전송 시 새 세션이 자동 생성된다.

@ProviderFor(ActiveSessionId)
final activeSessionIdProvider = ActiveSessionIdProvider._();

/// 현재 화면에 표시 중인 채팅 세션의 ID를 추적하는 상태 노티파이어.
///
/// null이면 아직 세션이 선택되지 않은 상태이며,
/// 첫 메시지 전송 시 새 세션이 자동 생성된다.
final class ActiveSessionIdProvider
    extends $NotifierProvider<ActiveSessionId, String?> {
  /// 현재 화면에 표시 중인 채팅 세션의 ID를 추적하는 상태 노티파이어.
  ///
  /// null이면 아직 세션이 선택되지 않은 상태이며,
  /// 첫 메시지 전송 시 새 세션이 자동 생성된다.
  ActiveSessionIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionIdHash();

  @$internal
  @override
  ActiveSessionId create() => ActiveSessionId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeSessionIdHash() => r'd0722f2f45afec2aebe6ea2b0ab34a426cc8d178';

/// 현재 화면에 표시 중인 채팅 세션의 ID를 추적하는 상태 노티파이어.
///
/// null이면 아직 세션이 선택되지 않은 상태이며,
/// 첫 메시지 전송 시 새 세션이 자동 생성된다.

abstract class _$ActiveSessionId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// [activeSessionIdProvider]와 [chatSessionsProvider]를 조합하여 현재 활성화된 [ChatSession] 객체를 반환하는 파생(computed) 프로바이더.
///
/// UI에서 현재 대화 내용을 표시할 때 `ref.watch`로 구독하며,
/// 활성 ID가 없거나 해당 세션이 없으면 null을 반환한다.

@ProviderFor(activeSession)
final activeSessionProvider = ActiveSessionProvider._();

/// [activeSessionIdProvider]와 [chatSessionsProvider]를 조합하여 현재 활성화된 [ChatSession] 객체를 반환하는 파생(computed) 프로바이더.
///
/// UI에서 현재 대화 내용을 표시할 때 `ref.watch`로 구독하며,
/// 활성 ID가 없거나 해당 세션이 없으면 null을 반환한다.

final class ActiveSessionProvider
    extends $FunctionalProvider<ChatSession?, ChatSession?, ChatSession?>
    with $Provider<ChatSession?> {
  /// [activeSessionIdProvider]와 [chatSessionsProvider]를 조합하여 현재 활성화된 [ChatSession] 객체를 반환하는 파생(computed) 프로바이더.
  ///
  /// UI에서 현재 대화 내용을 표시할 때 `ref.watch`로 구독하며,
  /// 활성 ID가 없거나 해당 세션이 없으면 null을 반환한다.
  ActiveSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionHash();

  @$internal
  @override
  $ProviderElement<ChatSession?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatSession? create(Ref ref) {
    return activeSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSession?>(value),
    );
  }
}

String _$activeSessionHash() => r'6e11044f53beef2dd335bb7031ff3c4d66174e50';

/// ============================================================
/// ChatController: Stateless Micro-Agent 패턴의 오케스트레이터
/// ============================================================
///
/// 이 컨트롤러는 "LLM이 판단"하는 Fat Agent 방식이 아닌,
/// "앱이 판단하고 LLM은 생성만"하는 Thin Micro-Services 패턴을 구현합니다.
///
/// 핵심 역할:
/// 1. 상태 기반 라우팅: 학습 상태에 따라 적절한 Micro-Agent로 분기
/// 2. Service 오케스트레이션: 각 서비스를 호출하고 결과를 조율
/// 3. 세션 관리: 메시지 추가, 상태 변화 추적, 히스토리 구성
///
/// Flow 종류:
/// - Analyst Flow: 정보 수집 (JSON 추출)
/// - Tutor Flow: 실제 수업 (스트리밍 응답)
/// - Feedback Flow: 피드백 처리 (JSON 추출)
/// - Syllabus Design: 커리큘럼 생성 (백그라운드)
///
/// 의사결정 트리:
/// ```
/// sendMessage()
///   ├─ isDesigning? → 무시
///   ├─ isCourseCompleted? → Analyst (새 학습)
///   ├─ !isReady? → Analyst (정보 수집)
///   └─ isReady? → Intent 분류
///       ├─ inClass → Tutor (수업)
///       └─ outOfClass → Feedback (피드백)
/// ```
///
/// 사용처: [ChatInput]

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// ============================================================
/// ChatController: Stateless Micro-Agent 패턴의 오케스트레이터
/// ============================================================
///
/// 이 컨트롤러는 "LLM이 판단"하는 Fat Agent 방식이 아닌,
/// "앱이 판단하고 LLM은 생성만"하는 Thin Micro-Services 패턴을 구현합니다.
///
/// 핵심 역할:
/// 1. 상태 기반 라우팅: 학습 상태에 따라 적절한 Micro-Agent로 분기
/// 2. Service 오케스트레이션: 각 서비스를 호출하고 결과를 조율
/// 3. 세션 관리: 메시지 추가, 상태 변화 추적, 히스토리 구성
///
/// Flow 종류:
/// - Analyst Flow: 정보 수집 (JSON 추출)
/// - Tutor Flow: 실제 수업 (스트리밍 응답)
/// - Feedback Flow: 피드백 처리 (JSON 추출)
/// - Syllabus Design: 커리큘럼 생성 (백그라운드)
///
/// 의사결정 트리:
/// ```
/// sendMessage()
///   ├─ isDesigning? → 무시
///   ├─ isCourseCompleted? → Analyst (새 학습)
///   ├─ !isReady? → Analyst (정보 수집)
///   └─ isReady? → Intent 분류
///       ├─ inClass → Tutor (수업)
///       └─ outOfClass → Feedback (피드백)
/// ```
///
/// 사용처: [ChatInput]
final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, void> {
  /// ============================================================
  /// ChatController: Stateless Micro-Agent 패턴의 오케스트레이터
  /// ============================================================
  ///
  /// 이 컨트롤러는 "LLM이 판단"하는 Fat Agent 방식이 아닌,
  /// "앱이 판단하고 LLM은 생성만"하는 Thin Micro-Services 패턴을 구현합니다.
  ///
  /// 핵심 역할:
  /// 1. 상태 기반 라우팅: 학습 상태에 따라 적절한 Micro-Agent로 분기
  /// 2. Service 오케스트레이션: 각 서비스를 호출하고 결과를 조율
  /// 3. 세션 관리: 메시지 추가, 상태 변화 추적, 히스토리 구성
  ///
  /// Flow 종류:
  /// - Analyst Flow: 정보 수집 (JSON 추출)
  /// - Tutor Flow: 실제 수업 (스트리밍 응답)
  /// - Feedback Flow: 피드백 처리 (JSON 추출)
  /// - Syllabus Design: 커리큘럼 생성 (백그라운드)
  ///
  /// 의사결정 트리:
  /// ```
  /// sendMessage()
  ///   ├─ isDesigning? → 무시
  ///   ├─ isCourseCompleted? → Analyst (새 학습)
  ///   ├─ !isReady? → Analyst (정보 수집)
  ///   └─ isReady? → Intent 분류
  ///       ├─ inClass → Tutor (수업)
  ///       └─ outOfClass → Feedback (피드백)
  /// ```
  ///
  /// 사용처: [ChatInput]
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();
}

String _$chatControllerHash() => r'30b49cfbb034f96b0ae473b3ee7296f583da2d81';

/// ============================================================
/// ChatController: Stateless Micro-Agent 패턴의 오케스트레이터
/// ============================================================
///
/// 이 컨트롤러는 "LLM이 판단"하는 Fat Agent 방식이 아닌,
/// "앱이 판단하고 LLM은 생성만"하는 Thin Micro-Services 패턴을 구현합니다.
///
/// 핵심 역할:
/// 1. 상태 기반 라우팅: 학습 상태에 따라 적절한 Micro-Agent로 분기
/// 2. Service 오케스트레이션: 각 서비스를 호출하고 결과를 조율
/// 3. 세션 관리: 메시지 추가, 상태 변화 추적, 히스토리 구성
///
/// Flow 종류:
/// - Analyst Flow: 정보 수집 (JSON 추출)
/// - Tutor Flow: 실제 수업 (스트리밍 응답)
/// - Feedback Flow: 피드백 처리 (JSON 추출)
/// - Syllabus Design: 커리큘럼 생성 (백그라운드)
///
/// 의사결정 트리:
/// ```
/// sendMessage()
///   ├─ isDesigning? → 무시
///   ├─ isCourseCompleted? → Analyst (새 학습)
///   ├─ !isReady? → Analyst (정보 수집)
///   └─ isReady? → Intent 분류
///       ├─ inClass → Tutor (수업)
///       └─ outOfClass → Feedback (피드백)
/// ```
///
/// 사용처: [ChatInput]

abstract class _$ChatController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
