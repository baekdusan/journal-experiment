import 'package:uuid/uuid.dart';

/// 학습 상태 변화를 나타내는 타임라인 이벤트
/// 메시지 사이에 발생한 상태 변화를 기록하여 학습 플랜 생성 과정을 추적
class StateChangeEvent {
  /// 이벤트 고유 ID
  final String id;

  /// 이벤트 발생 시각
  final DateTime timestamp;

  /// 상태 변화 유형
  final StateChangeType type;

  /// 변경된 내용 (필드명과 값의 맵)
  final Map<String, dynamic> changes;

  StateChangeEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.changes,
  });

  /// 새 상태 변화 이벤트 생성
  factory StateChangeEvent.create({
    required StateChangeType type,
    required Map<String, dynamic> changes,
  }) {
    return StateChangeEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      type: type,
      changes: changes,
    );
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'changes': changes,
    };
  }

  /// JSON에서 역직렬화
  factory StateChangeEvent.fromJson(Map<String, dynamic> json) {
    return StateChangeEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: StateChangeType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      changes: Map<String, dynamic>.from(json['changes'] as Map),
    );
  }

  /// 복사본 생성
  StateChangeEvent copyWith({
    String? id,
    DateTime? timestamp,
    StateChangeType? type,
    Map<String, dynamic>? changes,
  }) {
    return StateChangeEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      changes: changes ?? this.changes,
    );
  }
}

/// 학습 상태 변화 유형
enum StateChangeType {
  /// 프로필 업데이트 (subject, goal, level, tone 변경)
  profileUpdated,

  /// 커리큘럼 생성 시작
  syllabusGenerationStarted,

  /// 커리큘럼 생성 완료
  syllabusGenerated,

  /// 수업 완료
  courseCompleted,

  /// 재설계 요청
  redesignRequested,

  /// 단계 전진 (현재 학습 단계가 다음 단계로 이동)
  stepAdvanced,
}
