// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GalleryNotifier)
const galleryProvider = GalleryNotifierProvider._();

final class GalleryNotifierProvider
    extends $NotifierProvider<GalleryNotifier, GalleryState> {
  const GalleryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryNotifierHash();

  @$internal
  @override
  GalleryNotifier create() => GalleryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryState>(value),
    );
  }
}

String _$galleryNotifierHash() => r'c113778471269c1ed96adfa4faaf4bef734df617';

abstract class _$GalleryNotifier extends $Notifier<GalleryState> {
  GalleryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GalleryState, GalleryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GalleryState, GalleryState>,
              GalleryState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
