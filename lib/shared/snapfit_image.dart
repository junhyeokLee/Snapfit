import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, visibleForTesting, SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/storage_url_resolver.dart';
import '../core/cache/storage_image_url_cache.dart';
import '../core/cache/memory_pressure_caches.dart';
import '../core/cache/photo_failure_versions.dart';
import 'photo_preparation.dart';

typedef _PhotoFailureScope = (int, int?, int?, int?, int?);
typedef _PreferredPhoto = ({
  String source,
  String url,
  _PhotoFailureScope? scope,
  int failureVersion,
  DateTime until,
});

/// gs://, supabase:// 또는 https:// URL을 표시용 다운로드 URL로 변환해 주는 공용 위젯.
/// - 같은 storage URI에 대해서는 앱이 살아 있는 동안 반복 resolver 호출을 줄이도록 Future를 캐싱한다.
class SnapfitImage extends StatelessWidget {
  final String urlOrGs;

  /// Ordered alternatives, tried only when the preceding source fails.
  final List<String> fallbackSources;
  final bool? automaticStorageRefresh;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? error;
  final BaseCacheManager? cacheManager;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Widget Function(BuildContext, ImageProvider)? imageBuilder;

  @visibleForTesting
  final Future<String> Function(String)? resolveStorageUrlForTesting;
  @visibleForTesting
  final bool? enableWebStorageRecoveryForTesting;

  const SnapfitImage({
    super.key,
    required this.urlOrGs,
    this.fallbackSources = const [],
    this.automaticStorageRefresh,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.error,
    this.cacheManager,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.imageBuilder,
    this.resolveStorageUrlForTesting,
    this.enableWebStorageRecoveryForTesting,
  });

  static StorageImageUrlCache _urls = StorageImageUrlCache();
  static final _failures = PhotoFailureVersions();
  static final _storageSession = ValueNotifier<int>(0);
  static SupabaseClient? _storageClient;
  static StreamSubscription<AuthState>? _storageAuth;
  static String? _storageOwner;

  @visibleForTesting
  static String? Function()? storageOwnerForTesting;

  static void _observeStorageSession() {
    final testOwner = storageOwnerForTesting;
    if (testOwner != null) {
      _setStorageOwner(testOwner());
      return;
    }
    try {
      final client = Supabase.instance.client;
      if (identical(client, _storageClient)) return;
      unawaited(_storageAuth?.cancel());
      _storageClient = client;
      _setStorageOwner(client.auth.currentUser?.id, replaceClient: true);
      _storageAuth = client.auth.onAuthStateChange.listen((_) {
        if (identical(client, _storageClient)) {
          _setStorageOwner(client.auth.currentUser?.id);
        }
      });
    } catch (_) {
      // Standalone previews/tests can display public or bundled images.
    }
  }

  static void _setStorageOwner(String? owner, {bool replaceClient = false}) {
    if (!replaceClient && _storageOwner == owner) return;
    _storageOwner = owner;
    // Pending jobs must not be shared across accounts, even for the same URI.
    _urls = StorageImageUrlCache();
    _preferred.clear();
    _unavailable.clear();
    _failures.clear();
    _storageSession.value++;
  }

  // Weak keys keep custom managers collectible. Failure entries retain only a
  // primitive scope ID and decode bounds, never the manager or its image bytes.
  static final _cacheScopes = Expando<int>('photo-cache-scope');
  static int _nextCacheScope = 0;

  _PhotoFailureScope get _failureScope {
    final manager =
        cacheManager ?? CachedNetworkImageProvider.defaultCacheManager;
    final id = _cacheScopes[manager] ??= ++_nextCacheScope;
    return (
      id,
      memCacheWidth,
      memCacheHeight,
      maxWidthDiskCache,
      maxHeightDiskCache,
    );
  }

  // Metadata only: visible images and reader preparation remember the same
  // successful fallback, without retaining widgets, providers or image bytes.
  static final _preferred = <(String, String?, String?), _PreferredPhoto>{};
  static final _unavailable =
      <((String, String?, String?), String), DateTime>{};

  List<String> get _sources => <String>{
    for (final source in [urlOrGs, ...fallbackSources])
      if (source.trim().isNotEmpty) source.trim(),
  }.take(3).toList(growable: false);

