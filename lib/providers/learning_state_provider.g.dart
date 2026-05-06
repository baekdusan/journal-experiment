// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LearningStateNotifier)
final learningStateProvider = LearningStateNotifierProvider._();

final class LearningStateNotifierProvider
    extends $NotifierProvider<LearningStateNotifier, LearningState> {
  LearningStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningStateNotifierHash();

  @$internal
  @override
  LearningStateNotifier create() => LearningStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningState>(value),
    );
  }
}

String _$learningStateNotifierHash() =>
    r'bca76e19a2e60b200988aeed977eb9da533b24fa';

abstract class _$LearningStateNotifier extends $Notifier<LearningState> {
  LearningState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LearningState, LearningState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LearningState, LearningState>,
              LearningState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
