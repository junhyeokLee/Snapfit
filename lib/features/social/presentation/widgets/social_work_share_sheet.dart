import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/sharing/feed_share_sheet.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/printing/print_album_document.dart';
import '../../../album/printing/print_image_header.dart';
import '../../data/social_album_snapshot.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import 'social_snapshot_identity.dart';
import 'social_widgets.dart';

const _publicWebsite = String.fromEnvironment(
  'PUBLIC_WEBSITE_URL',
  defaultValue: 'https://snapfit-c719d.web.app/',
);

/// Links expose a public route identifier, never a snapshot capability URL.
Uri? publicSocialWorkShareUri(SocialWork work) {
  if (!work.isPublished ||
      work.isRestricted ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(work.id)) {
    return null;
  }
  final base = Uri.tryParse(_publicWebsite);
  if (base == null || base.scheme != 'https' || base.host.isEmpty) return null;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path.isEmpty ? '/' : base.path,
    fragment: WebAppLocation.socialWork(work.id).uri.toString(),
  );
}

/// Capability renewal can change the token, while changed content cannot reuse
/// an already prepared share. Reactions and author display names are unrelated.
String _shareSnapshotIdentity(String source) {
  final uri = Uri.tryParse(source);
  if (uri?.path == '/functions/v1/social-media') {
    // Gateway URLs keep work/position stable when an album is republished.
    // Their signed token also carries a media epoch: ignore expiry/MAC renewal
    // but retain that epoch, including for albums without publicationRevision.
    final token = uri!.queryParameters['token'] ?? '';
    final match = RegExp(
      r'^v1\.[0-9]{1,12}\.([0-9]{1,19})\.(?:[0-9a-f-]{36}|-)\.[0-9a-f]{64}$',
    ).firstMatch(token);
    return match == null
        ? source
        : '${socialSnapshotIdentity(source)}|epoch:${match.group(1)}';
  }
  return socialSnapshotIdentity(source);
}

bool sameSocialWorkShareSnapshot(SocialWork expected, SocialWork? current) =>
    current != null &&
    expected.isPublished &&
    !expected.isRestricted &&
    current.isPublished &&
    !current.isRestricted &&
    expected.id == current.id &&
    expected.author.userId == current.author.userId &&
    expected.kind == current.kind &&
    expected.title == current.title &&
    expected.caption == current.caption &&
    expected.publicationRevision == current.publicationRevision &&
    expected.aspectRatio == current.aspectRatio &&
    listEquals(
      expected.imageUrls.map(_shareSnapshotIdentity).toList(),
      current.imageUrls.map(_shareSnapshotIdentity).toList(),
    );

typedef SocialWorkShareRasterizer =
    Future<Uint8List> Function(
      PrintAlbumPage page,
      ThemeData theme,
      SocialSnapshotLoader loader,
    );

Future<Uint8List> _loadSnapshot(String source) async {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('공개 이미지를 다시 확인해 주세요.');
  }
  final response = await Dio()
      .get<List<int>>(
        source,
        options: Options(responseType: ResponseType.bytes),
      )
      .timeout(const Duration(seconds: 30));
  final data = response.data;
  if (data == null || data.isEmpty || data.length > 8 * 1024 * 1024) {
    throw const FormatException('공개 이미지를 불러오지 못했어요. 다시 시도해 주세요.');
  }
  return Uint8List.fromList(data);
}

Future<Uint8List> _rasterize(
  PrintAlbumPage page,
  ThemeData theme,
  SocialSnapshotLoader loader,
) => SocialSnapshotRenderer(
  loader: loader,
).renderPage(page, theme: theme, watermark: true);

final socialWorkShareSnapshotLoaderProvider = Provider<SocialSnapshotLoader>(
  (_) => _loadSnapshot,
);
final socialWorkShareRasterizerProvider = Provider<SocialWorkShareRasterizer>(
  (_) => _rasterize,
);

/// One explicit share operation. Only the selected, already public raster is
/// loaded; the source album document and its private media are never requested.
class SocialWorkShareSession {
  SocialWorkShareSession({
    required this.work,
    required this.actorId,
    required this.fetchWork,
    required this.isActive,
    SocialSnapshotLoader? loader,
    SocialWorkShareRasterizer? rasterizer,
  }) : _loader = loader ?? _loadSnapshot,
       _rasterizer = rasterizer ?? _rasterize,
       _current = work;

  final SocialWork work;
  final String? actorId;
  final Future<SocialWork?> Function() fetchWork;
  final bool Function() isActive;
  final SocialSnapshotLoader _loader;
  final SocialWorkShareRasterizer _rasterizer;
  SocialWork _current;

  bool get canExportImage =>
      work.isPublished &&
      !work.isRestricted &&
      actorId != null &&
      actorId == work.author.userId;

  void _requireActive() {
    if (!isActive()) throw StateError('share_session_changed');
  }