  (String, String?, String?) get _sourceKey {
    final sources = _sources;
    return (
      sources.firstOrNull ?? '',
      sources.length > 1 ? sources[1] : null,
      sources.length > 2 ? sources[2] : null,
    );
  }

  List<String> get _orderedSources {
    _observeStorageSession();
    final all = _sources;
    final usable = all
        .where((source) {
          // Direct URLs have no signing step. A stream failure is already
          // enough to defer them, even before the error widget's next frame.
          if (!source.startsWith('asset:') &&
              !_isStorage(source) &&
              _failures.rejectedSince(_failureScope, source, -1))
            return false;
          final key = (_sourceKey, source);
          final until = _unavailable[key];
          if (until == null) return true;
          if (DateTime.now().isBefore(until)) return false;
          _unavailable.remove(key);
          return true;
        })
        .toList(growable: false);
    // Defer recently failed sources, but never discard them: an original may
    // fail later after its preview has recovered. Each candidate is still tried
    // at most once (plus one bounded storage URL refresh) per load.
    final sources = [
      ...usable,
      ...all.where((source) => !usable.contains(source)),
    ];
    final choice = _preferred.remove(_sourceKey);
    if (choice == null ||
        !DateTime.now().isBefore(choice.until) ||
        !sources.contains(choice.source))
      return sources;
    _preferred[_sourceKey] = choice;
    return [
      choice.source,
      ...sources.where((source) => source != choice.source),
    ];
  }

  bool get _webRecovery => enableWebStorageRecoveryForTesting ?? kIsWeb;
  bool get _automaticRefresh => automaticStorageRefresh ?? !_webRecovery;

  static bool _isStorage(String source) =>
      source.startsWith('gs://') ||
      parseSupabaseStorageUri(source) != null ||
      privateAlbumAssetReference(source) != null;

  static void _clearMetadata() {
    _urls.clear();
    _preferred.clear();
    _unavailable.clear();
    _failures.clear();
  }

  static void _rejectUrl(
    _PhotoFailureScope scope,
    String source,
    String url,
    int version,
  ) {
    MemoryPressureCaches.register('storage-photo-metadata', _clearMetadata);
    _failures.reject(scope, url, version);
    if (_isStorage(source)) {
      _urls.invalidate(
        source,
        failedUrl: url,
        failureVersion: _failures.rejectionVersion(scope, url),
      );
    }
  }

  void _rememberSource(String source, String url, int failureVersion) {
    // An old live frame must not replace a newer recovery after its URL failed.
    if (_wasRejected(source, url, failureVersion)) return;
    if (!source.startsWith('asset:')) {
      _failures.recover(_failureScope, url, failureVersion);
    }
    MemoryPressureCaches.register('storage-photo-metadata', _clearMetadata);
    _preferred.remove(_sourceKey);
    _unavailable.remove((_sourceKey, source));
    _preferred[_sourceKey] = (
      source: source,
      url: url,
      scope: source.startsWith('asset:') ? null : _failureScope,
      failureVersion: failureVersion,
      until: DateTime.now().add(const Duration(minutes: 5)),
    );
    while (_preferred.length > 500) {
      _preferred.remove(_preferred.keys.first);
    }
  }

  void _forgetSource(String source, {String? url, int? failureVersion}) {
    final choice = _preferred[_sourceKey];
    if (choice != null &&
        choice.source == source &&
        (url == null || choice.url == url) &&
        (failureVersion == null || choice.failureVersion <= failureVersion)) {
      _preferred.remove(_sourceKey);
    }
  }

  void _markUnavailable(String source, {String? url, int? failureVersion}) {
    MemoryPressureCaches.register('storage-photo-metadata', _clearMetadata);
    _forgetSource(source, url: url, failureVersion: failureVersion);
    final key = (_sourceKey, source);
    _unavailable.remove(key);
    _unavailable[key] = DateTime.now().add(const Duration(seconds: 30));
    while (_unavailable.length > 1000) {
      _unavailable.remove(_unavailable.keys.first);
    }
  }

