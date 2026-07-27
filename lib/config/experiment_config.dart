/// 실험 조건 (피험자 간 2조건 설계).
enum ExperimentCondition {
  /// 처치군: 구조화 오케스트레이션
  /// (Intent 분류 · Analyst · Feedback · Syllabus Designer · 단계 추적 · 로드맵).
  treatment,

  /// 대조군: free form 단일 호출 (구조화 오케스트레이션 없음).
  control,
}

/// 실험 조건 토글.
///
/// 이 파일의 플래그는 "학습자에게 무엇을 노출하는가"만 제어하며,
/// 내부 단계 추적(currentStepIndex)·진행 관리(StepProgressService)·
/// Tutor 프롬프트의 현재 단계 주입에는 영향을 주지 않는다.
class ExperimentConfig {
  ExperimentConfig._();

  /// 학습 로드맵 UI를 피험자에게 노출할지 여부.
  ///
  /// 대상: 상단 진행 헤더 + 목차 모달 + 상태 배너("로드맵 생성 중/준비 완료").
  ///
  /// - true  : 피험자가 전체 경로와 현재 위치(✓/▶/○)를 시각적으로 본다.
  ///           → 지각된 방향상실 감소의 "직접" 메커니즘.
  /// - false : 로드맵 UI를 전부 숨긴다. 내부 단계 추적/진행 관리는 그대로 작동하므로
  ///           Tutor는 여전히 현재 단계에 집중하지만, 학습자는 위치를 시각적으로 보지 못한다.
  ///
  /// 현재 false — 양 조건의 화면을 글자 단위로 동일하게 유지하기 위한 결정이다.
  /// 처치군에만 로드맵 UI가 뜨면 조작이 오케스트레이션 구조 하나로 한정되지 않는다.
  /// 설계 대기 중 피드백은 양 조건 공용인 타이핑 인디케이터가 담당한다.
  ///
  /// 실험에서 로드맵 가시성 자체를 조작/복원하려면 이 값만 바꾸면 된다.
  static const bool showLearningRoadmap = false;

  /// URL 쿼리 파라미터로 처치/대조 조건을 결정한다.
  ///
  /// 예) `https://HOST/?condition=control`   → 대조군(free form)
  ///     `https://HOST/?condition=treatment` → 처치군(구조화)
  ///
  /// 미지정/오타 시 기본은 [ExperimentCondition.treatment].
  /// 참가자별로 다른 링크를 배포해 조건을 통제하고 세션 로그에도 기록한다.
  static ExperimentCondition get condition {
    final c = Uri.base.queryParameters['condition']?.toLowerCase().trim();
    if (c == 'control' || c == 'freeform' || c == 'free') {
      return ExperimentCondition.control;
    }
    return ExperimentCondition.treatment;
  }

  static bool get isControl => condition == ExperimentCondition.control;
  static bool get isTreatment => !isControl;

  /// 로그/내보내기에 기록할 조건 라벨.
  static String get conditionLabel => condition.name;
}
