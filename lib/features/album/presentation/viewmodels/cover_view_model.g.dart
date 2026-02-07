// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cover_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoverViewModel)
const coverViewModelProvider = CoverViewModelProvider._();

final class CoverViewModelProvider
    extends $AsyncNotifierProvider<CoverViewModel, CoverState> {
  const CoverViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coverViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coverViewModelHash();

  @$internal
  @override
  CoverViewModel create() => CoverViewModel();
}

String _$coverViewModelHash() => r'55f1d091aea4aee906fa3d952f5e1abe51e69b47';

abstract class _$CoverViewModel extends $AsyncNotifier<CoverState> {
  FutureOr<CoverState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CoverState>, CoverState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoverState>, CoverState>,
              AsyncValue<CoverState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