  Future<String> _resolveSource(String source) {
    if (!_isStorage(source)) return SynchronousFuture(source);
    _observeStorageSession();
    MemoryPressureCaches.register('storage-photo-metadata', _clearMetadata);
    final cached = _urls.peek(source);
    if (cached != null) {
      final rejection = _failures.rejectionVersion(_failureScope, cached);
      if (rejection != null) {
        // A URL consumer may have failed before this storage alias was mounted.
        // Consume that failure once, before handing its cached URL to a new load.
        _urls.invalidate(source, failedUrl: cached, failureVersion: rejection);
      }
      final reusable = _urls.peek(source);
      if (reusable != null) return SynchronousFuture(reusable);
    }
    return _urls.resolve(source, () => _signForCurrentSession(source));
  }

  Future<String> _signForCurrentSession(String source) async {
    final session = _storageSession.value;
    final resolve = resolveStorageUrlForTesting ?? resolveStorageImageUrl;
    final url = await resolve(source);
    _observeStorageSession();
    if (session != _storageSession.value) {
      throw StateError('storage_image_account_changed');
    }
    return url;
  }

  Future<String> _refreshSource(
    String source,
    String failedUrl, {
    bool explicit = false,
  }) {
    // Pending cache jobs retain the resolver and URI, not this widget's artwork.
    _observeStorageSession();
    return _urls.refresh(
      source,
      failedUrl,
      () => _signForCurrentSession(source),
      explicit: explicit,
    );
  }

  bool _wasRejected(String source, String url, int loadVersion) {
    if (source.startsWith('asset:')) return false;
    final rejection = _failures.rejectionVersion(_failureScope, url);
    if (rejection == null) return false;
    // A newly signed alias can resolve to an already failed direct URL. It
    // still needs renewal even if that failure preceded this consumer. A URL
    // renewed after consuming the failure is safe to reconsider on a new load.
    return rejection > loadVersion ||
        (_isStorage(source) && !_urls.consumedFailure(source, url, rejection));
  }

  ImageProvider _provider(String source, String url, {int? failureVersion}) =>
      ResizeImage.resizeIfNeeded(
        memCacheWidth,
        memCacheHeight,
        source.startsWith('asset:')
            ? AssetImage(source.substring('asset:'.length))
            : failureVersion != null
            ? _FailureReportingImageProvider(
                _failureScope,
                source,
                url,
                failureVersion,
                cacheManager: cacheManager,
                maxWidth: maxWidthDiskCache,
                maxHeight: maxHeightDiskCache,
              )
            : CachedNetworkImageProvider(
                url,
                cacheManager: cacheManager,
                maxWidth: maxWidthDiskCache,
                maxHeight: maxHeightDiskCache,
              ),
      );

  Future<void> _evictFailed(String source, String url) async {
    try {
      final provider = _provider(source, url);
      final key = await provider.obtainKey(ImageConfiguration.empty);
      // Do not evict another route's live image stream.
      PaintingBinding.instance.imageCache.evict(key, includeLive: false);
    } catch (_) {
      // Cache cleanup must not block a fresh authorized download.
    }
  }

  /// Resolve only; callers awaiting pixels use prepareImage instead.
  Future<ImageProvider> resolveImageProvider() async {
    _observeStorageSession();
    final session = _storageSession.value;
    final source = _orderedSources.firstOrNull ?? urlOrGs;
    final url = await _resolveSource(source);
    if (_isStorage(source) && session != _storageSession.value) {
      throw StateError('storage_image_account_changed');
    }
    return _provider(source, url);
  }