  Future<void> validate() async {
    _requireActive();
    final fresh = await fetchWork();
    _requireActive();
    if (!sameSocialWorkShareSnapshot(work, fresh)) {
      throw const FormatException('공개 상태나 내용이 바뀌었어요. 피드를 다시 열어 주세요.');
    }
    _current = fresh!;
  }

  String photoId(int index) => '${work.id}-$index';

  List<FeedSharePhoto> get photos => !canExportImage
      ? const []
      : [
          for (var index = 0; index < work.imageUrls.length; index++)
            FeedSharePhoto(
              id: photoId(index),
              preview: (_) => SocialWorkImage(
                url: _current.imageUrls[index],
                imageDecodeWidth: 160,
                label: '${work.title} ${index + 1}번째 공개 이미지',
              ),
              render: (theme, active) => render(index, theme, active),
            ),
        ];

  Future<Uint8List> render(
    int index,
    ThemeData theme,
    bool Function() sheetIsActive,
  ) async {
    void current() {
      _requireActive();
      if (!sheetIsActive()) throw StateError('share_sheet_closed');
    }

    current();
    if (!canExportImage || index < 0 || index >= _current.imageUrls.length) {
      throw const FormatException('공유할 공개 이미지를 선택해 주세요.');
    }
    final source = _current.imageUrls[index];
    final encoded = await _loader(source);
    current();
    if (encoded.isEmpty || encoded.length > 8 * 1024 * 1024) {
      throw const FormatException('공개 이미지를 불러오지 못했어요.');
    }
    final size = printEncodedImageSize(encoded);
    if (size.width * size.height > 40000000) {
      throw const FormatException('이미지가 너무 커요. 다른 이미지를 선택해 주세요.');
    }
    final page = PrintAlbumPage(
      index: 0,
      isCover: false,
      canvasSize: size,
      backgroundColor: Colors.transparent,
      layers: [
        LayerModel(
          id: 'public-share-image',
          type: LayerType.image,
          position: Offset.zero,
          width: size.width,
          height: size.height,
          imageTemplate: 'free',
          originalUrl: source,
          previewUrl: source,
          imageUrl: source,
        ),
      ],
    );
    final png = await _rasterizer(page, theme, (requested) async {
      current();
      if (requested != source) throw StateError('unexpected_share_source');
      return encoded;
    });
    current();
    if (png.length < 8 ||
        png.length > 8 * 1024 * 1024 ||
        !listEquals(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10])) {
      throw const FormatException('공유 이미지를 준비하지 못했어요. 다시 시도해 주세요.');
    }
    return png;
  }
}

Future<void> showSocialWorkShareSheet(
  BuildContext context, {
  required SocialWork work,
  required bool Function() isActive,
  int initialPage = 0,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repository = container.read(socialRepositoryProvider);
  final actor = container.read(socialCurrentUserIdProvider);
  var sessionChanged = false;
  var finished = false;
  final subscription = container.listen<String?>(socialCurrentUserIdProvider, (
    previous,
    next,
  ) {
    if (previous != next) sessionChanged = true;
  });
  // Auth stream events are not coalesced by a provider rebuild. In particular,
  // A -> B -> A during one awaited operation must permanently cancel this share.
  final auth = repository.client.auth.onAuthStateChange.listen((event) {
    if (event.session?.user.id != actor) sessionChanged = true;
  }, onError: (Object _, StackTrace __) => sessionChanged = true);
  bool current() {
    if (finished || sessionChanged || !context.mounted) return false;
    try {
      return isActive() &&
          container.read(socialCurrentUserIdProvider) == actor &&
          repository.client.auth.currentUser?.id == actor;
    } catch (_) {
      return false;
    }
  }

  final session = SocialWorkShareSession(
    work: work,
    actorId: actor,
    fetchWork: () => repository.fetchWork(work.id),
    isActive: current,
    loader: container.read(socialWorkShareSnapshotLoaderProvider),
    rasterizer: container.read(socialWorkShareRasterizerProvider),
  );
  try {
    await session.validate();
    if (!current()) return;
    final photos = session.photos;
    await showFeedShareSheet(
      context,
      title: work.title,
      caption: work.caption,
      photos: photos,
      initialPhotoId: photos.isEmpty
          ? null
          : session.photoId(initialPage.clamp(0, photos.length - 1)),
      publicUri: publicSocialWorkShareUri(work),
      note: session.canExportImage
          ? '공개한 이미지 한 장을 공유해요. 캡션은 따로 복사할 수 있어요.'
          : '공개 피드 링크와 캡션을 공유할 수 있어요.',
      validate: session.validate,
      isActive: current,
    );
  } catch (error) {
    if (current()) {
      socialError(
        context,
        message: error is FormatException
            ? error.message
            : '공유할 피드를 확인하지 못했어요. 다시 시도해 주세요.',
      );
    }
  } finally {
    finished = true;
    subscription.close();
    await auth.cancel();
  }
}
