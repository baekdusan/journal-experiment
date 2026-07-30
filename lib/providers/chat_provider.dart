import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import '../models/learning_state.dart';
import '../models/state_change_event.dart';
import '../providers/learning_state_provider.dart';
import '../providers/streaming_message_provider.dart';
import '../services/gemini_service.dart';
import '../services/intent_classifier_service.dart';
import '../services/conversational_agent_service.dart';
import '../services/syllabus_designer_service.dart';
import '../services/step_progress_service.dart';
import '../services/session_export_service.dart';
import '../config/agent_prompts.dart';
import '../config/experiment_config.dart';

part 'chat_provider.g.dart';

/// [GeminiService]의 싱글톤 인스턴스를 제공하는 프로바이더.
///
/// `keepAlive: true` 설정으로 앱 생명주기 동안 인스턴스가 유지되어
/// 불필요한 재생성을 방지하고 연결 상태를 보존한다.
@Riverpod(keepAlive: true)
GeminiService geminiService(Ref ref) {
  return GeminiService();
}

/// [IntentClassifierService]의 싱글톤 인스턴스 제공.
///
/// 사용자 발화가 "수업 내(inClass)" vs "수업 외(outOfClass)"인지 분류합니다.
@Riverpod(keepAlive: true)
IntentClassifierService intentClassifierService(Ref ref) {
  return IntentClassifierService();
}

/// [ConversationalAgentService]의 싱글톤 인스턴스 제공.
///
/// Analyst/Tutor/Feedback 세 가지 모드의 프롬프트와 실행을 담당합니다.
@Riverpod(keepAlive: true)
ConversationalAgentService conversationalAgentService(Ref ref) {
  return ConversationalAgentService();
}

/// [SyllabusDesignerService]의 싱글톤 인스턴스 제공.
///
/// 학습자 프로파일 기반으로 ADDIE 모델 커리큘럼을 생성합니다.
@Riverpod(keepAlive: true)
SyllabusDesignerService syllabusDesignerService(Ref ref) {
  return SyllabusDesignerService();
}

/// [SessionExportService]의 싱글톤 인스턴스 제공.
///
/// 채팅 세션과 상태 변화를 JSON 파일로 내보냅니다.
@Riverpod(keepAlive: true)
SessionExportService sessionExportService(Ref ref) {
  return SessionExportService();
}

/// [StepProgressService]의 싱글톤 인스턴스 제공.
///
/// in-class 튜터 턴 종료 후 현재 단계의 학습목표 달성 여부를 판정합니다.
@Riverpod(keepAlive: true)
StepProgressService stepProgressService(Ref ref) {
  return StepProgressService();
}

/// LLM 호출(Analyst/Tutor/Feedback/Designer)이 진행 중인지 표시하는 휘발성 플래그.
///
/// `isDesigning`이 syllabus 설계 단계만 가리키는 것과 달리,
/// 이 플래그는 **모든 LLM 호출 구간**(Analyst/Tutor 스트리밍/Feedback/Design + 자동 Tutor)을 덮어
/// 사용자가 처리 중에 추가 입력을 보내 흐름이 이중 실행되는 것을 막는다.
///
/// SharedPreferences에 영속화하지 않는다 — 앱 종료 시 진행 중이던 호출은 같이 사라지므로
/// 다음 실행에 가져갈 의미가 없는 일시 상태이기 때문이다.
@Riverpod(keepAlive: true)
class IsProcessing extends _$IsProcessing {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }
}

/// 앱의 모든 채팅 세션을 관리하는 상태 노티파이어.
///
/// 내부적으로는 [List<ChatSession>] 형태를 유지하지만, 단일 세션 모드로 동작한다.
/// 따라서 상태에는 최대 하나의 세션만 유지된다.
@riverpod
class ChatSessions extends _$ChatSessions {
  @override
  List<ChatSession> build() {
    return [];
  }

  /// 새 [ChatSession]을 세션 목록에 추가한다.
  ///
  /// 단일 세션 모드이므로 기존 세션이 있더라도 새 세션 하나로 교체한다.
  void addSession(ChatSession session) {
    state = [session];
  }

  /// 동일한 ID를 가진 세션을 찾아 새 세션으로 교체한다.
  ///
  /// 메시지 추가, 제목 변경 등 세션 내용이 업데이트될 때마다 호출된다.
  /// 불변성을 유지하기 위해 기존 세션을 수정하지 않고 새 객체로 대체한다.
  void updateSession(ChatSession session) {
    state = [session];
  }

  /// 지정된 ID의 세션을 목록에서 제거한다.
  ///
  /// 현재 단일 세션을 비우는 내부 정리용 메서드다.
  void deleteSession(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  /// 현재 단일 세션을 비운다.
  void clear() {
    state = [];
  }
}

/// 현재 화면에 표시 중인 채팅 세션의 ID를 추적하는 상태 노티파이어.
///
/// null이면 아직 세션이 선택되지 않은 상태이며,
/// 첫 메시지 전송 시 새 세션이 자동 생성된다.
@riverpod
class ActiveSessionId extends _$ActiveSessionId {
  @override
  String? build() {
    return null;
  }

  /// 활성 세션 ID를 변경한다.
  ///
  /// 단일 세션 모드에서는 현재 세션을 식별하는 용도로만 사용된다.
  /// 세션이 초기화되면 null로 돌아간다.
  void set(String? id) {
    state = id;
  }
}

/// [activeSessionIdProvider]와 [chatSessionsProvider]를 조합하여 현재 활성화된 [ChatSession] 객체를 반환하는 파생(computed) 프로바이더.
///
/// UI에서 현재 대화 내용을 표시할 때 `ref.watch`로 구독하며,
/// 활성 ID가 없거나 해당 세션이 없으면 null을 반환한다.
@riverpod
ChatSession? activeSession(Ref ref) {
  final sessions = ref.watch(chatSessionsProvider);
  final activeId = ref.watch(activeSessionIdProvider);
  if (sessions.isEmpty) return null;
  if (activeId == null) return sessions.first;

  for (final session in sessions) {
    if (session.id == activeId) {
      return session;
    }
  }

  return sessions.first;
}

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
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  int _turnCounter = 0;

