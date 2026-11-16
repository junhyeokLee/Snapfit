import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute, SynchronousFuture;
import 'package:flutter/widgets.dart';

import '../../../../core/cache/memory_pressure_caches.dart';
import '../../../../core/constants/cover_size.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_page.dart';
import 'album_document_worker.dart';
import 'album_progress_document.dart';

const albumCompletionCriteria =
    '사진칸이 있는 쪽은 모든 칸에 내 사진을 채워야 해요.\n'
    '사진칸이 없는 쪽은 직접 쓴 글이 있어야 해요.\n'
    '템플릿·배경·스티커·기본 문구만으로는 완성되지 않아요.\n'
    '표지를 제외한 모든 내지가 완성되어야 앨범이 완성돼요.\n'
    '기존 내용의 작성 여부를 확인할 수 없으면 만드는 중으로 표시해요.';

class AlbumProgressInfo {
  const AlbumProgressInfo({
    required this.completedPages,
    required this.targetPages,
    this.coverSize,
    this.firstIncompletePageIndex,
    this.firstIncompletePageNumber,
    this.firstIncompletePhotoSlots = 0,
    this.firstUnfilledPhotoLayerId,
  });
  final int completedPages, targetPages;
  final CoverSize? coverSize;
  final int? firstIncompletePageIndex, firstIncompletePageNumber;
  final int firstIncompletePhotoSlots;
  final String? firstUnfilledPhotoLayerId;
  bool get hasTarget => targetPages > 0;
  bool get isCompleted => hasTarget && completedPages >= targetPages;
  double get ratio =>
      hasTarget ? (completedPages / targetPages).clamp(0.0, 1.0) : 0.0;
  String get percentLabel => hasTarget ? '${(ratio * 100).round()}%' : '목표 없음';
  String get pageProgressLabel => hasTarget
      ? '$completedPages/$targetPages 페이지 진행 중'
      : '$completedPages 페이지 진행 중';
}

/// Finds an actual position in the prepared editor document. The cover is
/// excluded even when it has no content; completion uses the same provenance
/// and visibility rules as the saved-document progress shown in the library.
/// Returns null when all available interiors are complete or none exist.
int? firstIncompleteAlbumPageIndex(List<AlbumPage> pages) {
  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    if (page.isCover) continue;
    if (!preparedAlbumPageProgress(page).isComplete) {
      return index;
    }
  }
  return null;
}

({
  bool isComplete,
  int photoSlots,
  int filledPhotoSlots,
  String? firstUnfilledPhotoId,
})
preparedAlbumPageProgress(AlbumPage page) => albumPageContentSummary(
  page.layers.map(
    (layer) => <String, dynamic>{
      'id': layer.id,
      'type': layer.type.name,
      'templateContent': layer.isTemplateContent,
      'opacity': layer.opacity,
      'payload': <String, dynamic>{
        'text': layer.text,
        // A picked original has not been uploaded yet. It can complete the
        // local page; the save flow still waits for its durable server upload.
        'originalUrl': layer.asset != null
            ? 'local:pending-photo'
            : layer.originalUrl,
        'previewUrl': layer.previewUrl,
        'imageUrl': layer.imageUrl,
      },
    },
  ),
);

// Weak album keys and compact counts/dimensions: no raw JSON result cache and no
// retained history after refresh. Existing synchronous callers share the cache.
Expando<AlbumProgressInfo> _progress = Expando('album progress');
int _cacheEpoch = 0;

void _clearProgressCache() {
  _progress = Expando('album progress');
  _cacheEpoch++;
}

AlbumProgressInfo _resolveProgress(
  int targetPages,
  String ratio,
  AlbumDocumentMetadata document,
) {
  // totalPages is allocation, not proof of authored content. Templates allocate
  // their whole book immediately, and added empty interiors must also be filled.
  final target = math.max(math.max(0, targetPages), document.innerPages);
  final completed = document.completedPages;
  return AlbumProgressInfo(
    completedPages: target > 0 ? completed.clamp(0, target).toInt() : completed,
    targetPages: target,
    coverSize: resolveAlbumCoverSize(
      ratio,
      printProduct: document.printProduct,
    ),
    firstIncompletePageIndex: document.firstIncompletePageIndex,
    firstIncompletePageNumber: document.firstIncompletePageNumber,
    firstIncompletePhotoSlots: document.firstIncompletePhotoSlots,
    firstUnfilledPhotoLayerId: document.firstUnfilledPhotoLayerId,
  );
}

AlbumProgressInfo? cachedAlbumProgress(Album album) {
  MemoryPressureCaches.register('album-progress', _clearProgressCache);
  final cached = _progress[album];
  if (cached != null) return cached;
  if (album.coverLayersJson.isEmpty || album.coverLayersJson == '{}') {
    return _cacheResult(album, const AlbumDocumentMetadata());
  }
  return null;
}

AlbumProgressInfo _cacheResult(Album album, AlbumDocumentMetadata document) {
  final result = _resolveProgress(album.targetPages, album.ratio, document);
  album.cachePhysicalCoverSize(result.coverSize!);
  return _progress[album] = result;
}