  /// Use exactly the same candidate order, URL refresh and decode keys as the
  /// visible photo. Only three candidates and one refresh per source are tried.
  Future<ImageProvider?> prepareImage(BuildContext context) async {
    _observeStorageSession();
    final session = _storageSession.value;
    bool currentSession() => session == _storageSession.value;
    Object? lastError;
    StackTrace? lastStack;
    final failureVersion = _failures.version;
    for (final source in _orderedSources) {
      String? retryUrl;
      for (var attempt = 0; attempt < (_isStorage(source) ? 2 : 1); attempt++) {
        if (!currentSession() || !checkPhotoPreparationActive(context))
          return null;
        String? url;
        try {
          url = await (retryUrl == null
              ? _resolveSource(source)
              : _refreshSource(source, retryUrl));
          if (!currentSession() || !checkPhotoPreparationActive(context))
            return null;
          if (_wasRejected(source, url, failureVersion)) {
            throw StateError('photo_url_already_rejected');
          }
          final provider = _provider(
            source,
            url,
            failureVersion: failureVersion,
          );
          Object? failure;
          StackTrace? trace;
          await precacheImage(
            provider,
            context,
            onError: (error, stack) {
              // Publish before the failed stream is evicted or a visible
              // consumer rebuilds with its previously resolved URL.
              _rejectUrl(_failureScope, source, url!, failureVersion);
              failure = error;
              trace = stack;
            },
          );
          if (!currentSession() || !context.mounted) return null;
          if (failure != null)
            Error.throwWithStackTrace(failure!, trace ?? StackTrace.current);
          if (!currentSession() || !checkPhotoPreparationActive(context))
            return null;
          _rememberSource(source, url, failureVersion);
          return provider;
        } on PhotoPreparationPaused {
          rethrow;
        } catch (error, stack) {
          lastError = error;
          lastStack = stack;
          _forgetSource(source, url: url, failureVersion: failureVersion);
          if (url == null) {
            _markUnavailable(source, failureVersion: failureVersion);
            if (!checkPhotoPreparationActive(context)) return null;
            break; // Signing failed; there is no stale URL to renew.
          }
          _rejectUrl(_failureScope, source, url, failureVersion);
          if (!_isStorage(source) || attempt > 0) {
            _markUnavailable(source, url: url, failureVersion: failureVersion);
          }
          if (!checkPhotoPreparationActive(context)) return null;
          await _evictFailed(source, url);
          retryUrl = url;
        }
      }
    }
    if (!context.mounted) return null;
    Error.throwWithStackTrace(
      lastError ?? StateError('photo_source_unavailable'),
      lastStack ?? StackTrace.current,
    );
  }

  static void invalidateResolvedUrl(String source) => _urls.invalidate(source);

  @override
  Widget build(BuildContext context) {
    if (!_sources.any(_isStorage)) return _recoveringPhoto();
    _observeStorageSession();
    return ValueListenableBuilder<int>(
      valueListenable: _storageSession,
      builder: (context, session, _) => _recoveringPhoto(session),
    );
  }

  Widget _recoveringPhoto([int? session]) => _RecoveringPhoto(
    key: ValueKey((
      session,
      _sourceKey,
      cacheManager,
      memCacheWidth,
      memCacheHeight,
      maxWidthDiskCache,
      maxHeightDiskCache,
      _automaticRefresh,
      _webRecovery,
    )),
    image: this,
  );
}

/// Report the stream failure before another consumer can reload its rejected
/// key. Unlike a persistent provider errorListener, this observer removes itself
/// after the first result and releases its ImageInfo clone on success.
class _FailureReportingImageProvider extends CachedNetworkImageProvider {
  const _FailureReportingImageProvider(
    this.scope,
    this.source,
    String url,
    this.failureVersion, {
    super.cacheManager,
    super.maxWidth,
    super.maxHeight,
  }) : super(url);

  final _PhotoFailureScope scope;
  final String source;
  final int failureVersion;

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) => _observe(super.loadImage(key, decode));

  ImageStreamCompleter _observe(ImageStreamCompleter completer) {
    late final ImageStreamListener observer;
    observer = ImageStreamListener(
      (image, _) {
        image.dispose();
        completer.removeListener(observer);
      },
      onError: (Object _, StackTrace? __) {
        SnapfitImage._rejectUrl(scope, source, url, failureVersion);
        completer.removeListener(observer);
      },
    );
    completer.addListener(observer);
    return completer;
  }
}

/// Own only the current candidate and retry state. URL/choice caches contain no
/// pixels; the existing Flutter image cache still owns decoded image lifetimes.
class _RecoveringPhoto extends StatefulWidget {
  const _RecoveringPhoto({super.key, required this.image});
  final SnapfitImage image;

  @override
  State<_RecoveringPhoto> createState() => _RecoveringPhotoState();
}

