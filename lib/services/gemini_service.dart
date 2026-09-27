import 'package:firebase_ai/firebase_ai.dart';
import '../models/message.dart';
import '../config/ai_models.dart';
import '../models/telemetry.dart';
import 'llm_call_recorder.dart';

/// Firebase AI(Vertex AI in Firebase)를 통해 학습자 대면 Gemini 모델과 통신하는 서비스.
///
/// 확정 실험설계(260624)에 따라 처치군 Tutor와 대조군 순수 모델이 **공용**으로 쓴다:
/// - 모델: [AiModels.tutor] (양 조건 동일 — 통제 변인)
/// - 검색: `Tool.googleSearch()` grounding 상시 활성화 (양 조건 공통 역량 — 통제 변인)
/// - 시스템 프롬프트: [systemInstruction]이 주어지면 적용 (처치군),
///   null이면 시스템 프롬프트 없는 순수 모델로 동작 (대조군).
///
/// systemInstruction은 요청마다 함께 전송되는 값이므로(서버 고정 아님),
/// 처치군은 매 턴 상태(로드맵 진행·프로필)를 반영해 새로 빌드해 넘기면 된다.
///
/// Riverpod의 [geminiServiceProvider]를 통해 싱글톤으로 관리된다.
class GeminiService {
  /// 사용자 발화와 이전 대화 기록을 받아 스트리밍 응답 [Stream]을 반환한다.
  ///
  /// [history]의 [Message]들을 SDK의 [Content]로 변환해 멀티턴 맥락을 유지하고,
  /// [userText]를 새 user 메시지로 전송한다. 각 청크를 문자열로 yield한다.
  ///
  /// [onGrounding]: 이 턴에서 Google Search grounding이 발동했으면 스트림 종료 후
  /// (검색어 목록, 근거 소스 "제목 (URI)" 목록)으로 1회 호출된다. 미발동 시 호출 안 됨.
  Stream<String> streamResponse(
    List<Message> history,
    String userText, {
    String? systemInstruction,
    void Function(List<String> searchQueries, List<String> sources)?
        onGrounding,
    String agent = 'tutor',
    void Function(LlmCallRecord call)? onCallComplete,
  }) async* {
    final startedAt = DateTime.now();
    DateTime? firstChunkAt;
    var chunkCount = 0;
    UsageMetadata? usage;
    Candidate? lastCandidate;
    final buffer = StringBuffer();
    final historyChars =
        history.fold<int>(0, (sum, m) => sum + m.content.length);

    // systemInstruction이 턴마다 달라질 수 있으므로 모델을 호출 시점에 생성한다.
    // (GenerativeModel은 클라이언트 측 설정 객체라 생성 비용이 사실상 없다.)
    final model =
        FirebaseAI.vertexAI(location: AiModels.tutor.location).generativeModel(
      model: AiModels.tutor.model,
      tools: [Tool.googleSearch()],
      systemInstruction:
          systemInstruction != null ? Content.system(systemInstruction) : null,
    );

    final historyContent = history
        .map((m) => Content(m.role == MessageRole.user ? 'user' : 'model', [
              TextPart(m.content),
            ]))
        .toList();

    // grounding 메타데이터는 보통 마지막 청크에 실려 오므로 스트림을 돌며 수집한다.
    final searchQueries = <String>{};
    final sources = <String>{};
    final retryErrors = <String>[];

    LlmCallRecord record({String? error, required int attempt}) =>
        buildCallRecord(
          agent: agent,
          spec: AiModels.tutor,
          prompt: userText,
          systemInstruction: systemInstruction,
          startedAt: startedAt,
          firstChunkAt: firstChunkAt,
          completedAt: DateTime.now(),
          chunkCount: chunkCount,
          streaming: true,
          historyLength: history.length,
          historyChars: historyChars,
          usage: usage,
          candidate: lastCandidate,
          responseText: buffer.toString(),
          error: error,
          searchQueries: searchQueries.toList(),
          sources: sources.toList(),
          attempts: attempt,
          retryErrors: retryErrors,
        );

    // 429(Resource exhausted) 등 일시 오류는 첫 청크가 오기 전이면 재시도한다.
    // 청크를 이미 내보낸 뒤에는 화면에 일부가 보였으므로 재시도하지 않는다.
    var attempt = 1;
    while (true) {
      final chat = model.startChat(history: historyContent);
      final response = chat.sendMessageStream(Content.text(userText));
      try {
        await for (final chunk in response) {
          chunkCount += 1;
          firstChunkAt ??= DateTime.now();
          // usageMetadata·finishReason은 마지막 청크에 실려 오므로 계속 덮어쓴다.
          if (chunk.usageMetadata != null) usage = chunk.usageMetadata;
          if (chunk.candidates.isNotEmpty) {
            lastCandidate = chunk.candidates.first;
          }

          final metadata = chunk.candidates.isNotEmpty
              ? chunk.candidates.first.groundingMetadata
              : null;
          if (metadata != null) {
            searchQueries.addAll(metadata.webSearchQueries);
            for (final grounding in metadata.groundingChunks) {
              final web = grounding.web;
              if (web != null) {
                sources.add('${web.title ?? '(제목 없음)'} (${web.uri ?? '-'})');
              }
            }
          }
          if (chunk.text != null) {
            buffer.write(chunk.text!);
            yield chunk.text!;
          }
        }
        break;
      } catch (e) {
        if (chunkCount == 0 &&
            attempt < LlmRetryPolicy.maxAttempts &&
            LlmRetryPolicy.isRetryable(e)) {
          retryErrors.add(e.toString());
          await Future.delayed(LlmRetryPolicy.delayFor(attempt));
          attempt += 1;
          continue;
        }
        onCallComplete?.call(record(error: e.toString(), attempt: attempt));
        rethrow;
      }
    }

    if (onGrounding != null &&
        (searchQueries.isNotEmpty || sources.isNotEmpty)) {
      onGrounding(searchQueries.toList(), sources.toList());
    }

    onCallComplete?.call(record(attempt: attempt));
  }
}
