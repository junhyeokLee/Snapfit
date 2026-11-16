import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/snapfit_image.dart';
import '../../social/data/social_repository.dart';
import '../../social/domain/social_models.dart';
import '../../social/data/social_album_snapshot.dart';
import '../../album/printing/print_album_document.dart';
import '../domain/moment_record.dart';
import 'moment_photo_codec.dart';

class MomentPublicationState {
  const MomentPublicationState({
    required this.recordId,
    required this.recordRevision,
    required this.sourceRevision,
    required this.status,
    required this.publicationRevision,
    this.photoId,
    this.workId,
    this.requestId,
  });

  final String recordId, status;
  final int recordRevision, sourceRevision, publicationRevision;
  final String? photoId, workId, requestId;
  bool get isPublished => status == 'published';
  bool get isPending => status == 'draft';

  factory MomentPublicationState.fromJson(Map<String, dynamic> json) =>
      MomentPublicationState(
        recordId: json['recordId'] as String,
        recordRevision: (json['recordRevision'] as num).toInt(),
        sourceRevision: (json['sourceRevision'] as num).toInt(),
        status: json['status'] as String,
        publicationRevision: (json['publicationRevision'] as num).toInt(),
        photoId: json['photoId'] as String?,
        workId: (json['workId'] ?? json['id']) as String?,
        requestId: json['requestId'] as String?,
      );
}

typedef MomentPublicationRasterizer =
    Future<Uint8List> Function(MomentPhoto photo, BuildContext context);

/// Publishes one explicitly chosen photograph. Private record objects and their
/// original URLs never cross the social boundary; only a fresh bounded PNG does.
class MomentPublicationRepository {
  MomentPublicationRepository({
    required this.social,
    required String? Function() currentUserId,
    required Stream<String?> authChanges,
    MomentPublicationRasterizer? rasterizer,
    SocialSnapshotRenderer? snapshotRenderer,
  }) : _currentUserId = currentUserId,
       _rasterizer =
           rasterizer ??
           ((photo, context) => _rasterize(photo, context, snapshotRenderer)) {
    _owner = currentUserId();
    _auth = authChanges.listen(
      (owner) {
        if (owner != _owner) {
          _owner = owner;
          _generation++;
        }
      },
      onError: (Object _, StackTrace __) {
        // An SDK refresh failure must neither escape into the app's zone nor
        // authorize continuing an earlier public-copy attempt. Keep the owner.
        if (!_disposed) _generation++;
      },
    );
  }

  final SocialRepository social;
  final String? Function() _currentUserId;
  final MomentPublicationRasterizer _rasterizer;
  late final StreamSubscription<String?> _auth;
  String? _owner;
  int _generation = 0;
  bool _disposed = false;

