// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streaming_message_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(StreamingMessage)
final streamingMessageProvider = StreamingMessageProvider._();

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
final class StreamingMessageProvider
    extends $NotifierProvider<StreamingMessage, StreamingMessageState?> {
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
  StreamingMessageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streamingMessageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streamingMessageHash();

  @$internal
  @override
  StreamingMessage create() => StreamingMessage();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamingMessageState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamingMessageState?>(value),
    );
  }
}

String _$streamingMessageHash() => r'0ef68d538de1404b3a96b068457d9c4e9804d04a';

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

abstract class _$StreamingMessage extends $Notifier<StreamingMessageState?> {
  StreamingMessageState? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<StreamingMessageState?, StreamingMessageState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StreamingMessageState?, StreamingMessageState?>,
              StreamingMessageState?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
