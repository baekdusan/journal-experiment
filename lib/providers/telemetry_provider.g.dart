// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 세션 텔레메트리 누적기.
///
/// 메시지·학습 상태와 달리 화면을 그리지 않으므로 아무도 watch하지 않는다.
/// 내보내기 시점에 [SessionExportService]가 한 번 읽는다.
/// 시작 화면의 시작 버튼([startExperiment])에서 초기화되고 참가자가 기록된다.

@ProviderFor(Telemetry)
final telemetryProvider = TelemetryProvider._();

/// 세션 텔레메트리 누적기.
///
/// 메시지·학습 상태와 달리 화면을 그리지 않으므로 아무도 watch하지 않는다.
/// 내보내기 시점에 [SessionExportService]가 한 번 읽는다.
/// 시작 화면의 시작 버튼([startExperiment])에서 초기화되고 참가자가 기록된다.
final class TelemetryProvider
    extends $NotifierProvider<Telemetry, SessionTelemetry> {
  /// 세션 텔레메트리 누적기.
  ///
  /// 메시지·학습 상태와 달리 화면을 그리지 않으므로 아무도 watch하지 않는다.
  /// 내보내기 시점에 [SessionExportService]가 한 번 읽는다.
  /// 시작 화면의 시작 버튼([startExperiment])에서 초기화되고 참가자가 기록된다.
  TelemetryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'telemetryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$telemetryHash();

  @$internal
  @override
  Telemetry create() => Telemetry();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionTelemetry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionTelemetry>(value),
    );
  }
}

String _$telemetryHash() => r'768db32ea6fa39e877a146ad1ab3dc99930de190';

/// 세션 텔레메트리 누적기.
///
/// 메시지·학습 상태와 달리 화면을 그리지 않으므로 아무도 watch하지 않는다.
/// 내보내기 시점에 [SessionExportService]가 한 번 읽는다.
/// 시작 화면의 시작 버튼([startExperiment])에서 초기화되고 참가자가 기록된다.

abstract class _$Telemetry extends $Notifier<SessionTelemetry> {
  SessionTelemetry build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionTelemetry, SessionTelemetry>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionTelemetry, SessionTelemetry>,
              SessionTelemetry,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
