// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlbumViewModel)
const albumViewModelProvider = AlbumViewModelProvider._();

final class AlbumViewModelProvider
    extends $AsyncNotifierProvider<AlbumViewModel, AlbumState> {
  const AlbumViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumViewModelHash();

  @$internal
  @override
  AlbumViewModel create() => AlbumViewModel();
}

String _$albumViewModelHash() => r'ac9ad732b60fba4531faf6e4a7c7bdb429ada257';

abstract class _$AlbumViewModel extends $AsyncNotifier<AlbumState> {
  FutureOr<AlbumState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<AlbumState>, AlbumState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AlbumState>, AlbumState>,
              AsyncValue<AlbumState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