  /// 동시에 진행 중인 처리 작업 수. 0이 될 때만 [isProcessingProvider]를 false로 내린다.
  ///
  /// 사용 이유: `sendMessage`가 백그라운드 Future(`_startSyllabusDesign` 내부)를 띄우고
  /// 곧장 return하는 경로 때문에, 단순 bool 플래그로는 백그라운드 진행 중에 플래그가 풀려버린다.
  /// 카운터로 `_enter`/`_exit`을 짝지어 호출하면 sendMessage가 finally에서 빠져나가도
  /// 백그라운드가 살아있는 동안 isProcessing이 true로 유지된다.
  int _activeCount = 0;

  @override
  FutureOr<void> build() {
    // Nothing to initialize
  }

  /// 처리 작업 진입: 카운터 증가 및 [isProcessingProvider] true로 설정.
  void _enter() {
    _activeCount += 1;
    ref.read(isProcessingProvider.notifier).set(true);
  }

  /// 처리 작업 종료: 카운터 감소, 0이면 [isProcessingProvider] false로 해제.
  void _exit() {
    _activeCount -= 1;
    if (_activeCount <= 0) {
      _activeCount = 0;
      ref.read(isProcessingProvider.notifier).set(false);
    }
  }

  /// ============================================================
  /// 메인 진입점: 사용자 메시지를 받아 상태 기반으로 적절한 흐름으로 라우팅
  /// ============================================================
  ///
  /// ChatController의 핵심 메서드로, 모든 사용자 입력이 이 메서드를 거쳐갑니다.
  /// "앱이 판단하고 LLM은 생성만" 하는 Stateless Micro-Agent 패턴의 오케스트레이터입니다.
  ///
  /// 의사결정 흐름:
  /// 1. 세션 생성/조회
  /// 2. 상태 체크 → 적절한 Flow로 라우팅
  ///    - 설계 중? → 무시 (중복 방지)
  ///    - 완료 후? → Analyst Flow (새 학습 시작)
  ///    - 준비 안됨? → Analyst Flow (정보 수집)
  ///    - 준비 완료? → Intent 분류 → Tutor/Feedback Flow
  Future<void> sendMessage(String text) async {
    // ============================================================
    // 0. 진입 가드: 이미 LLM 호출이 진행 중이면 무시
    // ============================================================
    // Analyst/Tutor/Feedback/Designer 어느 것이든 진행 중이면 false 리턴 대신 그냥 무시한다.
    // UI(chat_input)도 isProcessing을 watch하여 입력을 막지만,
    // 그 가드와 실제 호출 시작 사이의 미세한 윈도우를 컨트롤러에서도 한 번 더 닫는다.
    if (ref.read(isProcessingProvider)) {
      return;
    }

    _enter();
    try {
      await _sendMessageImpl(text);
    } finally {
      _exit();
    }
  }

  Future<void> _sendMessageImpl(String text) async {
    _turnCounter += 1;
    final activeId = ref.read(activeSessionIdProvider);
    final sessions = ref.read(chatSessionsProvider);

    // ============================================================
    // 1. 세션 준비: 없으면 새로 생성, 있으면 조회
    // ============================================================
    ChatSession? session;
    if (activeId == null) {
      // 활성 세션이 없으면 새 세션을 생성하고, 첫 메시지 앞부분을 제목으로 사용한다.
      session = ChatSession(
        title: text.length > 20 ? '${text.substring(0, 20)}...' : text,
      );
      ref.read(chatSessionsProvider.notifier).addSession(session);
      ref.read(activeSessionIdProvider.notifier).set(session.id);
    } else {
      for (final existing in sessions) {
        if (existing.id == activeId) {
          session = existing;
          break;
        }
      }

      session ??= sessions.isNotEmpty ? sessions.first : null;
      if (session == null) {
        session = ChatSession(
          title: text.length > 20 ? '${text.substring(0, 20)}...' : text,
        );
        ref.read(chatSessionsProvider.notifier).addSession(session);
      }
      ref.read(activeSessionIdProvider.notifier).set(session.id);
    }

    // 사용자 메시지를 세션에 추가
    _appendMessage(session.id, Message(role: MessageRole.user, content: text));

    // ============================================================
    // 실험 대조군(free form): 구조화 라우팅을 모두 건너뛰고
    // 단일 프롬프트로 자유 대화 튜터링만 수행한다.
    // ============================================================
    if (ExperimentConfig.isControl) {
      _log('condition', {'turn': _turnCounter, 'value': 'control'});
      await _runFreeformFlow(session.id, text);
      return;
    }

    // ============================================================
    // 2. 현재 학습 상태 조회 및 로깅
    // ============================================================
    final learning = ref.read(learningStateProvider);
    _log('turn.start', {
      'turn': _turnCounter,
      'text': text,
      'mandatory': learning.learnerProfile.isLearnerProfileFilled,
      'isDesignFilled': learning.instructionalDesign.isDesignFilled,
      'designing': learning.isDesigning,
      'designReady': learning.showDesignReady,
      'completed': learning.isCourseCompleted,
      'subject': learning.learnerProfile.subject,
      'goal': learning.learnerProfile.goal,
      'totalSteps': learning.instructionalDesign.totalSteps,
    });

    // ============================================================
    // 3. 상태 기반 라우팅: "앱이 판단"하는 핵심 로직
    // ============================================================

    // 3-1. 설계 중이면 무시 (중복 요청 방지)
    if (learning.isDesigning) {
      return;
    }

    // 3-2. 학습 완료 후 새 대화 → Analyst로 재시작
    if (learning.isCourseCompleted) {
      await _runAnalystFlow(session.id, text, learning, forceAnalyst: true);
      return;
    }

    // 3-3. 프로파일/설계 미완성 → Analyst로 정보 수집
    final isReady = learning.learnerProfile.isLearnerProfileFilled &&
        learning.instructionalDesign.isDesignFilled;
    if (!isReady) {
      await _runAnalystFlow(session.id, text, learning);
      return;
    }

    // 3-4. 준비 완료 → Intent 분류 후 Tutor/Feedback 선택
    final intentService = ref.read(intentClassifierServiceProvider);
    final previousTutorMessage = _getLastTutorMessage(session.id);
    final intent = await intentService.classify(
      text,
      previousTutorMessage: previousTutorMessage,
    );
    _log('intent', {
      'turn': _turnCounter,
      'value': intent.name,
    });

    // Intent 결과에 따라 분기
    if (intent == IntentResult.inClass) {
      await _runTutorFlow(session.id, text);  // 수업 내 발화 → 튜터링
    } else {
      await _runFeedbackFlow(session.id, text);  // 수업 외 발화 → 피드백
    }
  }

