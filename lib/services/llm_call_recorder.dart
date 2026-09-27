import 'dart:math';
import 'package:firebase_ai/firebase_ai.dart';
import '../config/ai_models.dart';
import '../models/telemetry.dart';

/// 일시 오류 재시도 정책.
///
/// Vertex AI는 공유 용량이 순간적으로 차면 429 "Resource exhausted"를 돌려준다
/// (파일럿에서 실제로 발생). 참가자에게 오류가 보이면 조건과 무관한 교란이 되므로
/// 짧은 백오프로 몇 번 더 시도한다. 시도 횟수와 사유는 [LlmCallRecord]에 남는다.
class LlmRetryPolicy {
  LlmRetryPolicy._();

  static const int maxAttempts = 4;

  /// 429·503·504·UNAVAILABLE·overloaded 계열만 재시도한다. 400/403/안전 차단은 즉시 실패.
  static bool isRetryable(Object error) {
    final m = error.toString().toLowerCase();
    return m.contains('resource exhausted') ||
        m.contains('429') ||
        m.contains('503') ||
        m.contains('504') ||
        m.contains('unavailable') ||
        m.contains('overloaded') ||
        m.contains('deadline exceeded') ||
        m.contains('try again');
  }

  /// attempt는 1부터. 1→1s, 2→2s, 3→4s (+0~300ms 지터).
  static Duration delayFor(int attempt, {Random? random}) {
    final base = 1000 * (1 << (attempt - 1));
    final jitter = (random ?? Random()).nextInt(300);
    return Duration(milliseconds: base + jitter);
  }
}

/// 비스트리밍 호출을 시간·토큰·원문까지 기록하며 실행한다.
///
/// 실패해도 [LlmCallRecord]를 남긴 뒤 예외를 다시 던진다.
/// 호출부는 [onCall]로 기록을 받아 텔레메트리에 쌓는다.
Future<({GenerateContentResponse response, LlmCallRecord call})> recordedGenerate({
  required GenerativeModel model,
  required ModelSpec spec,
  required String agent,
  required String prompt,
  String? systemInstruction,
  /// 재시도 끝까지 일시 오류면 이 모델로 한 번 더 시도한다 (없으면 그대로 실패).
  ({GenerativeModel model, ModelSpec spec})? fallback,
}) async {
  final startedAt = DateTime.now();
  final retryErrors = <String>[];
  var activeModel = model;
  var activeSpec = spec;
  String? fallbackFrom;
  for (var attempt = 1; ; attempt++) {
    try {
      final response =
          await activeModel.generateContent([Content.text(prompt)]);
      final call = buildCallRecord(
        agent: agent,
        spec: activeSpec,
        prompt: prompt,
        systemInstruction: systemInstruction,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        usage: response.usageMetadata,
        candidate:
            response.candidates.isNotEmpty ? response.candidates.first : null,
        responseText: response.text,
        attempts: attempt,
        retryErrors: retryErrors,
        fallbackFromModel: fallbackFrom,
      );
      return (response: response, call: call);
    } catch (e) {
      final retryable = LlmRetryPolicy.isRetryable(e);
      if (retryable && attempt < LlmRetryPolicy.maxAttempts) {
        retryErrors.add(e.toString());
        await Future.delayed(LlmRetryPolicy.delayFor(attempt));
        continue;
      }
      // 재시도 소진: 대체 모델이 있고 아직 안 썼으면 마지막으로 한 번 더.
      if (retryable && fallback != null && fallbackFrom == null) {
        retryErrors.add(e.toString());
        fallbackFrom = activeSpec.model;
        activeModel = fallback.model;
        activeSpec = fallback.spec;
        continue;
      }
      throw LlmCallException(
        e,
        buildCallRecord(
          agent: agent,
          spec: activeSpec,
          prompt: prompt,
          systemInstruction: systemInstruction,
          startedAt: startedAt,
          completedAt: DateTime.now(),
          error: e.toString(),
          attempts: attempt,
          retryErrors: retryErrors,
          fallbackFromModel: fallbackFrom,
        ),
      );
    }
  }
}

