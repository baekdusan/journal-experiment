import 'dart:convert';
import 'package:intl/intl.dart';
import '../config/ai_models.dart';
import '../config/experiment_config.dart';
import '../models/chat_session.dart';
import '../models/learning_state.dart';
import '../models/message.dart';
import '../models/state_change_event.dart';
import '../models/telemetry.dart';
import '../platform/web_env.dart';

/// 세션을 사후 분석용 JSON 파일로 내보내는 서비스.
///
/// Version 3.0: v2.1의 `timeline`은 그대로 두고(기존 분석 스크립트 호환),
/// 그 위에 다음을 통째로 싣는다.
/// - participant / environment : 참가자·시작 시각·브라우저·기기·빌드·모델 설정
/// - turns      : 턴별 라우팅·의도·읽기/작성 시간·지연·단계 인덱스
/// - llmCalls   : 호출별 에이전트·모델·토큰·지연·finishReason·프롬프트·원문
/// - flowEvents : 예전에 콘솔에만 찍히던 오케스트레이션 판정 로그 전부
/// - stateChanges : 필터 없이 원본 전부 (stepAdvanced·courseCompleted 포함)
/// - uiEvents   : 탭 이탈·창 크기·스크롤·버튼 클릭
/// - messages   : system 메시지(오류)까지, meta 포함
/// - finalLearningState / summary
///
/// 대조군도 같은 수집 계층을 타므로 조건 간 교란은 없다.
class SessionExportService {
  Future<void> exportSession(
    ChatSession session,
    LearningState finalState,
    SessionTelemetry telemetry,
  ) async {
    try {
      final exportData = buildExportData(session, finalState, telemetry);
      final filename = _generateFilename(session, telemetry);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      downloadTextFile(filename, jsonString, 'application/json');
    } catch (e) {
      throw Exception('세션 내보내기 실패: $e');
    }
  }

  /// 내보낼 JSON 데이터를 구성한다. 테스트에서 직접 호출할 수 있도록 공개한다.
  Map<String, dynamic> buildExportData(
    ChatSession session,
    LearningState finalState,
    SessionTelemetry telemetry,
  ) {
    final exportedAt = DateTime.now();
    final startedAt = telemetry.participant?.startedAt;

    return {
      'exportVersion': '3.0',
      'exportedAt': exportedAt.toIso8601String(),
      'exportCount': telemetry.exportCount,
      'experiment': {
        // URL 쿼리(?condition=...)로 결정된 값. 조건 구분의 유일한 근거.
        'condition': ExperimentConfig.conditionLabel,
        'blindLabel': ExperimentConfig.blindLabel, // 참가자가 고른 그룹 글자
        'conditionSource': ExperimentConfig.conditionSource, // start | url | default
        'station': ExperimentConfig.station,
        'showLearningRoadmap': ExperimentConfig.showLearningRoadmap,
        'buildCommit': ExperimentConfig.buildCommit,
        'buildVersion': ExperimentConfig.buildVersion,
        'models': {
          'extractor': _spec(AiModels.extractor),
          'tutor': _spec(AiModels.tutor),
          'designer': _spec(AiModels.designer),
        },
      },
      'participant': {
        ...?telemetry.participant?.toJson(),
        'endedAt': exportedAt.toIso8601String(),
        'totalDurationMs':
            startedAt == null ? null : exportedAt.difference(startedAt).inMilliseconds,
      },
      'environment': telemetry.environment,
      'session': _sessionInfo(session),
      'summary': _summary(session, finalState, telemetry, exportedAt),
      'finalLearningState': finalState.toJson(),
      'turns': telemetry.turns.map((t) => t.toJson(startedAt)).toList(),
      'messages': session.messages.map((m) => m.toJson()).toList(),
      'llmCalls': telemetry.llmCalls.map((c) => c.toJson()).toList(),
      'flowEvents': telemetry.flowEvents.map((e) => e.toJson()).toList(),
      'stateChanges': session.stateChanges.map((e) => e.toJson()).toList(),
      'uiEvents': telemetry.uiEvents.map((e) => e.toJson()).toList(),
      // v2.1 호환 타임라인
      'timeline': _buildSimplifiedTimeline(session.messages, session.stateChanges),
    };
  }

  Map<String, String> _spec(ModelSpec spec) =>
      {'model': spec.model, 'location': spec.location};

  Map<String, dynamic> _sessionInfo(ChatSession session) {
    final users = session.messages.where((m) => m.role == MessageRole.user);
    final models = session.messages.where((m) => m.role == MessageRole.model);
    final first = users.isEmpty ? null : users.first.timestamp;
    final last = models.isEmpty ? null : models.last.timestamp;
    return {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.toIso8601String(),
      'firstUserMessageAt': first?.toIso8601String(),
      'lastModelMessageAt': last?.toIso8601String(),
      'activeDurationMs':
          (first == null || last == null) ? null : last.difference(first).inMilliseconds,
    };
  }

