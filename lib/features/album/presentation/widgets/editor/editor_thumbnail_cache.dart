import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// No global byte cache: only active/queued work is shared between panels.
/// The shared limit also applies while an old panel's native call is finishing.
class EditorThumbnailDispatcher {
  EditorThumbnailDispatcher({this.maxConcurrent = 2})
    : assert(maxConcurrent > 0);

  static final shared = EditorThumbnailDispatcher();
  final int maxConcurrent;
  final _jobs = <String, _ThumbnailJob>{};
  final _queue = Queue<_ThumbnailJob>();
  int _active = 0;

  _ThumbnailHandle _acquire(
    String assetId,
    Future<Uint8List?> Function() load,
  ) {
    final job = _jobs.putIfAbsent(assetId, () {
      final job = _ThumbnailJob(assetId, load);
      _queue.add(job);
      return job;
    });
    job.consumers++;
    _drain();
    return _ThumbnailHandle(job.result.future, () {
      job.consumers--;
      if (job.consumers == 0 && !job.started) {
        _queue.remove(job);
        _jobs.remove(job.assetId);
        job.load = null;
        job.result.complete(const _ThumbnailResult(null, completed: false));
      }
    });
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      job.started = true;
      _active++;
      unawaited(_load(job));
    }
  }

  Future<void> _load(_ThumbnailJob job) async {
    Uint8List? bytes;
    try {
      bytes = await job.load!();
    } catch (_) {
      // A missing/inaccessible photo uses the normal numbered placeholder.
    } finally {
      job.load = null;
      _jobs.remove(job.assetId);
      _active--;
      job.result.complete(_ThumbnailResult(bytes, completed: true));
      _drain();
    }
  }
}

class _ThumbnailJob {
  _ThumbnailJob(this.assetId, this.load);
  final String assetId;
  Future<Uint8List?> Function()? load;
  final result = Completer<_ThumbnailResult>();
  int consumers = 0;
  bool started = false;
}

class _ThumbnailResult {
  const _ThumbnailResult(this.bytes, {required this.completed});
  final Uint8List? bytes;
  final bool completed;
}

class _ThumbnailHandle {
  _ThumbnailHandle(this.future, this.release);
  final Future<_ThumbnailResult> future;
  final void Function() release;
}

/// Completed thumbnails live only as long as their rearrange panel. Pending
/// requests are never evicted by this LRU and do not create duplicate work.
class EditorThumbnailCache {
  EditorThumbnailCache({
    EditorThumbnailDispatcher? dispatcher,
    this.maxEntries = 32,
    this.maxBytes = 2 * 1024 * 1024,
  }) : _dispatcher = dispatcher ?? EditorThumbnailDispatcher.shared,
       assert(maxEntries > 0),
       assert(maxBytes > 0);

  final EditorThumbnailDispatcher _dispatcher;
  final int maxEntries, maxBytes;
  final _completed = <String, Uint8List?>{};
  final _leases = <EditorThumbnailLease>{};
  int _bytes = 0;
  bool _disposed = false;

  EditorThumbnailLease acquire(
    String assetId,
    Future<Uint8List?> Function() load,
  ) {
    assert(!_disposed);
    late final EditorThumbnailLease lease;
    if (_completed.containsKey(assetId)) {
      final bytes = _completed.remove(assetId);
      _completed[assetId] = bytes;
      lease = EditorThumbnailLease._(
        Future.value(bytes),
        () => _leases.remove(lease),
      );
    } else {
      final handle = _dispatcher._acquire(assetId, load);
      lease = EditorThumbnailLease._(
        handle.future.then((result) {
          if (!_disposed && !lease._released && result.completed) {
            _remember(assetId, result.bytes);
          }
          return result.bytes;
        }),
        () {
          handle.release();
          _leases.remove(lease);
        },
      );
    }
    _leases.add(lease);
    return lease;
  }

  void _remember(String assetId, Uint8List? bytes) {
    _bytes -= _completed.remove(assetId)?.lengthInBytes ?? 0;
    if ((bytes?.lengthInBytes ?? 0) > maxBytes) return;
    _completed[assetId] = bytes;
    _bytes += bytes?.lengthInBytes ?? 0;
    while (_completed.length > maxEntries || _bytes > maxBytes) {
      _bytes -= _completed.remove(_completed.keys.first)?.lengthInBytes ?? 0;
    }
  }

  void retainOnly(Set<String> assetIds) {
    _completed.removeWhere((id, bytes) {
      if (assetIds.contains(id)) return false;
      _bytes -= bytes?.lengthInBytes ?? 0;
      return true;
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final lease in _leases.toList(growable: false)) {
      lease.release();
    }
    _completed.clear();
    _bytes = 0;
  }
}

class EditorThumbnailLease {
  EditorThumbnailLease._(this.future, this._onRelease);
  final Future<Uint8List?> future;
  void Function()? _onRelease;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    final callback = _onRelease;
    _onRelease = null;
    callback?.call();
  }
}
