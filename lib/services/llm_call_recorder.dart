import 'package:firebase_ai/firebase_ai.dart';
import '../config/ai_models.dart';
import '../models/telemetry.dart';

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
}) async {
  final startedAt = DateTime.now();
  try {
    final response = await model.generateContent([Content.text(prompt)]);
    final call = buildCallRecord(
      agent: agent,
      spec: spec,
      prompt: prompt,
      systemInstruction: systemInstruction,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      usage: response.usageMetadata,
      candidate: response.candidates.isNotEmpty ? response.candidates.first : null,
      responseText: response.text,
    );
    return (response: response, call: call);
  } catch (e) {
    throw LlmCallException(
      e,
      buildCallRecord(
        agent: agent,
        spec: spec,
        prompt: prompt,
        systemInstruction: systemInstruction,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: e.toString(),
      ),
    );
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
  );
}

/// 후보의 grounding 메타데이터에서 검색어·출처 문자열을 뽑는다.
/// (GroundingMetadata 타입은 패키지 밖으로 export되지 않아 Candidate를 받는다.)
({List<String> queries, List<String> sources}) extractGrounding(
    Candidate? candidate) {
  final metadata = candidate?.groundingMetadata;
  if (metadata == null) return (queries: const [], sources: const []);
  final sources = <String>[
    for (final grounding in metadata.groundingChunks)
      if (grounding.web != null)
        '${grounding.web!.title ?? '(제목 없음)'} (${grounding.web!.uri ?? '-'})',
  ];
  return (queries: metadata.webSearchQueries, sources: sources);
}
