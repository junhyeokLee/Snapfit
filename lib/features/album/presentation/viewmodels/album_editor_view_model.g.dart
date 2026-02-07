// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_editor_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlbumEditorViewModel)
const albumEditorViewModelProvider = AlbumEditorViewModelProvider._();

final class AlbumEditorViewModelProvider
    extends $AsyncNotifierProvider<AlbumEditorViewModel, AlbumEditorState> {
  const AlbumEditorViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumEditorViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumEditorViewModelHash();

  @$internal
  @override
  AlbumEditorViewModel create() => AlbumEditorViewModel();
}

String _$albumEditorViewModelHash() =>
    r'ac19f410a4acca1008a4d952f6ed4a3c94aeb21a';

abstract class _$AlbumEditorViewModel extends $AsyncNotifier<AlbumEditorState> {
  FutureOr<AlbumEditorState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<AlbumEditorState>, AlbumEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AlbumEditorState>, AlbumEditorState>,
              AsyncValue<AlbumEditorState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
