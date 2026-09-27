/// AI 모델 중앙 설정.
///
/// 모든 서비스의 Gemini 모델명과 Vertex AI location을 여기서 관리한다.
/// 모델을 갈아끼울 때는 이 파일만 수정하면 된다.
///
/// 모델마다 사용 가능한 location이 다르므로 (model, location)을 묶어 관리한다.
/// - addie-tutor 프로젝트는 대부분의 모델을 'us-central1'에서만 호출할 수 있다.
///   ('global' 엔드포인트는 라우팅이 불안정해 404가 잦다.)
/// - 단, gemini-3.5-flash는 'global' 전용이라 us-central1에서는 404가 난다.
/// - gemini-2.0-flash / gemini-3-flash-preview는 us-central1에서 호출 불가(404).
class ModelSpec {
  final String model;
  final String location;
  const ModelSpec(this.model, this.location);
}

class AiModels {
  AiModels._();

  /// 분류·추출용 (Intent / Analyst / Feedback / StepProgress / Wikidata).
  /// 빠르고 저렴한 모델, temperature 0.0으로 사용.
  static const ModelSpec extractor =
      ModelSpec('gemini-2.5-flash', 'us-central1');

  /// 학습자 대면 스트리밍 응답용 (처치군 Tutor + 대조군 순수 모델 공용).
  /// 양 조건 모두 gemini-3.5-flash(global)로 통일하고 Tool.googleSearch()
  /// grounding을 공통 활성화한다 (2026-07-07 확정 — designer와 동일 backbone).
  /// ※ 확정설계 문서(260624)에는 2.5-flash로 적혀 있으나 3.5 통일로 갱신 필요.
  static const ModelSpec tutor = ModelSpec('gemini-3.5-flash', 'global');

  /// 교수설계(Syllabus) 생성용. 강한 추론 모델을 global에서 사용.
  static const ModelSpec designer = ModelSpec('gemini-3.5-flash', 'global');

  /// 3.5-flash(global)가 429 "Resource exhausted"를 재시도 끝까지 돌려줄 때
  /// **그 호출 한 번만** 대신 쓰는 모델. tutor·designer 공용, 양 조건 동일.
  ///
  /// global 엔드포인트는 동적 공유 할당량이라 프로젝트 한도를 올려서 막을 수
  /// 없다(2026-09-27 파일럿). 참가자에게 오류를 보이는 것보다 낫지만 통제 변인이
  /// 그 턴에 바뀌므로, 내보내기 `llmCalls[].fallbackFromModel`로 사후 식별한다.
  static const ModelSpec fallback = ModelSpec('gemini-2.5-flash', 'us-central1');
}
