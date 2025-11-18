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

String _$coverViewModelHash() => r'ddd5b1a946a1525cf71efef5c951c572d91c9f8d';

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
