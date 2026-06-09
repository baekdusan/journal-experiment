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

  /// 튜터 스트리밍 응답용.
  /// 실험: 대조군(free form)과 backbone을 동일하게 맞추기 위해 designer와 같은
  /// gemini-3.5-flash/global을 사용한다. (콘텐츠 생성능력을 교란변인으로 통제)
  static const ModelSpec tutor = ModelSpec('gemini-3.5-flash', 'global');

  /// 교수설계(Syllabus) 생성용. 강한 추론 모델을 global에서 사용.
  /// global이 불안정하면 ModelSpec('gemini-2.5-flash', 'us-central1')로 폴백.
  static const ModelSpec designer = ModelSpec('gemini-3.5-flash', 'global');
}
