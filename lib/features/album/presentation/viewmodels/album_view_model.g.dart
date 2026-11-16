// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlbumViewModel)
final albumViewModelProvider = AlbumViewModelProvider._();

final class AlbumViewModelProvider
    extends $AsyncNotifierProvider<AlbumViewModel, Album?> {
  AlbumViewModelProvider._()
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

String _$albumViewModelHash() => r'b9a8f28f5b736452686a5bd16b173101a0b3ca28';

abstract class _$AlbumViewModel extends $AsyncNotifier<Album?> {
  FutureOr<Album?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Album?>, Album?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Album?>, Album?>,
              AsyncValue<Album?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