  Future<T> _step<T>(Future<T> operation) => operation.timeout(
    const Duration(seconds: 25),
    onTimeout: () =>
        throw const MomentException('연결이 늦어지고 있어요. 공개 상태를 다시 확인한 뒤 시도해 주세요.'),
  );

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_auth.cancel());
  }

  (String, int) _session() {
    final owner = _currentUserId();
    if (owner == null || _disposed) {
      throw const MomentException('로그인한 뒤 공개 상태를 다시 확인해 주세요.');
    }
    return (owner, _generation);
  }

  void _check((String, int) session) {
    if (_disposed ||
        session.$1 != _currentUserId() ||
        session.$2 != _generation) {
      throw const MomentException('계정이 변경됐어요. 나의 기록을 다시 열어 주세요.');
    }
  }

  Future<MomentPublicationState?> state(String recordId) async {
    final session = _session();
    final raw = await _step(social.fetchMomentPublication(recordId));
    _check(session);
    return raw == null ? null : MomentPublicationState.fromJson(raw);
  }

  Future<SocialWork> publish({
    required MomentRecord record,
    required String photoId,
    required String requestId,
    required BuildContext context,
    required bool Function() canContinue,
  }) async {
    final session = _session();
    void check() {
      _check(session);
      if (!context.mounted || !canContinue()) {
        throw const MomentException('공개를 멈췄어요. 기록에서 다시 확인해 주세요.');
      }
    }

    final photo = record.photos
        .where((photo) => photo.id == photoId)
        .firstOrNull;
    if (photo == null) throw const MomentException('공개할 사진 한 장을 골라 주세요.');
    check();
    final previous = await state(record.id);
    check();
    if (previous == null || previous.recordRevision != record.revision) {
      throw const MomentException('기록이 변경됐어요. 최신 기록을 다시 확인해 주세요.');
    }
    if (previous.isPublished &&
        previous.workId != null &&
        previous.photoId == photoId &&
        previous.sourceRevision == record.revision) {
      final published = await _step(social.fetchWork(previous.workId!));
      check();
      return _requirePublished(published);
    }
    if (previous.status == 'private' &&
        previous.workId != null &&
        previous.photoId == photoId &&
        previous.sourceRevision == record.revision) {
      await _step(
        social.setMomentPublicationVisibility(
          previous.workId!,
          true,
          expectedPublicationRevision: previous.publicationRevision,
        ),
      );
      check();
      final published = await _step(social.fetchWork(previous.workId!));
      check();
      return _requirePublished(published);
    }
    await _step(social.ensureOwnProfile());
    check();
    final draft = await _step(
      social.beginMomentPublication(
        recordId: record.id,
        photoId: photo.id,
        expectedRevision: record.revision,
        requestId: requestId,
      ),
    );
    check();
    if (draft.status == 'published') {
      final published = await _step(social.fetchWork(draft.id));
      check();
      return _requirePublished(published);
    }
    if (draft.status != 'draft') {
      throw const MomentException('공개 상태가 바뀌었어요. 기록에서 다시 확인해 주세요.');
    }
    final png = await _step(_rasterizer(photo, context));
    check();
    if (!isSocialPng(png))
      throw const MomentException('공개 사진을 준비하지 못했어요. 다시 시도해 주세요.');
    await _step(social.uploadPublicationPage(draft.id, 0, png));
    check();
    final published = await _step(social.finalizePublication(draft.id));
    check();
    return _requirePublished(published);
  }

  SocialWork _requirePublished(SocialWork? work) {
    if (work == null || !work.isPublished) {
      throw const MomentException('공개 상태가 바뀌었어요. 기록에서 다시 확인해 주세요.');
    }
    return work;
  }

  Future<void> makePrivate(String recordId) async {
    final session = _session();
    final current = await state(recordId);
    _check(session);
    if (current == null ||
        current.workId == null ||
        (!current.isPublished && !current.isPending))
      return;
    await _step(
      social.setMomentPublicationVisibility(
        current.workId!,
        false,
        expectedPublicationRevision: current.publicationRevision,
      ),
    );
    _check(session);
    final confirmed = await state(recordId);
    _check(session);
    if (confirmed?.isPublished == true || confirmed?.isPending == true) {
      throw const MomentException('공개 상태가 바뀌었어요. 나만 보기로 다시 바꿔 주세요.');
    }
  }

  static Future<Uint8List> _rasterize(
    MomentPhoto photo,
    BuildContext context,
    SocialSnapshotRenderer? snapshotRenderer,
  ) async {
    if (photo.design case final design?) {
      final renderer = snapshotRenderer ?? SocialSnapshotRenderer();
      final page = PrintAlbumPage(
        index: 0,
        isCover: false,
        canvasSize: design.canvasSize,
        layers: design.layersForPhoto(photo.storageUri),
        backgroundColor: design.backgroundColor,
      );
      await renderer.prepareFonts([page]);
      if (!context.mounted) {
        throw const MomentException('사진 꾸미기를 준비하지 못했어요. 다시 열어 주세요.');
      }
      return renderer.renderPage(page, theme: Theme.of(context));
    }
    final edge = math.max(photo.width, photo.height);
    if (edge <= 0) throw const MomentException('사진 정보를 확인해 주세요.');
    final decodeWidth = (photo.width * math.min(1, 1440 / edge)).round().clamp(
      1,
      1440,
    );
    final provider = await SnapfitImage(
      urlOrGs: photo.storageUri,
      memCacheWidth: decodeWidth,
    ).prepareImage(context).timeout(const Duration(seconds: 25));
    if (provider == null || !context.mounted) {
      throw const MomentException('사진을 준비하지 못했어요. 다시 시도해 주세요.');
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        try {
          if (!completer.isCompleted) completer.complete(image.image.clone());
        } finally {
          image.dispose();
        }
      },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    ui.Image? image;
    try {
      image = await completer.future.timeout(const Duration(seconds: 25));
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) throw const MomentException('사진을 준비하지 못했어요.');
      final normalized = await prepareMomentPhoto(
        encoded.buffer.asUint8List(
          encoded.offsetInBytes,
          encoded.lengthInBytes,
        ),
        maxEdge: 1440,
        maxOutputBytes: 8 * 1024 * 1024,
      );
      return normalized.bytes;
    } finally {
      stream.removeListener(listener);
      image?.dispose();
    }
  }
}
