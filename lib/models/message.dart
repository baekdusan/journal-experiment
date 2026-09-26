import 'package:uuid/uuid.dart';

/// 채팅 메시지의 발신자 유형을 정의하는 열거형.
///
/// - [user]: 사용자가 입력한 메시지
/// - [model]: AI(Gemini)가 생성한 응답 메시지
/// - [system]: 시스템 안내 또는 오류 메시지
enum MessageRole {
  user,
  model,
  system;

  String toJson() => name;
  static MessageRole fromJson(String json) => MessageRole.values.byName(json);
}

/// 채팅 메시지를 표현하는 불변(immutable) 데이터 모델.
///
/// UI 렌더링([MessageBubble])과 Gemini API 통신([GeminiService])에 모두 사용되며,
/// 고유 ID, 발신자 역할, 내용, 타임스탬프, 스트리밍 상태를 포함한다.
class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  /// AI 응답이 스트리밍 중인지 나타내는 플래그.
  ///
  /// true이면 응답이 아직 수신 중이며, UI에서 타이핑 효과나
  /// 로딩 인디케이터를 표시하는 데 활용할 수 있다.
  final bool isStreaming;

  /// 분석용 부가 정보. 화면에는 쓰이지 않고 내보내기 파일에만 실린다.
  ///
  /// - user: turn, chars, compose(작성 행동)
  /// - model: agent, turn, streaming, startedAt/firstChunkAt/completedAt, chunkCount, callId
  /// - system: kind(error 등), flow
  final Map<String, dynamic> meta;

  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.meta = const {},
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  /// 불변성 패턴 구현을 위한 복사 메서드.
  ///
  /// 원본 객체를 변경하지 않고 지정된 필드만 다른 값으로 갖는
  /// 새 [Message] 인스턴스를 생성한다. Riverpod 상태 업데이트 시 필수적으로 사용된다.
  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    Map<String, dynamic>? meta,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      meta: meta ?? this.meta,
    );
  }

  /// 메시지를 JSON [Map]으로 변환하는 직렬화 메서드.
  ///
  /// 로컬 저장소 영속화나 네트워크 전송 시 사용한다.
  /// [role]은 문자열로, [timestamp]는 ISO 8601 형식으로 변환된다.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toJson(),
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'chars': content.length,
      'meta': meta,
    };
  }

  /// JSON [Map]에서 [Message] 인스턴스를 복원하는 팩토리 생성자.
  ///
  /// 저장된 데이터를 불러오거나 API 응답을 파싱할 때 사용한다.
  /// role 문자열을 [MessageRole] enum으로 변환한다.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: MessageRole.fromJson(json['role']),
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