  Map<String, dynamic> _summary(
    ChatSession session,
    LearningState finalState,
    SessionTelemetry telemetry,
    DateTime exportedAt,
  ) {
    int countRole(MessageRole r) =>
        session.messages.where((m) => m.role == r).length;
    int charsRole(MessageRole r) => session.messages
        .where((m) => m.role == r)
        .fold(0, (sum, m) => sum + m.content.length);

    // LLM 호출 집계 (에이전트별)
    final byAgent = <String, Map<String, num>>{};
    var promptTokens = 0, candidateTokens = 0, totalTokens = 0, thoughtTokens = 0;
    for (final c in telemetry.llmCalls) {
      final entry = byAgent.putIfAbsent(
        c.agent,
        () => {'count': 0, 'errors': 0, 'durationMs': 0, 'totalTokens': 0},
      );
      entry['count'] = entry['count']! + 1;
      if (c.error != null) entry['errors'] = entry['errors']! + 1;
      entry['durationMs'] = entry['durationMs']! + c.durationMs;
      entry['totalTokens'] = entry['totalTokens']! + (c.totalTokenCount ?? 0);
      promptTokens += c.promptTokenCount ?? 0;
      candidateTokens += c.candidatesTokenCount ?? 0;
      totalTokens += c.totalTokenCount ?? 0;
      thoughtTokens += c.thoughtsTokenCount ?? 0;
    }

    // grounding 집계 (source별)
    final groundingBySource = <String, int>{};
    var searchQueryCount = 0;
    var sourceCount = 0;
    for (final e in session.stateChanges) {
      if (e.type != StateChangeType.groundingUsed) continue;
      final source = e.changes['source']?.toString() ?? 'unknown';
      groundingBySource[source] = (groundingBySource[source] ?? 0) + 1;
      searchQueryCount += (e.changes['searchQueries'] as List?)?.length ?? 0;
      sourceCount += (e.changes['sources'] as List?)?.length ?? 0;
    }

    // 턴 지연·읽기·작성 시간 평균 (값이 있는 턴만)
    final startedAt = telemetry.participant?.startedAt;
    final turnRows = telemetry.turns.map((t) => t.toJson(startedAt)).toList();
    num? mean(String key) {
      final vals = turnRows.map((r) => r[key]).whereType<num>().toList();
      if (vals.isEmpty) return null;
      return (vals.reduce((a, b) => a + b) / vals.length).round();
    }
    final routes = <String, int>{};
    for (final t in telemetry.turns) {
      final r = t.route ?? 'unknown';
      routes[r] = (routes[r] ?? 0) + 1;
    }

    // 탭 이탈: hidden→visible 쌍으로 이탈 시간 합산
    var hiddenCount = 0, hiddenMs = 0;
    DateTime? hiddenAt;
    for (final e in telemetry.uiEvents) {
      if (e.type != 'visibility') continue;
      if (e.data['state'] == 'hidden') {
        hiddenCount += 1;
        hiddenAt = e.timestamp;
      } else if (hiddenAt != null) {
        hiddenMs += e.timestamp.difference(hiddenAt).inMilliseconds;
        hiddenAt = null;
      }
    }

    return {
      'turnCount': telemetry.turns.length,
      'routes': routes,
      'messages': {
        'student': countRole(MessageRole.user),
        'tutor': countRole(MessageRole.model),
        'system': countRole(MessageRole.system),
        // 오류로 대체된 말풍선(model 역할이지만 튜터 발화가 아님)
        'errorBubbles': session.messages
            .where((m) => m.meta['kind'] == 'error')
            .length,
      },
      'chars': {
        'student': charsRole(MessageRole.user),
        'tutor': charsRole(MessageRole.model),
      },
      'meanTurn': {
        'readingMs': mean('readingMs'),
        'composeMs': mean('composeMs'),
        'sinceResponseMs': mean('sinceResponseMs'),
        'timeToFirstChunkMs': mean('timeToFirstChunkMs'),
        'latencyMs': mean('latencyMs'),
        'blockedMs': mean('blockedMs'),
        'postProcessingMs': mean('postProcessingMs'),
        'userChars': mean('userChars'),
        'responseChars': mean('responseChars'),
      },
      'llmCalls': {
        'count': telemetry.llmCalls.length,
        'errors': telemetry.llmCalls.where((c) => c.error != null).length,
        // 재시도 끝에 성공한 호출 수 (모델은 바뀌지 않음)
        'retried': telemetry.llmCalls.where((c) => c.attempts > 1).length,
        'byAgent': byAgent,
        'tokens': {
          'prompt': promptTokens,
          'candidates': candidateTokens,
          'thoughts': thoughtTokens,
          'total': totalTokens,
        },
      },
      'errors': telemetry.flowEvents.where((e) => e.name.endsWith('.error')).length,
      'grounding': {
        // 검색 발동 횟수(조절변수 '자료 검색 빈도'의 1차 지표)
        'events': groundingBySource,
        'searchQueryCount': searchQueryCount,
        'sourceCount': sourceCount,
      },
      'course': {
        'stepsTotal': finalState.totalSteps,
        'currentStepIndex': finalState.currentStepIndex,
        'completed': finalState.isCourseCompleted,
        'redesigns': session.stateChanges
            .where((e) => e.type == StateChangeType.redesignRequested)
            .length,
        'stepTimeline': _stepTimeline(session, finalState, telemetry, exportedAt),
      },
      'attention': {
        'tabHiddenCount': hiddenCount,
        'tabHiddenMs': hiddenMs,
        'scrollEvents': telemetry.uiEvents.where((e) => e.type == 'scroll').length,
        'jumpToBottomClicks':
            telemetry.uiEvents.where((e) => e.type == 'jump_to_bottom').length,
      },
    };
  }

