import 'learner_profile.dart';
import 'instructional_design.dart';

/// 통합 학습 상태.
///
/// 자료(레퍼런스) 캐시는 두지 않는다 — 확정 실험설계(260624)에 따라
/// 자료 취득은 로컬 캐시 없이 `Tool.googleSearch()` grounding으로만 이루어지며,
/// Designer/Tutor가 호출 시점에 직접 검색한다.
class LearningState {
  final LearnerProfile learnerProfile;
  final InstructionalDesign instructionalDesign;
  final bool isDesigning;
  final bool showDesignReady;
  final bool isCourseCompleted;

  /// 현재 진행 중인 학습 단계(0-based). 단계 추적/진행 관리의 핵심 상태.
  final int currentStepIndex;
  final DateTime updatedAt;

  LearningState({
    required this.learnerProfile,
    required this.instructionalDesign,
    this.isDesigning = false,
    this.showDesignReady = false,
    this.isCourseCompleted = false,
    this.currentStepIndex = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 현재 단계 객체. 인덱스가 범위를 벗어나면 null.
  Step? get currentStep => (currentStepIndex >= 0 &&
          currentStepIndex < instructionalDesign.syllabus.length)
      ? instructionalDesign.syllabus[currentStepIndex]
      : null;

  /// 전체 단계 수.
  int get totalSteps => instructionalDesign.totalSteps;

  /// 마지막 단계에 도달했는지 여부.
  bool get isLastStep =>
      totalSteps > 0 && currentStepIndex >= totalSteps - 1;

  /// 진행 표시용 라벨 (예: "3/5").
  String get progressLabel =>
      totalSteps == 0 ? '-' : '${currentStepIndex + 1}/$totalSteps';

  LearningState copyWith({
    LearnerProfile? learnerProfile,
    InstructionalDesign? instructionalDesign,
    bool? isDesigning,
    bool? showDesignReady,
    bool? isCourseCompleted,
    int? currentStepIndex,
    DateTime? updatedAt,
  }) {
    return LearningState(
      learnerProfile: learnerProfile ?? this.learnerProfile,
      instructionalDesign: instructionalDesign ?? this.instructionalDesign,
      isDesigning: isDesigning ?? this.isDesigning,
      showDesignReady: showDesignReady ?? this.showDesignReady,
      isCourseCompleted: isCourseCompleted ?? this.isCourseCompleted,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'learnerProfile': learnerProfile.toJson(),
      'instructionalDesign': instructionalDesign.toJson(),
      'isDesigning': isDesigning,
      'showDesignReady': showDesignReady,
      'isCourseCompleted': isCourseCompleted,
      'currentStepIndex': currentStepIndex,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LearningState.fromJson(Map<String, dynamic> json) {
    return LearningState(
      learnerProfile:
          LearnerProfile.fromJson(json['learnerProfile'] as Map<String, dynamic>),
      instructionalDesign: InstructionalDesign.fromJson(
        json['instructionalDesign'] as Map<String, dynamic>,
      ),
      // 구버전 prefs에 남아 있는 'resourceCache' 키는 무시한다.
      isDesigning: json['isDesigning'] as bool? ?? false,
      showDesignReady: json['showDesignReady'] as bool? ?? false,
      isCourseCompleted: json['isCourseCompleted'] as bool? ?? false,
      currentStepIndex: json['currentStepIndex'] as int? ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  factory LearningState.initial() {
    return LearningState(
      learnerProfile: LearnerProfile(),
      instructionalDesign: InstructionalDesign.empty(),
    );
  }
}