  /// 활성 세션 ID를 null로 초기화하여 새 대화를 시작할 준비를 한다.
  ///
  /// 단일 세션 모드에서 현재 대화와 학습 상태를 모두 초기화한다.
  /// 다음 메시지 전송 시 새 세션이 자동 생성된다.
  void createNewSession() {
    ref.read(chatSessionsProvider.notifier).clear();
    ref.read(activeSessionIdProvider.notifier).set(null);
    ref.read(streamingMessageProvider.notifier).clear();
    _turnCounter = 0;
    unawaited(ref.read(learningStateProvider.notifier).reset());
  }

  /// 지정된 세션을 JSON 파일로 내보낸다.
  ///
  /// 세션의 메시지와 상태 변화 이벤트를 타임라인으로 조합하여
  /// 브라우저를 통해 다운로드한다.
  Future<void> downloadSession(String sessionId) async {
    try {
      final sessions = ref.read(chatSessionsProvider);
      final session = sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw Exception('세션을 찾을 수 없습니다.'),
      );

      final learningState = ref.read(learningStateProvider);
      final exportService = ref.read(sessionExportServiceProvider);

      await exportService.exportSession(session, learningState);
    } catch (e) {
      throw Exception('세션 다운로드 실패: $e');
    }
  }

  /// ============================================================
  /// Analyst Flow: 학습자 정보 수집 단계
  /// ============================================================
  ///
  /// 역할: ConversationalAgentService.runAnalyst를 호출하여
  ///       사용자 발화에서 학습 정보(subject, goal, level, tone)를 추출합니다.
  ///
  /// 실행 조건:
  /// - 프로파일 미완성 (subject/goal 없음)
  /// - 학습 완료 후 새 학습 시작 (forceAnalyst=true)
  ///
  /// 처리 흐름:
  /// 1. 이미 완성됨 + 강제 아님 → Feedback으로 전환
  /// 2. 프로파일 완성 + 설계 미완 → 설계 시작
  /// 3. runAnalyst 호출 → JSON 추출 (비스트리밍)
  /// 4. 추출된 정보로 상태 업데이트
  /// 5. 필수 정보 완성 시 → 자동으로 커리큘럼 생성 시작
  ///
  /// [forceAnalyst] 학습 완료 후 강제로 Analyst 모드 실행 여부
  Future<void> _runAnalystFlow(
    String sessionId,
    String userText,
    LearningState previous, {
    bool forceAnalyst = false,
  }) async {
    // ============================================================
    // 1. 상태 체크: 이미 준비됐으면 다른 Flow로 전환
    // ============================================================
    if (!forceAnalyst &&
        previous.learnerProfile.isLearnerProfileFilled &&
        previous.instructionalDesign.isDesignFilled) {
      await _runFeedbackFlow(sessionId, userText);
      return;
    }

    // 프로파일은 완성됐지만 설계가 안됐으면 → 설계 시작
    if (!forceAnalyst &&
        previous.learnerProfile.isLearnerProfileFilled &&
        !previous.instructionalDesign.isDesignFilled) {
      _startSyllabusDesign(sessionId, isRedesign: false);
      return;
    }

    // ============================================================
    // 2. Analyst Agent 호출: 정보 추출 (비스트리밍, JSON)
    // ============================================================
    final agent = ref.read(conversationalAgentServiceProvider);
    try {
      final result = await agent.runAnalyst(previous, userText);
      _log('analyst.extract', {
        'turn': _turnCounter,
        'subject': result.subject,
        'goal': result.goal,
        'level': result.level?.name,
        'tone': result.tonePreference?.name,
        // 게이트에 걸려 null이 된 필드를 구분하기 위해 원 확신도를 함께 남긴다.
        'confidence': result.fieldConfidence,
      });

      // ============================================================
      // 3. 추출된 정보로 학습 상태 업데이트
      // ============================================================
      await ref
          .read(learningStateProvider.notifier)
          .updateFromExtractedInfo(
            subject: result.subject,
            goal: result.goal,
            level: result.level,
            tonePreference: result.tonePreference,
          );

      final updated = ref.read(learningStateProvider);

      // ============================================================
      // 4. 프로필 변경 사항 추적 (디버깅/분석용)
      // ============================================================
      final profileChanges = <String, dynamic>{};
      if (result.subject != null) profileChanges['subject'] = result.subject;
      if (result.goal != null) profileChanges['goal'] = result.goal;
      if (result.level != null) profileChanges['level'] = result.level!.name;
      if (result.tonePreference != null) {
        profileChanges['tonePreference'] = result.tonePreference!.name;
      }
      if (profileChanges.isNotEmpty) {
        _recordStateChange(
          sessionId,
          StateChangeType.profileUpdated,
          profileChanges,
        );
      }

      // (자료 사전 취득 단계 없음 — 확정 실험설계(260624)에 따라 자료는
      //  Designer/Tutor가 Google Search grounding으로 호출 시점에 직접 취득한다.)

      // ============================================================
      // 5. 필수 정보 완성 체크 → 자동으로 커리큘럼 생성 시작
      // ============================================================
      final wasMandatory = previous.learnerProfile.isLearnerProfileFilled;
      final shouldTriggerDesign =
          updated.learnerProfile.isLearnerProfileFilled &&
          !updated.instructionalDesign.isDesignFilled &&
          (forceAnalyst || !wasMandatory);

      // ============================================================
      // 6. 사용자 응답 표시: 설계 시작 안내는 앱 상태 기준으로만 제어
      // ============================================================
      // 문구에 '로드맵'처럼 시각물을 암시하는 표현을 쓰지 않는다.
      // 로드맵 UI는 [ExperimentConfig.showLearningRoadmap]=false로 숨겨져 있어,
      // 보이지도 않는 것을 예고하면 학습자가 찾아 헤매게 되기 때문이다
      // (주 종속변수인 지각된 방향상실을 인위적으로 올린다).
      if (shouldTriggerDesign) {
        _appendAssistantMessage(
          sessionId,
          '좋아요. 필요한 정보를 확인했어요. 학습 순서를 정하고 바로 수업을 시작할게요.',
        );
      } else {
        final safeResponse = _sanitizeAnalystResponse(
          response: result.response,
          state: updated,
        );
        _appendAssistantMessage(sessionId, safeResponse);
      }

      if (shouldTriggerDesign) {
        _startSyllabusDesign(sessionId, isRedesign: false);
      }
    } catch (e, st) {
      _log('analyst.error', {'error': e.toString()});
      debugPrint('[Analyst ERROR] $e\n$st');
      _appendSystemMessage(sessionId, '요청을 처리하는 중 오류가 발생했어요. 다시 시도해 주세요.');
    }
  }

  /// ============================================================
  /// Tutor Flow: 실제 수업 진행 (스트리밍 응답)
  /// ============================================================
  ///
  /// 역할: 실시간 스트리밍으로 튜터링 응답을 생성합니다.
  ///
  /// 실행 조건:
  /// - 프로파일 완성됨 (subject, goal 있음)
  /// - 커리큘럼 생성됨
  /// - Intent Classifier가 "inClass" 판단 (수업 내 발화)
  ///
  /// 처리 흐름:
  /// 1. 대화 히스토리 구성 (최근 6개)
  /// 2. buildTutorSystemInstruction으로 시스템 프롬프트 생성 (매 턴 재빌드)
  /// 3. GeminiService.streamResponse 호출 (스트리밍)
  /// 4. 청크 단위로 수신하며 UI 실시간 업데이트
  /// 5. 완료 후 isStreaming=false 처리
  ///
  /// 특징:
  /// - JSON이 아닌 자연어 생성
  /// - 실시간 스트리밍으로 사용자 경험 향상
  /// - 대화 히스토리를 컨텍스트로 전달
  Future<void> _runTutorFlow(String sessionId, String userText) async {
    final learning = ref.read(learningStateProvider);
    final agent = ref.read(conversationalAgentServiceProvider);
    String? assistantId;
    try {
      // ============================================================
      // 1. 시스템 프롬프트 생성 (매 턴 상태 반영 재빌드)
      // ============================================================
      // 자료는 로컬 주입 없이 Google Search grounding으로 모델이 직접 취득한다.
      final systemInstruction = agent.buildTutorSystemInstruction(learning);

      // ============================================================
      // 2. 빈 메시지 생성 (스트리밍 준비)
      // ============================================================
      assistantId = const Uuid().v4();
      _appendMessage(
        sessionId,
        Message(
          id: assistantId,
          role: MessageRole.model,
          content: '',
          isStreaming: true,  // 스트리밍 중 표시
        ),
      );

      // ============================================================
      // 3. Gemini 스트리밍 API 호출
      // ============================================================
      final gemini = ref.read(geminiServiceProvider);
      final stream = gemini.streamResponse(
        _recentMessages(sessionId,
            excludeMessageId: assistantId, currentUserText: userText),
        userText,
        systemInstruction: systemInstruction,
        onGrounding: (queries, sources) =>
            _logGrounding(sessionId, 'tutor', queries, sources),
      );

      // ============================================================
      // 4. 스트리밍 수신: StreamingMessage Provider 업데이트
      // ============================================================
      // 스트리밍 상태 초기화
      ref.read(streamingMessageProvider.notifier).start(assistantId);

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
        // 경량 StreamingMessage Provider만 업데이트 (ChatSession은 완료 시 1회만)
        ref.read(streamingMessageProvider.notifier).appendChunk(chunk);
      }

      // 스트리밍 상태 정리
      ref.read(streamingMessageProvider.notifier).clear();

      // ============================================================
      // 5. 스트리밍 완료: ChatSession에 최종 메시지 저장 (1회만)
      // ============================================================
      final finalSessions = ref.read(chatSessionsProvider);
      final finalSession = finalSessions.firstWhere((s) => s.id == sessionId);
      final finalMessages = [
        for (final m in finalSession.messages)
          if (m.id == assistantId)
            m.copyWith(content: fullResponse, isStreaming: false)
          else
            m,
      ];
      ref
          .read(chatSessionsProvider.notifier)
          .updateSession(finalSession.copyWith(messages: finalMessages));

      // ============================================================
      // 6. designReady 플래그 정리 (설계 완료 안내 숨김)
      // ============================================================
      final latest = ref.read(learningStateProvider);
      if (latest.showDesignReady) {
        await ref.read(learningStateProvider.notifier).setDesignReady(false);
      }

      // ============================================================
      // 7. 단계 진행 평가 (in-class 턴 종료 후)
      // ============================================================
      // "앱이 판단" 원칙: StepProgressService는 완료 여부 신호만 생성하고,
      // 단계 전진(단조 증가)/완료 처리는 여기(앱)에서 수행한다.
      await _evaluateStepProgress(sessionId, userText);
    } catch (e) {
      // ============================================================
      // 에러 처리: 스트리밍 중단 시 에러 메시지 표시
      // ============================================================
      // 스트리밍 상태 정리
      ref.read(streamingMessageProvider.notifier).clear();

      if (assistantId != null) {
        final sessions = ref.read(chatSessionsProvider);
        final session = sessions.firstWhere((s) => s.id == sessionId);
        final updatedMessages = [
          for (final m in session.messages)
            if (m.id == assistantId)
              m.copyWith(
                content: '응답 생성 중 오류가 발생했어요. 다시 시도해 주세요.',
                isStreaming: false,
              )
            else
              m,
        ];
        ref
            .read(chatSessionsProvider.notifier)
            .updateSession(session.copyWith(messages: updatedMessages));
      } else {
        _appendSystemMessage(sessionId, '튜터 응답을 생성하는 중 오류가 발생했어요.');
      }
    }
  }

  /// 대조군(Naive) 전용 처리 흐름.
  ///
  /// 확정 실험설계(260624): 대조군은 **시스템 프롬프트가 전혀 없는 순수 모델**이다.
  /// 처치군의 상태 기반 라우팅(Intent · Analyst · Feedback · Syllabus · 단계 추적)을
  /// 모두 건너뛰고, 사용자 발화를 그대로 모델에 전달한다.
  /// 모델([AiModels.tutor]) · Google Search grounding · 스트리밍 · 히스토리 리밋은
  /// 처치군 Tutor와 동일하게 통제된다 (GeminiService 공용).
  Future<void> _runFreeformFlow(String sessionId, String userText) async {
    String? assistantId;
    try {
      assistantId = const Uuid().v4();
      _appendMessage(
        sessionId,
        Message(
          id: assistantId,
          role: MessageRole.model,
          content: '',
          isStreaming: true,
        ),
      );

      final gemini = ref.read(geminiServiceProvider);
      // systemInstruction 없이 호출 → 시스템 프롬프트 없는 순수 모델
      final stream = gemini.streamResponse(
        _recentMessages(sessionId,
            excludeMessageId: assistantId, currentUserText: userText),
        userText,
        onGrounding: (queries, sources) =>
            _logGrounding(sessionId, 'freeform', queries, sources),
      );

      ref.read(streamingMessageProvider.notifier).start(assistantId);

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
        ref.read(streamingMessageProvider.notifier).appendChunk(chunk);
      }

      ref.read(streamingMessageProvider.notifier).clear();

      final finalSessions = ref.read(chatSessionsProvider);
      final finalSession = finalSessions.firstWhere((s) => s.id == sessionId);
      final finalMessages = [
        for (final m in finalSession.messages)
          if (m.id == assistantId)
            m.copyWith(content: fullResponse, isStreaming: false)
          else
            m,
      ];
      ref
          .read(chatSessionsProvider.notifier)
          .updateSession(finalSession.copyWith(messages: finalMessages));
    } catch (e) {
      ref.read(streamingMessageProvider.notifier).clear();
      if (assistantId != null) {
        final sessions = ref.read(chatSessionsProvider);
        final session = sessions.firstWhere((s) => s.id == sessionId);
        final updatedMessages = [
          for (final m in session.messages)
            if (m.id == assistantId)
              m.copyWith(
                content: '응답 생성 중 오류가 발생했어요. 다시 시도해 주세요.',
                isStreaming: false,
              )
            else
              m,
        ];
        ref
            .read(chatSessionsProvider.notifier)
            .updateSession(session.copyWith(messages: updatedMessages));
      } else {
        _appendSystemMessage(sessionId, '응답을 생성하는 중 오류가 발생했어요.');
      }
      _log('freeform.error', {'error': e.toString()});
    }
  }

  /// ============================================================
  /// 단계 진행 평가: in-class 튜터 턴 종료 후 호출
  /// ============================================================
  ///
  /// [StepProgressService]로 현재 단계 학습목표 달성 여부(불리언 신호)를 받고,
  /// 앱이 단조 전진 규칙으로 단계를 전진하거나 수업 완료를 처리한다.
  ///
  /// - 완료 신호 + confidence ≥ 0.6 + 마지막 단계 → 수업 완료
  /// - 완료 신호 + confidence ≥ 0.6 + 그 외 → 다음 단계로 전진
  /// - 그 외 → 현재 단계 유지
  Future<void> _evaluateStepProgress(String sessionId, String userText) async {
    final learning = ref.read(learningStateProvider);
    final current = learning.currentStep;

    // syllabus가 없거나(자유대화 등) 이미 완료된 경우 평가하지 않는다.
    if (current == null || learning.isCourseCompleted) return;

    try {
      final progressSvc = ref.read(stepProgressServiceProvider);
      final history = _buildHistory(sessionId, userText, limit: 6);
      final result = await progressSvc.evaluate(
        currentStep: current,
        recentHistory: history,
      );

      _log('step.progress', {
        'turn': _turnCounter,
        'index': learning.currentStepIndex,
        'completed': result.stepCompleted,
        'confidence': result.confidence,
      });

      if (!result.stepCompleted || result.confidence < 0.6) return;

      if (learning.isLastStep) {
        await ref.read(learningStateProvider.notifier).markCourseCompleted();
        _recordStateChange(sessionId, StateChangeType.courseCompleted, {
          'completedAtStep': learning.currentStepIndex,
        });

        // 완료는 앱 상태만 바꾸므로 학습자에게는 아무 신호도 가지 않는다.
        // 마무리 발화를 한 번 더 돌려 종료 사실·정리·다음 안내를 튜터가 직접
        // 말하게 한다(설계 완료 후 자동으로 수업을 시작하는 것과 같은 방식).
        // 재귀는 없다 — 이 턴의 StepProgress는 isCourseCompleted에서 즉시 반환한다.
        await _runTutorFlow(sessionId, AgentPrompts.courseClosingCue);
      } else {
        final next = learning.currentStepIndex + 1;
        await ref.read(learningStateProvider.notifier).setCurrentStep(next);
        _recordStateChange(sessionId, StateChangeType.stepAdvanced, {
          'from': learning.currentStepIndex,
          'to': next,
        });
      }
    } catch (e) {
      // 진행 평가 실패는 수업 흐름을 막지 않는다 (graceful degradation).
      _log('step.progress.error', {'error': e.toString()});
    }
  }

  /// ============================================================
  /// Feedback Flow: 수업 외 발화 처리 (난이도/말투 변경, 재설계 요청)
  /// ============================================================
  ///
  /// 역할: ConversationalAgentService.runFeedback을 호출하여
  ///       수업과 관련 없는 피드백/요청을 처리합니다.
  ///
  /// 실행 조건:
  /// - 프로파일/설계 완성됨
  /// - Intent Classifier가 "outOfClass" 판단 (수업 외 발화)
  ///
  /// 처리 흐름:
  /// 1. 대화 히스토리 구성 (최근 6개)
  /// 2. runFeedback 호출 → JSON 추출 (비스트리밍)
  /// 3. 명시적 변경 요청 시 → 프로파일 업데이트 (level, tone)
  /// 4. 재설계 필요 + 명시적 요청 → 커리큘럼 재생성
  /// 5. 단순 피드백 → 응답만 표시
  ///
  /// 특징:
  /// - 대화 히스토리를 컨텍스트로 전달하여 맥락 파악
  /// - explicitChange=true일 때만 상태 변경 (추측 방지)
  /// - needs_redesign + explicitChange → 커리큘럼 재생성
  /// - 단순 잡담은 무시 (needs_redesign=false)
  Future<void> _runFeedbackFlow(String sessionId, String userText) async {
    final learning = ref.read(learningStateProvider);
    final agent = ref.read(conversationalAgentServiceProvider);
    try {
      // ============================================================
      // 1. 대화 히스토리 구성
      // ============================================================
      final history = _buildHistory(sessionId, userText, limit: 6);

      // ============================================================
      // 2. Feedback Agent 호출: 피드백 분석 (비스트리밍, JSON)
      // ============================================================
      final result = await agent.runFeedback(learning, userText, history);
      _appendAssistantMessage(sessionId, result.response);
      _log('feedback.result', {
        'turn': _turnCounter,
        'needsRedesign': result.needsRedesign,
        'explicitChange': result.explicitChange,
        'redesignRequest': result.redesignRequest,
      });

      // ============================================================
      // 2. 명시적 변경 요청 시 프로파일 업데이트
      // ============================================================
      if (result.explicitChange) {
        await ref
            .read(learningStateProvider.notifier)
            .updateFromExtractedInfo(
              level: result.level,
              tonePreference: result.tonePreference,
            );
      }

      // ============================================================
      // 3. 재설계 필요 + 명시적 요청 → 커리큘럼 재생성
      // ============================================================
      if (result.needsRedesign && result.explicitChange) {
        // 재설계 요청 추적
        _recordStateChange(
          sessionId,
          StateChangeType.redesignRequested,
          {
            'redesignRequest': result.redesignRequest ?? '',
            'level': result.level?.name,
            'tonePreference': result.tonePreference?.name,
          },
        );

        _startSyllabusDesign(
          sessionId,
          isRedesign: true,
          redesignRequest: result.redesignRequest,
        );
      } else if (result.needsRedesign && !result.explicitChange) {
        // 재설계 필요하지만 명시적 요청 아님 → 무시
        _log('feedback.ignored_redesign', {'reason': 'not_explicit'});
      }
    } catch (e) {
      _appendSystemMessage(sessionId, '피드백을 처리하는 중 오류가 발생했어요.');
    }
  }

  /// ============================================================
  /// Syllabus Design: 커리큘럼 생성/재생성 (백그라운드)
  /// ============================================================
  ///
  /// 역할: SyllabusDesignerService를 호출하여 학습 로드맵을 생성합니다.
  ///
  /// 실행 조건:
  /// - 필수 프로파일 완성 후 (Analyst Flow에서 자동 호출)
  /// - 명시적 재설계 요청 시 (Feedback Flow에서 호출)
  ///
  /// 처리 흐름:
  /// 1. isDesigning=true 설정 (중복 방지)
  /// 2. Future()로 비동기 실행 (블로킹 방지)
  /// 3. SyllabusDesignerService.generate 호출
  /// 4. 생성된 syllabus로 상태 업데이트
  /// 5. 완료 후 자동으로 _runTutorFlow 실행 (수업 시작)
  ///
  /// 특징:
  /// - 백그라운드 실행으로 UI 블로킹 방지
  /// - 완료 후 자동으로 수업 시작
  /// - redesignRequest로 재설계 시 사용자 요청 반영
  ///
  /// [isRedesign] 재설계 여부 (초기 생성=false, 재설계=true)
  /// [redesignRequest] 재설계 시 사용자의 구체적 요청
  void _startSyllabusDesign(
    String sessionId, {
    required bool isRedesign,
    String? redesignRequest,
  }) {
    final learning = ref.read(learningStateProvider);

    // ============================================================
    // 1. 중복 방지: 이미 설계 중이면 무시
    // ============================================================
    if (learning.isDesigning) return;

    _log('design.start', {
      'turn': _turnCounter,
      'isRedesign': isRedesign,
      'request': redesignRequest,
    });

    // ============================================================
    // 2. 설계 시작 플래그 설정
    // ============================================================
    unawaited(ref.read(learningStateProvider.notifier).setDesigning(true));

    // 커리큘럼 생성 시작 추적
    final designStartChanges = <String, dynamic>{
      'isRedesign': isRedesign,
    };
    if (redesignRequest != null) {
      designStartChanges['redesignRequest'] = redesignRequest;
    }
    _recordStateChange(
      sessionId,
      StateChangeType.syllabusGenerationStarted,
      designStartChanges,
    );

    // ============================================================
    // 3. 백그라운드 실행: UI 블로킹 방지
    // ============================================================
    // sendMessage의 try/finally는 이 Future를 await하지 않고 곧장 종료된다.
    // 따라서 Future 자체를 `_enter`/`_exit` 쌍으로 감싸 isProcessing이
    // design + 자동 Tutor 스트리밍이 끝날 때까지 true로 유지되도록 한다.
    _enter();
    Future(() async {
      try {
        // 설계자는 Google Search grounding으로 기존 커리큘럼·시험 범위를
        // 조사한 뒤 커리큘럼을 생성한다 (2단계: 검색 조사 → JSON 구조화).
        final designer = ref.read(syllabusDesignerServiceProvider);
        final result = await designer.generate(
          learning.learnerProfile,
          redesignRequest: redesignRequest,
        );
        final syllabus = result.syllabus;

        _log('design.generated', {
          'turn': _turnCounter,
          'steps': syllabus.length,
          'topics': syllabus.map((step) => step.topic).toList(),
          'searchQueries': result.searchQueries,
          'sources': result.sources,
        });
        if (result.searchQueries.isNotEmpty || result.sources.isNotEmpty) {
          _logGrounding(
              sessionId, 'designer', result.searchQueries, result.sources);
        }

        // ============================================================
        // 4. 생성된 커리큘럼으로 상태 업데이트
        // ============================================================
        await ref
            .read(learningStateProvider.notifier)
            .setSyllabus(syllabus);

        // 커리큘럼 생성 완료 추적
        _recordStateChange(
          sessionId,
          StateChangeType.syllabusGenerated,
          {
            'stepCount': syllabus.length,
            'steps': syllabus.map((step) => {
              'step': step.step,
              'topic': step.topic,
              'objective': step.objective,
            }).toList(),
          },
        );

        // ============================================================
        // 5. 완료 후 자동으로 수업 시작
        // ============================================================
        await _runTutorFlow(sessionId, '수업을 시작해줘');
      } catch (e) {
        _log('design.error', {'error': e.toString()});
        await ref
            .read(learningStateProvider.notifier)
            .setDesigning(false);
        _appendSystemMessage(sessionId, '학습 준비에 실패했어요. 잠시 후 다시 시도해 주세요.');
      } finally {
        _exit();
      }
    });
  }

  /// ============================================================
  /// Helper: 메시지 추가 헬퍼 메서드들
  /// ============================================================

  /// AI 응답 메시지 추가 (Analyst/Feedback Flow에서 사용)
  void _appendAssistantMessage(String sessionId, String content) {
    _appendMessage(sessionId, Message(role: MessageRole.model, content: content));
  }

  /// 시스템 에러 메시지 추가 (예외 처리 시 사용)
  void _appendSystemMessage(String sessionId, String content) {
    _appendMessage(sessionId, Message(role: MessageRole.system, content: content));
  }

  /// 메시지를 세션에 추가하고 상태 업데이트
  void _appendMessage(String sessionId, Message message) {
    final sessions = ref.read(chatSessionsProvider);
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updatedMessages = [...session.messages, message];
    ref
        .read(chatSessionsProvider.notifier)
        .updateSession(session.copyWith(messages: updatedMessages));
  }

  /// Google Search grounding 발동을 콘솔 로그 + 세션 타임라인에 기록한다.
  ///
  /// [source]: 발동 주체 ('tutor' | 'freeform' | 'designer').
  /// 세션 내보내기(JSON)의 stateChanges에 남아 확정 실험설계(260624) §6-4의
  /// 조절변수 '자료 검색 빈도' 산출에 쓰인다.
  void _logGrounding(
    String sessionId,
    String source,
    List<String> searchQueries,
    List<String> sources,
  ) {
    _log('grounding.$source', {
      'turn': _turnCounter,
      'searchQueries': searchQueries,
      'sources': sources,
    });
    _recordStateChange(sessionId, StateChangeType.groundingUsed, {
      'source': source,
      'searchQueries': searchQueries,
      'sources': sources,
    });
  }

  /// 학습 상태 변화를 타임라인 이벤트로 기록한다.
  ///
  /// 메시지 사이에 발생한 상태 변화를 추적하여 학습 플랜 생성 과정을 시각화할 수 있다.
  void _recordStateChange(
    String sessionId,
    StateChangeType type,
    Map<String, dynamic> changes,
  ) {
    final sessions = ref.read(chatSessionsProvider);
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final event = StateChangeEvent.create(type: type, changes: changes);
    final updatedStateChanges = [...session.stateChanges, event];
    ref
        .read(chatSessionsProvider.notifier)
        .updateSession(session.copyWith(stateChanges: updatedStateChanges));
  }

  /// ============================================================
  /// Helper: 대화 히스토리 구성 (Tutor Flow용)
  /// ============================================================
  ///
  /// 역할: 최근 N개의 대화를 "User: ...", "Tutor: ..." 형식으로 변환합니다.
  ///
  /// 사용처:
  /// - _runTutorFlow에서 프롬프트 생성 시 컨텍스트로 전달
  ///
  /// 처리:
  /// 1. system 메시지 제외 (사용자/AI만 포함)
  /// 2. 현재 사용자 메시지는 제외 (중복 방지)
  /// 3. 최근 N개만 선택 (기본 6개)
  /// 4. "User: ...", "Tutor: ..." 형식으로 변환
  ///
  /// [limit] 가져올 최대 메시지 수 (기본 6개)
  List<String> _buildHistory(
    String sessionId,
    String currentUserText, {
    int limit = 6,
  }) {
    final session = ref.read(chatSessionsProvider).firstWhere(
          (s) => s.id == sessionId,
        );

    // 1. system 메시지 제외
    final filtered = session.messages
        .where((m) => m.role != MessageRole.system)
        .toList();

    // 2. 현재 사용자 메시지 제외 (중복 방지)
    if (filtered.isNotEmpty &&
        filtered.last.role == MessageRole.user &&
        filtered.last.content == currentUserText) {
      filtered.removeLast();
    }

    // 3. 최근 N개만 선택
    final recent = filtered.length > limit
        ? filtered.sublist(filtered.length - limit)
        : filtered;

    // 4. 포맷팅: "User: ...", "Tutor: ..."
    return recent
        .map((m) =>
            m.role == MessageRole.user ? 'User: ${m.content}' : 'Tutor: ${m.content}')
        .toList();
  }

  /// ============================================================
  /// Helper: 마지막 튜터 메시지 조회 (Intent Classifier용)
  /// ============================================================
  ///
  /// 역할: Intent Classifier가 컨텍스트를 파악할 수 있도록
  ///       바로 직전 튜터 메시지를 제공합니다.
  ///
  /// 사용처:
  /// - sendMessage에서 Intent 분류 시 previousTutorMessage로 전달
  ///
  /// 반환:
  /// - 튜터 메시지가 있으면 마지막 내용 반환
  /// - 없으면 null 반환
  String? _getLastTutorMessage(String sessionId) {
    final session = ref.read(chatSessionsProvider).firstWhere(
          (s) => s.id == sessionId,
        );
    final tutorMessages = session.messages
        .where((m) => m.role == MessageRole.model)
        .toList();
    return tutorMessages.isEmpty ? null : tutorMessages.last.content;
  }

  String _sanitizeAnalystResponse({
    required String response,
    required LearningState state,
  }) {
    final normalized = response.trim();
    final mentionsRoadmap = RegExp(
      r'로드맵|학습 계획|커리큘럼',
      caseSensitive: false,
    ).hasMatch(normalized);

    if (!state.learnerProfile.isLearnerProfileFilled && mentionsRoadmap) {
      return _buildMissingProfilePrompt(state);
    }

    if (normalized.isEmpty) {
      return _buildMissingProfilePrompt(state);
    }

    return normalized;
  }

  String _buildMissingProfilePrompt(LearningState state) {
    final profile = state.learnerProfile;
    final missing = <String>[];
    if (profile.subject == null || profile.subject!.trim().isEmpty) {
      missing.add('무엇을 배우고 싶은지');
    }
    if (profile.goal == null || profile.goal!.trim().isEmpty) {
      missing.add('배워서 무엇을 하고 싶은지');
    }
    if (profile.level == null) {
      missing.add('현재 학습 수준');
    }
    if (profile.tonePreference == null) {
      missing.add('원하는 대화 말투');
    }

    if (missing.isEmpty) {
      return '좋아요. 필요한 정보를 정리하고 있어요.';
    }

    return '좋아요. 수업을 시작하기 전에 ${missing.join(', ')} 알려주세요.';
  }

  /// ============================================================
  /// Helper: 스트리밍 호출용 대화 히스토리 구성 (양 조건 공용)
  /// ============================================================
  ///
  /// 대화 메모리 정책: 양 조건 동일하게 **세션 전체 히스토리**를 전달한다.
  /// (30분 단일 세션이라 컨텍스트 부담이 작고, 윈도우 잘림으로 인한
  ///  선호·맥락 망각을 없앤다. 판정용 에이전트(StepProgress/Feedback)는
  ///  별도로 [_buildHistory]의 최근 6개 윈도우를 유지한다.)
  ///
  /// 처리:
  /// 1. system 메시지(에러 안내 등) 제외
  /// 2. 스트리밍용 빈 assistant 메시지([excludeMessageId]) 제외
  /// 3. 현재 턴의 사용자 메시지 제외 (새 user 메시지로 별도 전송되므로 중복 방지)
  /// 4. 히스토리가 model 메시지로 시작하지 않도록 선두의 model 메시지 제거
  ///    (Gemini chat history는 user로 시작해야 안전)
  List<Message> _recentMessages(
    String sessionId, {
    required String? excludeMessageId,
    required String currentUserText,
  }) {
    final session = ref.read(chatSessionsProvider).firstWhere(
          (s) => s.id == sessionId,
        );

    var recent = session.messages
        .where((m) =>
            m.role != MessageRole.system && m.id != excludeMessageId)
        .toList();

    if (recent.isNotEmpty &&
        recent.last.role == MessageRole.user &&
        recent.last.content == currentUserText) {
      recent.removeLast();
    }

    while (recent.isNotEmpty && recent.first.role != MessageRole.user) {
      recent = recent.sublist(1);
    }

    return recent;
  }

  /// ============================================================
  /// Helper: 디버깅용 로그 출력
  /// ============================================================
  ///
  /// 역할: Flow 실행 과정을 추적하고 디버깅합니다.
  ///
  /// 로그 종류:
  /// - turn.start: 턴 시작 + 현재 상태
  /// - intent: Intent 분류 결과
  /// - analyst.extract: Analyst 추출 결과
  /// - feedback.result: Feedback 처리 결과
  /// - design.start/generated/error: 커리큘럼 생성 과정
  void _log(String event, Map<String, dynamic> data) {
    final payload = const JsonEncoder.withIndent('  ').convert(data);
    debugPrint('[Flow] $event\n$payload\n');
  }
}