  /// 단계별 진입·이탈 시각과 소요 시간·턴 수. stateChanges에서 복원한다.
  List<Map<String, dynamic>> _stepTimeline(
    ChatSession session,
    LearningState finalState,
    SessionTelemetry telemetry,
    DateTime exportedAt,
  ) {
    final steps = finalState.instructionalDesign.syllabus;
    if (steps.isEmpty) return const [];

    final entered = <int, DateTime>{};
    final exited = <int, DateTime>{};
    for (final e in session.stateChanges) {
      switch (e.type) {
        case StateChangeType.syllabusGenerated:
          // 재설계 시 다시 0단계부터. 이전 기록은 덮어쓴다.
          entered.clear();
          exited.clear();
          entered[0] = e.timestamp;
        case StateChangeType.stepAdvanced:
          final from = e.changes['from'] as int?;
          final to = e.changes['to'] as int?;
          if (from != null) exited[from] = e.timestamp;
          if (to != null) entered[to] = e.timestamp;
        case StateChangeType.courseCompleted:
          final at = e.changes['completedAtStep'] as int?;
          if (at != null) exited[at] = e.timestamp;
        default:
          break;
      }
    }

    return [
      for (var i = 0; i < steps.length; i++)
        () {
          final start = entered[i];
          final end = exited[i] ?? (start != null ? exportedAt : null);
          return {
            'index': i,
            'step': steps[i].step,
            'topic': steps[i].topic,
            'enteredAt': start?.toIso8601String(),
            'exitedAt': exited[i]?.toIso8601String(),
            'durationMs': (start == null || end == null)
                ? null
                : end.difference(start).inMilliseconds,
            'turns': telemetry.turns.where((t) => t.stepIndexBefore == i).length,
            'reached': start != null,
            'completed': exited[i] != null,
          };
        }(),
    ];
  }

  /// v2.1 호환 타임라인 (학생, 튜터, 프로필, 커리큘럼, 검색 발동).
  List<Map<String, dynamic>> _buildSimplifiedTimeline(
    List<Message> messages,
    List<StateChangeEvent> stateChanges,
  ) {
    final timeline = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message.role == MessageRole.user) {
        timeline.add({
          'type': 'student',
          'timestamp': message.timestamp.toIso8601String(),
          'content': message.content,
        });
      } else if (message.role == MessageRole.model) {
        timeline.add({
          'type': 'tutor',
          'timestamp': message.timestamp.toIso8601String(),
          'content': message.content,
        });
      }
    }

    for (final event in stateChanges) {
      if (event.type == StateChangeType.profileUpdated) {
        timeline.add({
          'type': 'profile',
          'timestamp': event.timestamp.toIso8601String(),
          'profile': event.changes,
        });
      } else if (event.type == StateChangeType.syllabusGenerated) {
        final steps = event.changes['steps'] as List?;
        if (steps != null && steps.isNotEmpty) {
          timeline.add({
            'type': 'syllabus',
            'timestamp': event.timestamp.toIso8601String(),
            'syllabus': steps,
          });
        }
      } else if (event.type == StateChangeType.groundingUsed) {
        timeline.add({
          'type': 'grounding',
          'timestamp': event.timestamp.toIso8601String(),
          'source': event.changes['source'],
          'searchQueries': event.changes['searchQueries'] ?? const [],
          'sources': event.changes['sources'] ?? const [],
        });
      }
    }

    timeline.sort((a, b) {
      final timestampA = DateTime.parse(a['timestamp'] as String);
      final timestampB = DateTime.parse(b['timestamp'] as String);
      return timestampA.compareTo(timestampB);
    });

    return timeline;
  }

  /// 파일명: YYYYMMDD_HHMM_<조건>[_<PC>]_<참가자>.json
  ///
  /// 예: 20260925_1430_control_A_홍길동.json
  /// 열어보지 않고도 조건·PC·참가자를 알 수 있게 한다.
  String _generateFilename(ChatSession session, SessionTelemetry telemetry) {
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final who = telemetry.participant?.name ?? session.title;
    final station = ExperimentConfig.station;

    var sanitized = who
        .replaceAll(RegExp(r'[^\w가-힣\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (sanitized.length > 20) sanitized = sanitized.substring(0, 20);
    if (sanitized.isEmpty) sanitized = 'session';

    final parts = [
      dateStr,
      ExperimentConfig.conditionLabel,
      ?station,
      sanitized,
    ];
    return '${parts.join('_')}.json';
  }
}