/// 호출 실패 시 기록을 함께 실어 나르는 예외.
class LlmCallException implements Exception {
  final Object cause;
  final LlmCallRecord call;
  LlmCallException(this.cause, this.call);

  @override
  String toString() => 'LlmCallException(${call.agent}): $cause';
}

LlmCallRecord buildCallRecord({
  required String agent,
  required ModelSpec spec,
  required String prompt,
  String? systemInstruction,
  required DateTime startedAt,
  DateTime? firstChunkAt,
  required DateTime completedAt,
  int chunkCount = 0,
  bool streaming = false,
  int historyLength = 0,
  int historyChars = 0,
  UsageMetadata? usage,
  Candidate? candidate,
  String? responseText,
  String? error,
  List<String> searchQueries = const [],
  List<String> sources = const [],
  int attempts = 1,
  List<String> retryErrors = const [],
  String? fallbackFromModel,
}) {
  return LlmCallRecord(
    agent: agent,
    model: spec.model,
    location: spec.location,
    streaming: streaming,
    startedAt: startedAt,
    firstChunkAt: firstChunkAt,
    completedAt: completedAt,
    chunkCount: chunkCount,
    promptTokenCount: usage?.promptTokenCount,
    candidatesTokenCount: usage?.candidatesTokenCount,
    totalTokenCount: usage?.totalTokenCount,
    thoughtsTokenCount: usage?.thoughtsTokenCount,
    toolUsePromptTokenCount: usage?.toolUsePromptTokenCount,
    finishReason: candidate?.finishReason?.name,
    finishMessage: candidate?.finishMessage,
    error: error,
    systemInstruction: systemInstruction,
    prompt: prompt,
    historyLength: historyLength,
    historyChars: historyChars,
    responseText: responseText,
    searchQueries: searchQueries,
    sources: sources,
    attempts: attempts,
    retryErrors: List.unmodifiable(retryErrors),
    fallbackFromModel: fallbackFromModel,
  );
}

/// 후보의 grounding 메타데이터에서 검색어·출처 문자열을 뽑는다.
/// (GroundingMetadata 타입은 패키지 밖으로 export되지 않아 Candidate를 받는다.)
///
/// firebase_ai(3.6~3.15 확인)는 `webSearchQueries`를 `List<String>` 패턴으로
/// 매칭하는데 JSON은 `List<dynamic>`이라 항상 빈 리스트가 된다. 파일럿에서
/// 출처 10건에 검색어 0건으로 드러났다. 대신 `searchEntryPoint.renderedContent`
/// (구글 검색 제안 HTML)의 칩 텍스트에서 검색어를 복원한다.
({List<String> queries, List<String> sources}) extractGrounding(
    Candidate? candidate) {
  final metadata = candidate?.groundingMetadata;
  if (metadata == null) return (queries: const [], sources: const []);
  final sources = <String>[
    for (final grounding in metadata.groundingChunks)
      if (grounding.web != null)
        '${grounding.web!.title ?? '(제목 없음)'} (${grounding.web!.uri ?? '-'})',
  ];
  var queries = metadata.webSearchQueries;
  if (queries.isEmpty) {
    queries = extractQueriesFromEntryPoint(
        metadata.searchEntryPoint?.renderedContent);
  }
  return (queries: queries, sources: sources);
}

/// 검색 제안 HTML(`<a class="chip" href="…">검색어</a>`)에서 검색어를 뽑는다.
List<String> extractQueriesFromEntryPoint(String? renderedContent) {
  if (renderedContent == null || renderedContent.isEmpty) return const [];
  final re = RegExp(r'<a[^>]*class="chip"[^>]*>(.*?)</a>', dotAll: true);
  final out = <String>[];
  for (final m in re.allMatches(renderedContent)) {
    final text = m.group(1)!
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    if (text.isNotEmpty && !out.contains(text)) out.add(text);
  }
  return out;
}
