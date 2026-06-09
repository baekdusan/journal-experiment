/// 실험 조건 토글.
///
/// 이 파일의 플래그는 "학습자에게 무엇을 노출하는가"만 제어하며,
/// 내부 단계 추적(currentStepIndex)·진행 관리(StepProgressService)·
/// Tutor 프롬프트의 현재 단계 주입에는 영향을 주지 않는다.
class ExperimentConfig {
  ExperimentConfig._();

  /// 학습 로드맵 UI(상단 진행 헤더 + 목차 모달)를 피험자에게 노출할지 여부.
  ///
  /// - true  : 피험자가 전체 경로와 현재 위치(✓/▶/○)를 시각적으로 본다.
  ///           → 지각된 방향상실 감소의 "직접" 메커니즘.
  /// - false : 로드맵 UI를 숨긴다. 내부 단계 추적/진행 관리는 그대로 작동하므로
  ///           Tutor는 여전히 현재 단계에 집중하지만, 학습자는 위치를 시각적으로 보지 못한다.
  ///
  /// 실험에서 로드맵 가시성 자체를 조작/제거하려면 이 값만 바꾸면 된다.
  static const bool showLearningRoadmap = true;
}
