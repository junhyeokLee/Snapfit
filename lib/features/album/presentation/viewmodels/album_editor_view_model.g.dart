// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_editor_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlbumEditorViewModel)
final albumEditorViewModelProvider = AlbumEditorViewModelProvider._();

final class AlbumEditorViewModelProvider
    extends $AsyncNotifierProvider<AlbumEditorViewModel, AlbumEditorState> {
  AlbumEditorViewModelProvider._()
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
    r'17eeec5a61e235229cafdbd3006d4298c10ed347';

abstract class _$AlbumEditorViewModel extends $AsyncNotifier<AlbumEditorState> {
  FutureOr<AlbumEditorState> build();
  @$mustCallSuper
  @override
  void runBuild() {
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
    element.handleCreate(ref, build);
  }
}
