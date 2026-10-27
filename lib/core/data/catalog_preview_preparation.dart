import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'catalog_preview.dart';

class CatalogPreviewPreparation {
  CatalogPreviewPreparation._(this.cover, this.spread);
  final bool cover, spread;
  final _result = Completer<CatalogPreview?>();
  _PreparationJob? _job;
  Future<CatalogPreview?> get future => _result.future;

  void cancel() => CatalogPreviewPreparations._cancel(this);

  void _complete(CatalogPreview? preview) {
    _job = null;
    if (!_result.isCompleted) _result.complete(preview);
  }
}

class _PreparationJob {
  _PreparationJob(this.preview);
  CatalogPreview? preview;
  final clients = <CatalogPreviewPreparation>{};
}

/// Worker results contain raw maps. Build native layers for only one cover or
/// spread per frame, sharing work across the visible consumers of that preview.
/// No widget callbacks or completed futures are retained after a job finishes.
abstract final class CatalogPreviewPreparations {
  static final _jobs = HashMap<CatalogPreview, _PreparationJob>.identity();
  static final _pending = Queue<_PreparationJob>();
  static int? _frame;

  static CatalogPreviewPreparation prepare(
    CatalogPreview preview, {
    required bool cover,
    required bool spread,
  }) {
    final request = CatalogPreviewPreparation._(cover, spread);
    if (preview.hasPreparedParts(cover: cover, spread: spread)) {
      request._complete(preview);
      return request;
    }
    final job = _jobs.putIfAbsent(preview, () {
      final job = _PreparationJob(preview);
      _pending.add(job);
      return job;
    });
    request._job = job;
    job.clients.add(request);
    _schedule();
    return request;
  }

  static void _cancel(CatalogPreviewPreparation request) {
    final job = request._job;
    request._complete(null);
    if (job == null) return;
    job.clients.remove(request);
    if (job.clients.isEmpty) {
      _pending.remove(job);
      _jobs.remove(job.preview);
      job.preview = null;
    }
    if (_pending.isEmpty && _frame != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_frame!);
      _frame = null;
    }
  }

  static void _schedule() {
    if (_frame != null || _pending.isEmpty) return;
    _frame = WidgetsBinding.instance.scheduleFrameCallback((_) {
      _frame = null;
      final job = _pending.removeFirst();
      final preview = job.preview!;
      try {
        final cover = job.clients.any(
          (client) => client.cover && !preview.hasPreparedParts(cover: true),
        );
        // A request for both surfaces gets its cover first. Spread layers wait
        // for the next frame rather than adding to the cover's construction.
        preview.prepareParts(
          cover: cover,
          spread: !cover && job.clients.any((client) => client.spread),
        );
        job.clients.removeWhere((client) {
          if (!preview.hasPreparedParts(
            cover: client.cover,
            spread: client.spread,
          ))
            return false;
          client._complete(preview);
          return true;
        });
      } on Object {
        for (final client in job.clients) {
          client._complete(null);
        }
        job.clients.clear();
      }
      if (job.clients.isEmpty) {
        _jobs.remove(preview);
        job.preview = null;
      } else {
        _pending.add(job);
      }
      _schedule();
    });
  }
}
