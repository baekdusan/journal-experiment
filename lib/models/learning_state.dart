import 'learner_profile.dart';
import 'instructional_design.dart';
import 'resource_cache.dart';

class LearningState {
  final LearnerProfile learnerProfile;
  final InstructionalDesign instructionalDesign;
  final ResourceCache resourceCache;
  final bool isDesigning;
  final bool showDesignReady;
  final bool isCourseCompleted;

  /// 현재 진행 중인 학습 단계(0-based). 단계 추적/진행 관리의 핵심 상태.
  final int currentStepIndex;
  final DateTime updatedAt;

  LearningState({
    required this.learnerProfile,
    required this.instructionalDesign,
    ResourceCache? resourceCache,
    this.isDesigning = false,
    this.showDesignReady = false,
    this.isCourseCompleted = false,
    this.currentStepIndex = 0,
    DateTime? updatedAt,
  })  : resourceCache = resourceCache ?? ResourceCache.empty(),
        updatedAt = updatedAt ?? DateTime.now();

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
    ResourceCache? resourceCache,
    bool? isDesigning,
    bool? showDesignReady,
    bool? isCourseCompleted,
    int? currentStepIndex,
    DateTime? updatedAt,
  }) {
    return LearningState(
      learnerProfile: learnerProfile ?? this.learnerProfile,
      instructionalDesign: instructionalDesign ?? this.instructionalDesign,
      resourceCache: resourceCache ?? this.resourceCache,
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
      'resourceCache': resourceCache.toJson(),
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
      resourceCache: json['resourceCache'] != null
          ? ResourceCache.fromJson(json['resourceCache'] as Map<String, dynamic>)
          : ResourceCache.empty(),
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
