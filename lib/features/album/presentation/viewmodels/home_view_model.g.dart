// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeViewModel)
const homeViewModelProvider = HomeViewModelProvider._();

final class HomeViewModelProvider
    extends $AsyncNotifierProvider<HomeViewModel, List<Album>> {
  const HomeViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeViewModelHash();

  @$internal
  @override
  HomeViewModel create() => HomeViewModel();
}

String _$homeViewModelHash() => r'a3684bdf9032656f9606df25a3d0e8c5be1ea475';

abstract class _$HomeViewModel extends $AsyncNotifier<List<Album>> {
  FutureOr<List<Album>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Album>>, List<Album>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Album>>, List<Album>>,
              AsyncValue<List<Album>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
