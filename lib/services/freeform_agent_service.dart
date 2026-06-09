import '../models/resource_cache.dart';

/// 대조군(free form) 전용 단일 호출 튜터 서비스.
///
/// 처치군의 구조화 오케스트레이션(Intent 분류 · Analyst · Feedback ·
/// Syllabus Designer · 단계 추적 · 로드맵)을 **모두 제거**한 조건이다.
/// 상태 머신 없이 단일 프롬프트로 자유 대화 튜터링만 수행한다.
///
/// 통제: 학습 자료(CBBF)와 backbone 모델(gemini-3.5-flash/global),
/// 스트리밍 방식은 처치군 Tutor와 동일하게 맞춘다. 유일한 차이는
/// "구조화 오케스트레이션의 유무"(= 독립변인)뿐이다.
class FreeformAgentService {
  /// free form 튜터 프롬프트 생성.
  /// 실제 스트리밍 호출은 [GeminiService.streamResponse]가 담당한다.
  String buildFreeformPrompt(
    ResourceCache cache,
    String userText,
    List<String> history,
  ) {
    final historyBlock = history.isEmpty ? '없음' : history.join('\n');
    final resourceBlock =
        cache.isResourceReady ? '\n${cache.toPromptBlock()}\n' : '';

    return '''너는 학습자를 돕는 친절하고 전문적인 튜터다.
학습자와 자유롭게 대화하며, 학습자가 배우고자 하는 것을 잘 이해하도록 도와라.

[튜터링 원칙]
1) 정답을 먼저 말하지 마라. (비계 설정/Scaffolding)
2) 사용자가 어렵다고 하면 더 쉬운 설명과 더 작은 예시로 내려가라.
3) 이해 확인 질문은 필요할 때만 0~1개로 제한하라.
4) 설명은 지나치게 짧지 않게 3~6문장 정도로 충분히 풀어라.
5) 사용자가 "그냥 알려줘"라고 하면 질문 없이 설명만 하라.
6) 말투는 기본적으로 친근하게(kind) 하되, 사용자가 다른 말투를 요청하면 맞춰라.
7) 교수설계 이론을 적용하여 효과적으로 학습을 안내하라.
8) 학습 자료의 내용에 근거하여 설명하고, 자료에 없는 사실을 지어내지 마라.
$resourceBlock
[최근 대화 요약]
$historyBlock

[입력]
$userText

[출력 규칙]
- 반드시 한국어 자연어로만 답하라.
- JSON을 출력하지 마라.
''';
  }
}
