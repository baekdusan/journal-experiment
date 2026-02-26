import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'streaming_message_provider.g.dart';

/// 스트리밍 중인 메시지의 임시 상태를 담는 모델.
///
/// 이 상태는 메모리에만 존재하며, 스트리밍이 완료되면 삭제된다.
/// ChatSession에는 스트리밍 완료 시 1회만 업데이트되어 성능을 최적화한다.
class StreamingMessageState {
  /// 스트리밍 중인 메시지의 고유 ID
  final String messageId;

  /// 현재까지 누적된 메시지 내용
  final String content;

  const StreamingMessageState({
    required this.messageId,
    required this.content,
  });

  StreamingMessageState copyWith({
    String? messageId,
    String? content,
  }) {
    return StreamingMessageState(
      messageId: messageId ?? this.messageId,
      content: content ?? this.content,
    );
  }
}

/// 현재 스트리밍 중인 메시지의 상태를 관리하는 Provider.
///
/// **사용 목적:**
/// - 스트리밍 중에는 이 Provider만 업데이트하여 ChatSession 업데이트 오버헤드 제거
/// - MessageBubble 위젯만 이 Provider를 감시하여 UI 업데이트 범위 최소화
/// - 스트리밍 완료 시 clear()하여 메모리 누수 방지
///
/// **성능 향상:**
/// - 이전: 50개 청크 × ChatSession 전체 복사 = O(50 × M)
/// - 현재: 50개 청크 × String 추가 = O(50)
@riverpod
class StreamingMessage extends _$StreamingMessage {
  @override
  StreamingMessageState? build() {
    return null;
  }

  /// 새로운 메시지에 대한 스트리밍을 시작한다.
  ///
  /// [messageId]: 스트리밍할 메시지의 고유 ID
  void start(String messageId) {
    state = StreamingMessageState(
      messageId: messageId,
      content: '',
    );
  }

  /// 현재 스트리밍 중인 메시지에 청크를 추가한다.
  ///
  /// [chunk]: Gemini API로부터 받은 텍스트 청크
  ///
  /// 스트리밍이 시작되지 않은 상태(state == null)에서는 무시된다.
  void appendChunk(String chunk) {
    if (state == null) return;
    state = state!.copyWith(content: state!.content + chunk);
  }

  /// 스트리밍 상태를 초기화한다.
  ///
  /// 스트리밍 완료 또는 에러 발생 시 호출하여 메모리를 정리한다.
  void clear() {
    state = null;
  }

  /// 특정 메시지가 현재 스트리밍 중인지 확인한다.
  ///
  /// [messageId]: 확인할 메시지의 ID
  ///
  /// Returns: 해당 메시지가 스트리밍 중이면 true
  bool isStreaming(String messageId) {
    return state?.messageId == messageId;
  }
}