/// Kept for existing non-home callers. Home captions/filters use the loader.
AlbumProgressInfo calculateAlbumProgress(Album album) =>
    cachedAlbumProgress(album) ??
    _cacheResult(album, analyzeAlbumDocument(album.coverLayersJson));

class AlbumProgressRequest {
  AlbumProgressRequest._();
  final _result = Completer<AlbumProgressInfo?>();
  _ProgressJob? _job;
  Future<AlbumProgressInfo?> get result => _result.future;
  void cancel() => AlbumProgressLoader._cancel(this);

  void _complete(AlbumProgressInfo? value) {
    _job = null;
    if (!_result.isCompleted) _result.complete(value);
  }
}

class _ProgressJob {
  _ProgressJob(Album source)
    : album = WeakReference(source),
      queuedAlbum = source,
      targetPages = source.targetPages,
      ratio = source.ratio,
      epoch = _cacheEpoch;
  final WeakReference<Album> album;
  // A queued request owns its input only until starting or cancellation. Once
  // compute starts, the broker retains just this weak key and small metadata.
  Album? queuedAlbum;
  final int targetPages;
  final String ratio;
  final int epoch;
  final clients = <AlbumProgressRequest>{};
  bool started = false;
  bool cancelled = false;
  bool get needed => !cancelled && (started || clients.isNotEmpty);
}

/// Visible captions request only mounted items; a filter requests one album at
/// a time. Queued work is cancellable; running work remains reusable through a
/// weak key, even while there are temporarily no visible consumers.
abstract final class AlbumProgressLoader {
  static const _workerThreshold = 32 * 1024;
  static final _jobs = Expando<_ProgressJob>('album document work');
  static final _pending = Queue<_ProgressJob>();
  static bool _running = false;
  static int? _frame;

  static AlbumProgressRequest request(Album album) {
    final request = AlbumProgressRequest._();
    final cached = cachedAlbumProgress(album);
    if (cached != null) {
      request._complete(cached);
      return request;
    }
    var job = _jobs[album];
    if (job == null) {
      job = _ProgressJob(album);
      _jobs[album] = job;
      _pending.add(job);
    }
    job.clients.add(request);
    request._job = job;
    _schedule();
    return request;
  }

  static void _cancel(AlbumProgressRequest request) {
    final job = request._job;
    request._complete(null);
    if (job == null) return;
    job.clients.remove(request);
    if (job.clients.isNotEmpty) return;
    // A running compute cannot be stopped by cancelling its Future. Keep its
    // weak lookup so scroll-idle/tab-resume can rejoin instead of decoding twice.
    if (job.started) return;
    final album = job.album.target;
    if (album != null && identical(_jobs[album], job)) _jobs[album] = null;
    _pending.remove(job);
    job.cancelled = true;
    job.queuedAlbum = null;
    if (_pending.isEmpty && _frame != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_frame!);
      _frame = null;
    }
  }

  static void _schedule() {
    if (_running || _frame != null || _pending.isEmpty) return;
    _frame = WidgetsBinding.instance.scheduleFrameCallback((_) {
      _frame = null;
      if (_pending.isEmpty) return;
      final job = _pending.removeFirst();
      if (!job.needed) {
        _schedule();
        return;
      }
      _running = true;
      _start(job).then(
        (document) => _finish(job, document),
        onError: (Object _, StackTrace __) =>
            _finish(job, const AlbumDocumentMetadata(), cacheable: false),
      );
    });
  }

  static Future<AlbumDocumentMetadata?> _start(_ProgressJob job) {
    final source = job.queuedAlbum!.coverLayersJson;
    job.queuedAlbum = null;
    if (source.length <= _workerThreshold) {
      job.started = true;
      return SynchronousFuture(analyzeAlbumDocument(source));
    }
    return AlbumDocumentWorker.run(() {
      job.started = true;
      return compute(
        analyzeAlbumDocument,
        source,
        debugLabel: 'album-progress-document',
      );
    }, isCurrent: () => job.needed);
  }

  static void _finish(
    _ProgressJob job,
    AlbumDocumentMetadata? document, {
    bool cacheable = true,
  }) {
    final album = job.album.target;
    AlbumProgressInfo? result;
    if (album != null && identical(_jobs[album], job)) _jobs[album] = null;
    if (!job.cancelled && document != null) {
      result = _resolveProgress(job.targetPages, job.ratio, document);
      // Cache only compact metadata for an album that is still alive. Work
      // started before pressure cleanup must never refill the cleared cache.
      // A worker failure may display server/ratio fallbacks, but must not save
      // an estimated size over valid print metadata that has not been read.
      if (cacheable && album != null && job.epoch == _cacheEpoch) {
        _progress[album] = result;
        album.cachePhysicalCoverSize(result.coverSize!);
      }
    }
    for (final client in job.clients) {
      client._complete(result);
    }
    job.clients.clear();
    job.queuedAlbum = null;
    _running = false;
    _schedule();
  }
}
