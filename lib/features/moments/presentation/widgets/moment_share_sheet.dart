import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_extensions.dart';

import '../../../../shared/sharing/feed_share_sheet.dart';
import '../../data/moment_photo_share_exporter.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import 'moments_widgets.dart';

final momentPhotoShareExporterProvider = Provider<MomentPhotoShareExporter>(
  (_) => MomentPhotoShareExporter(),
);

final _activeShares = Expando<Object>('private-moment-share-session');

/// Shares one explicitly selected flattened image. This does not create a
/// publication, upload a private photograph, or expose a private storage URI.
Future<void> showMomentShareSheet(
  BuildContext context, {
  required MomentRecord record,
  String? initialPhotoId,
}) async {
  if (!context.mounted || record.photos.isEmpty) return;
  final scope = ProviderScope.containerOf(context, listen: false);
  if (_activeShares[scope] != null) return;
  final repository = scope.read(momentsRepositoryProvider);
  final owner = repository.currentUserId;
  if (owner == null || scope.read(momentsCurrentUserIdProvider) != owner)
    return;
  final snapshot = MomentRecord(
    id: record.id,
    recordDate: record.recordDate,
    caption: record.caption,
    photos: List.unmodifiable(record.photos),
    revision: record.revision,
  );
  final token = Object();
  _activeShares[scope] = token;
  var sessionChanged = false;
  final session = repository.authChanges.listen((next) {
    // A → B → A still invalidates this request, even if a provider rebuild
    // batches those auth events into an apparently unchanged account.
    if (next != owner) sessionChanged = true;
  }, onError: (Object _, StackTrace __) => sessionChanged = true);
  bool active() {
    if (!context.mounted || sessionChanged || _activeShares[scope] != token) {
      return false;
    }
    try {
      return repository.currentUserId == owner &&
          scope.read(momentsCurrentUserIdProvider) == owner;
    } catch (_) {
      return false;
    }
  }

  var authorized = <String, MomentPhoto>{};
  Future<void> validate() async {
    if (!active()) throw const MomentShareExportCancelled();
    final journal = await repository
        .listMonth(momentMonth(snapshot.recordDate))
        .timeout(const Duration(seconds: 12));
    if (!active()) throw const MomentShareExportCancelled();
    MomentRecord? current;
    for (final candidate in journal.records) {
      if (candidate.id == snapshot.id) {
        current = candidate;
        break;
      }
    }
    if (current == null || !_sameRecord(snapshot, current)) {
      throw const MomentException('기록이 바뀌었어요. 최신 기록에서 공유할 사진을 다시 선택해 주세요.');
    }
    authorized = {for (final photo in current.photos) photo.id: photo};
  }

  try {
    final exporter = scope.read(momentPhotoShareExporterProvider);
    await showFeedShareSheet(
      context,
      title: '${momentDateLabel(snapshot.recordDate)} 기록 공유',
      caption: snapshot.caption,
      initialPhotoId: initialPhotoId,
      note: '사진만 공유해요. 기록의 공개 범위는 바뀌지 않아요.',
      isActive: active,
      validate: validate,
      photos: [
        for (final photo in snapshot.photos)
          FeedSharePhoto(
            id: photo.id,
            preview: (_) => MomentPhotoView(
              photo: photo,
              imageDecodeWidth: 160,
              fit: BoxFit.contain,
              label: '${momentDateLabel(snapshot.recordDate)} 공유할 사진',
            ),
            render: (theme, selectedActive) async {
              bool current() => active() && selectedActive();
              if (!current()) throw const MomentShareExportCancelled();
              if (authorized.isEmpty) await validate();
              final selected = authorized[photo.id];
              if (selected == null || !current()) {
                throw const MomentShareExportCancelled();
              }
              final image = await exporter.export(
                photo: selected,
                theme: theme,
                isActive: current,
              );
              if (!current()) throw const MomentShareExportCancelled();
              return image.bytes;
            },
          ),
      ],
    );
  } on MomentShareExportCancelled {
    // Account changes and closing the sheet are cancellation, not a failure.
  } catch (_) {
    if (active()) {
      context.showSnack('공유할 사진을 준비하지 못했어요. 다시 시도해 주세요.');
    }
  } finally {
    if (_activeShares[scope] == token) _activeShares[scope] = null;
    await session.cancel();
  }
}

bool _sameRecord(MomentRecord before, MomentRecord after) {
  if (before.id != after.id ||
      before.revision != after.revision ||
      before.caption != after.caption ||
      momentDate(before.recordDate) != momentDate(after.recordDate) ||
      before.photos.length != after.photos.length)
    return false;
  for (var i = 0; i < before.photos.length; i++) {
    final a = before.photos[i], b = after.photos[i];
    if (a.id != b.id ||
        a.path != b.path ||
        a.width != b.width ||
        a.height != b.height ||
        !_sameJson(a.design?.toJson(), b.design?.toJson())) {
      return false;
    }
  }
  // Signed URL renewal is not a content change and must not block sharing.
  return true;
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
