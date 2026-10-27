import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api/album_provider.dart';
import '../../domain/entities/album.dart';
import '../../printing/print_album_document.dart';
import '../../../social/data/social_album_snapshot.dart';

enum AlbumSavedReason { saved, firstSave, completed }

/// Ordinary saves remain a lightweight confirmation. A newly created book or
/// the first transition to authored completion deserves a larger result.
bool shouldCelebrateAlbumSave({
  required bool creationFlow,
  required bool previouslyComplete,
  required bool nowComplete,
  required bool returnToPrevious,
}) =>
    !returnToPrevious && (creationFlow || (!previouslyComplete && nowComplete));

typedef SavedAlbumLoader = Future<Album> Function(int albumId);
final savedAlbumLoaderProvider = Provider<SavedAlbumLoader>((ref) {
  final repository = ref.watch(albumRepositoryProvider);
  return (id) => repository.fetchAlbum('$id');
});

typedef SavedAlbumPageRenderer =
    Future<Uint8List> Function(PrintAlbumPage page, ThemeData theme);
final savedAlbumPageRendererProvider = Provider<SavedAlbumPageRenderer>((ref) {
  final renderer = SocialSnapshotRenderer();
  return (page, theme) async {
    // Prepare only the explicitly selected page, never every private page.
    await renderer.prepareFonts([page]);
    return renderer.renderPage(page, theme: theme);
  };
});

typedef SavedAlbumImageWriter =
    Future<void> Function(Uint8List bytes, String name, Rect? origin);
final savedAlbumImageWriterProvider = Provider<SavedAlbumImageWriter>((ref) {
  return (bytes, name, origin) async {
    // share_plus uses the native sheet and Web Share when supported, and a
    // browser download fallback elsewhere. No image is uploaded to a server.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [name],
        downloadFallbackEnabled: true,
        sharePositionOrigin: origin,
      ),
    );
  };
});

String savedAlbumPageFileName(int albumId, int pageIndex) =>
    'snapfit-album-$albumId-${pageIndex == 0 ? 'cover' : 'page-$pageIndex'}.png';

/// A refreshed revision may contain a different photograph in the same array
/// position. Require another explicit selection instead of exporting it.
bool isSameSavedAlbumRevision(Album shown, Album fresh) =>
    shown.id == fresh.id &&
    shown.userId == fresh.userId &&
    shown.updatedAt == fresh.updatedAt &&
    shown.ratio == fresh.ratio &&
    shown.coverTheme == fresh.coverTheme &&
    shown.coverLayersJson == fresh.coverLayersJson;