class _RecoveringPhotoState extends State<_RecoveringPhoto>
    with WidgetsBindingObserver {
  late List<String> _sources;
  Future<String>? _resolved;
  int _failureVersion = SnapfitImage._failures.version;
  int _index = 0;
  int _version = 0;
  bool _refreshUsed = false;
  bool _scheduled = false;
  bool _retrying = false;
  bool _hasTerminalFailure = false;
  bool _active = false;
  (String, String)? _lastResolved;
  String get _source => _sources[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _startIfActive() {
    final active = photoPreparationActive(context);
    final resumed = active && !_active;
    _active = active;
    if (!active) return;
    if (_resolved != null) {
      if (resumed && !_retrying) _adoptSharedPhoto();
      return;
    }
    _sources = widget.image._orderedSources;
    _failureVersion = SnapfitImage._failures.version;
    if (_sources.isNotEmpty) {
      _resolved = widget.image._resolveSource(_source);
    }
  }

  void _adoptSharedPhoto() {
    final image = widget.image;
    final choice = SnapfitImage._preferred[image._sourceKey];
    if (choice != null &&
        DateTime.now().isBefore(choice.until) &&
        choice.failureVersion >= _failureVersion &&
        (choice.scope == null || choice.scope!.$1 == image._failureScope.$1) &&
        !image._wasRejected(choice.source, choice.url, choice.failureVersion)) {
      _useSharedPhoto(choice.source, choice.url);
      return;
    }
    // Different source lists/URI spellings may share a decoded download URL.
    // Existing failure entries carry only a recovery token, never image bytes.
    for (final source in _sources) {
      if (source.startsWith('asset:')) continue;
      final cached = SnapfitImage._isStorage(source)
          ? SnapfitImage._urls.peek(source)
          : source;
      final url =
          cached ?? (_lastResolved?.$1 == source ? _lastResolved?.$2 : null);
      if (url == null) continue;
      final recovery = SnapfitImage._failures.recoveryVersion(
        image._failureScope,
        url,
      );
      if (recovery != null && recovery >= _failureVersion) {
        if (SnapfitImage._isStorage(source)) {
          SnapfitImage._urls.acceptRecovery(source, url, recovery);
        }
        if (!image._wasRejected(source, url, recovery)) {
          _useSharedPhoto(source, url);
          return;
        }
      } else if (cached != null &&
          (_hasTerminalFailure || _lastResolved?.$1 == source) &&
          cached != _lastResolved?.$2 &&
          !image._wasRejected(source, cached, -1)) {
        // A peer already renewed this URI. Join its new provider/cache key;
        // mounting it neither signs again nor duplicates an in-flight download.
        _useSharedPhoto(source, cached);
        return;
      }
    }
  }

  void _useSharedPhoto(String source, String url) {
    final image = widget.image;
    final sources = image._sources;
    if (!sources.contains(source)) return;
    // Rejoin a shared result, including a same-URL decoded recovery. Keep the
    // normal provider/cache key without signing, listeners or a pixel cache.
    _version++;
    _sources = [source, ...sources.where((candidate) => candidate != source)];
    _index = 0;
    // This resumed pass may reconsider alternatives that failed before the
    // shared success. Its chosen URL was validated above against newer errors.
    _failureVersion = SnapfitImage._failures.version;
    _lastResolved = (source, url);
    _resolved = SynchronousFuture(url);
    _scheduled = false;
    _refreshUsed = false;
    _hasTerminalFailure = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Signing as well as pixel loading must wait for a visible, resumed route.
    _startIfActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(_startIfActive);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _recover(String? failedUrl, {bool explicit = false}) async {
    _scheduled = false;
    if (!mounted || _retrying || !photoPreparationActive(context)) return;
    if (explicit && !_hasTerminalFailure) return;
    final image = widget.image;
    final source = _source;
    final refresh =
        failedUrl != null &&
        SnapfitImage._isStorage(source) &&
        (explicit || (image._automaticRefresh && !_refreshUsed));
    if (!explicit && !refresh && _index + 1 >= _sources.length) return;
    final version = ++_version;
    _hasTerminalFailure = false;
    setState(() {
      _scheduled = false;
      _retrying = true;
    });
    if (explicit) {
      // A user retry is a fresh bounded pass, including a preview that may have
      // recovered while the final original was unavailable.
      _sources = image._sources;
      _index = 0;
      _failureVersion = SnapfitImage._failures.version;
      SnapfitImage._preferred.remove(image._sourceKey);
      for (final candidate in _sources) {
        SnapfitImage._unavailable.remove((image._sourceKey, candidate));
      }
      _refreshUsed = refresh && _source == source;
      final future = _refreshUsed
          ? image._refreshSource(_source, failedUrl!, explicit: true)
          : image._resolveSource(_source);
      if (failedUrl != null) await image._evictFailed(source, failedUrl);
      if (!mounted || _version != version) return;
      setState(() {
        _resolved = future;
        _retrying = false;
      });
    } else if (refresh) {
      _refreshUsed = true;
      final future = image._refreshSource(source, failedUrl!);
      await image._evictFailed(source, failedUrl);
      if (!mounted || _version != version) return;
      setState(() {
        _resolved = future;
        _retrying = false;
      });
    } else {
      setState(() {
        _index++;
        _refreshUsed = false;
        _resolved = image._resolveSource(_source);
        _retrying = false;
      });
    }
  }

  Widget _onFailure(String? failedUrl, int version) {
    if (version != _version) return _placeholder();
    final image = widget.image;
    if (failedUrl != null && !_source.startsWith('asset:'))
      SnapfitImage._rejectUrl(
        image._failureScope,
        _source,
        failedUrl,
        _failureVersion,
      );
    image._forgetSource(
      _source,
      url: failedUrl,
      failureVersion: _failureVersion,
    );
    final refresh =
        failedUrl != null &&
        SnapfitImage._isStorage(_source) &&
        image._automaticRefresh &&
        !_refreshUsed;
    if (!refresh) {
      image._markUnavailable(
        _source,
        url: failedUrl,
        failureVersion: _failureVersion,
      );
    }
    if (refresh || _index + 1 < _sources.length) {
      if (!_scheduled) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && version == _version) unawaited(_recover(failedUrl));
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
      return _placeholder();
    }
    _hasTerminalFailure = true;
    return _failure(failedUrl);
  }

  Widget _placeholder() =>
      widget.image.placeholder ??
      Container(
        color: Colors.grey[300],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _failure(String? failedUrl) {
    if (widget.image.error != null) return widget.image.error!;
    final sources = widget.image._sources;
    if (sources.length < 2 && !sources.any(SnapfitImage._isStorage)) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      );
    }
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final action = _retrying
                ? null
                : () => _recover(failedUrl, explicit: true);
            final key = ValueKey(
              widget.image._webRecovery
                  ? 'web-storage-image-retry'
                  : 'storage-image-retry',
            );
            if (bounds.maxWidth < 180 || bounds.maxHeight < 80) {
              return IconButton(
                key: key,
                tooltip: '사진 다시 불러오기',
                onPressed: action,
                icon: const Icon(Icons.refresh, size: 20),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
              );
            }
            return TextButton.icon(
              key: key,
              onPressed: action,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('사진 다시 불러오기', style: TextStyle(fontSize: 12)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A maintained route can still rebuild offstage. Do not mount another image
    // provider there; dependencies/lifecycle rebuild this state on resume.
    if (!photoPreparationActive(context)) return _placeholder();
    if (_resolved == null) return _failure(null);
    final version = _version;
    return FutureBuilder<String>(
      key: ValueKey(version),
      future: _resolved,
      builder: (context, snapshot) {
        if (_retrying || snapshot.connectionState != ConnectionState.done)
          return _placeholder();
        final url = snapshot.data;
        if (snapshot.hasError || url == null || url.isEmpty)
          return _onFailure(null, version);
        _lastResolved = (_source, url);
        if (widget.image._wasRejected(_source, url, _failureVersion)) {
          return _onFailure(url, version);
        }
        final provider = widget.image._provider(
          _source,
          url,
          failureVersion: _failureVersion,
        );
        return Image(
          image: provider,
          fit: widget.image.fit,
          alignment: widget.image.alignment,
          filterQuality: widget.image.filterQuality,
          frameBuilder: (context, child, frame, synchronous) {
            if (frame == null) return _placeholder();
            widget.image._rememberSource(_source, url, _failureVersion);
            return widget.image.imageBuilder?.call(context, provider) ?? child;
          },
          errorBuilder: (_, __, ___) => _onFailure(url, version),
        );
      },
    );
  }
}
