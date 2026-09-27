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

  /// 진행자 설정 화면([SetupScreen])에서 고른 조건. URL보다 우선한다.
  static ExperimentCondition? _override;
  static String? _stationOverride;

  /// URL 쿼리(`?condition=`)가 가리키는 조건. 없거나 오타면 null.
  ///
  /// 예) `https://HOST/?condition=control`   → 대조군(free form)
  ///     `https://HOST/?condition=treatment` → 처치군(구조화)
  static ExperimentCondition? get conditionFromUrl {
    final c = Uri.base.queryParameters['condition']?.toLowerCase().trim();
    if (c == 'control' || c == 'freeform' || c == 'free') {
      return ExperimentCondition.control;
    }
    if (c == 'treatment' || c == 'addie') return ExperimentCondition.treatment;
    return null;
  }

  /// 현재 조건. 진행자 설정 > URL > 기본값(처치군) 순.
  ///
  /// 실제 운영에서는 [SetupScreen]이 명시적 선택을 강제하므로 기본값에
  /// 조용히 떨어지는 일은 없다. 기본값은 테스트·개발용 안전망이다.
  static ExperimentCondition get condition =>
      _override ?? conditionFromUrl ?? ExperimentCondition.treatment;

  /// 조건이 어디서 왔는지 (setup | url | default). 내보내기에 기록한다.
  static String get conditionSource => _override != null
      ? 'setup'
      : (conditionFromUrl != null ? 'url' : 'default');

  static void setCondition(ExperimentCondition c) => _override = c;
  static void setStation(String? s) =>
      _stationOverride = (s == null || s.trim().isEmpty) ? null : s.trim();

  static bool get isControl => condition == ExperimentCondition.control;
  static bool get isTreatment => !isControl;

  /// 로그/내보내기에 기록할 조건 라벨.
  static String get conditionLabel => condition.name;

  /// 현장 PC 식별자 (`?pc=A` 또는 `?station=A`). 두 대를 동시에 돌릴 때
  /// 파일이 어느 컴퓨터에서 나왔는지 구분한다. 없으면 null.
  static String? get station => _stationOverride ?? stationFromUrl;

  static String? get stationFromUrl {
    final q = Uri.base.queryParameters;
    final v = (q['pc'] ?? q['station'])?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 시작 화면의 이름 칸을 미리 채울 값 (`?pid=P07`). 없으면 빈 칸.
  static String? get participantIdFromUrl {
    final v = Uri.base.queryParameters['pid']?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 빌드 시 주입되는 git 커밋 해시.
  /// `flutter build web --dart-define=BUILD_COMMIT=$(git rev-parse --short HEAD)`
  static const String buildCommit =
      String.fromEnvironment('BUILD_COMMIT', defaultValue: 'unknown');

  /// pubspec 버전과 같은 값을 빌드 시 넣는다. 미지정이면 unknown.
  static const String buildVersion =
      String.fromEnvironment('BUILD_VERSION', defaultValue: 'unknown');

  /// App Check용 reCAPTCHA Enterprise 사이트 키. 배포 빌드에만 넣는다 (main.dart 참고).
  static const String recaptchaSiteKey =
      String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
}
