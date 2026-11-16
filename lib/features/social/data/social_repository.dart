import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/social_models.dart';
import 'social_profile_photo.dart';
import '../../moments/domain/moment_record.dart';

class SocialActionException implements Exception {
  const SocialActionException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

String socialActionMessage(Object error, {required String fallback}) =>
    error is SocialActionException ? error.message : fallback;

class SocialRepository {
  SocialRepository(
    this.client, {
    this.readTimeout = const Duration(seconds: 25),
  });
  final SupabaseClient client;
  final Duration readTimeout;
  static const snapshotBucket = 'social-snapshots';
  static const profilePhotoBucket = 'social-profile-photos';
  // The app requests short-lived signed links. Already downloaded copies cannot
  // be revoked. Callers must not persist URLs or cache them beyond this TTL.
  static const snapshotUrlLifetimeSeconds = 60;

  // Bound the complete page read, including optional avatar signing and legacy
  // snapshot links. Keep writes outside this deadline: a local timeout cannot
  // establish whether the server committed a follow, purchase or publication.
  Future<T> _read<T>(Future<T> Function() read) => read().timeout(readTimeout);

  String _requireUser() {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('로그인이 필요해요.');
    return id;
  }

  Future<dynamic> _request(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final owner = client.auth.currentUser?.id;
    final dynamic result;
    try {
      result = await client.rpc(
        'social_api',
        params: {'p_action': action, 'p_payload': payload},
      );
    } on PostgrestException catch (error) {
      final message = switch (error.message) {
        'social_rate_limited' => '잠시 쉬었다가 다시 시도해 주세요. 요청이 너무 자주 들어왔어요.',
        'social_public_snapshot_quota_exceeded' =>
          '공개할 수 있는 사진 용량을 넘었어요. 기존 공개 기록을 정리한 뒤 다시 시도해 주세요. 나의 기록은 그대로 저장돼요.',
        'social_publication_restricted' =>
          '운영 검토로 공개와 소통이 제한돼 있어요. 나의 기록은 계속 작성할 수 있어요.',
        'social_report_changed' => '다른 관리자가 먼저 처리했어요. 목록을 새로 확인해 주세요.',
        'social_comment_parent_unavailable' =>
          '답글을 달 댓글을 찾을 수 없어요. 댓글 목록을 새로 확인해 주세요.',
        'social_comment_mentions_limit' => '한 댓글에서는 최대 5명까지 언급할 수 있어요.',
        'social_invalid_month_cover' => '이달에 공개한 사진에서 표지를 다시 골라 주세요.',
        _ => null,
      };
      if (message != null)
        throw SocialActionException(message, code: error.message);
      rethrow;
    }
    if (owner != client.auth.currentUser?.id) {
      throw StateError('계정이 변경되었어요. 다시 열어주세요.');
    }
    final hydrated = await _hydratePublicPhotos(result);
    if (owner != client.auth.currentUser?.id) {
      throw StateError('계정이 변경되었어요. 다시 열어주세요.');
    }
    return hydrated;
  }

  Future<dynamic> _hydratePublicPhotos(dynamic value) async {
    final profiles = <Map<String, dynamic>>[];
    dynamic copy(dynamic node) {
      if (node is List) return node.map(copy).toList();
      if (node is! Map) return node;
      final data = <String, dynamic>{
        for (final entry in node.entries)
          entry.key as String: copy(entry.value),
      };
      if (data['userId'] is String && data['displayName'] is String) {
        final path = data['avatarPath'];
        if (path != null &&
            (path is! String ||
                !RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.png$').hasMatch(path) ||
                !path.startsWith('${data['userId']}/'))) {
          throw const FormatException('공개 프로필 사진 경로를 확인할 수 없어요.');
        }
        // Never accept a private account URL or an arbitrary external address.
        data['avatarUrl'] = null;
        if (path != null) profiles.add(data);
      }
      return data;
    }

    final result = copy(value);
    if (profiles.isEmpty) return result;
    final paths = profiles
        .map((profile) => profile['avatarPath'] as String)
        .toSet();
    try {
      final signed = await client.storage
          .from(profilePhotoBucket)
          .createSignedUrls(paths.toList(), snapshotUrlLifetimeSeconds);
      final urls = {
        for (final item in signed)
          if (item.signedUrl.isNotEmpty) item.path: item.signedUrl,
      };
      for (final profile in profiles) {
        profile['avatarUrl'] = urls[profile['avatarPath']];
      }
    } on StorageException {
      // A withdrawn or concurrently replaced photo falls back to initials.
    }
    return result;
  }

  Future<SocialProfile> updateOwnPhoto(Uint8List input) async {
    final owner = _requireUser();
    final png = await prepareSocialProfilePhoto(input);
    if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
    final previous = await ensureOwnProfile();
    if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
    final path = '$owner/${const Uuid().v4()}.png';
    try {
      await client.storage
          .from(profilePhotoBucket)
          .uploadBinary(
            path,
            png,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              cacheControl: '0',
              upsert: false,
            ),
          );
      if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
      final raw = await _request('setProfilePhoto', {'path': path});
      if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
      if (previous.avatarPath != null && previous.avatarPath != path) {
        await _removeUnusedPhoto(previous.avatarPath!);
      }
      return SocialProfile.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      if (client.auth.currentUser?.id == owner) await _removeUnusedPhoto(path);
      rethrow;
    }
  }

  Future<SocialProfile> removeOwnPhoto() async {
    final owner = _requireUser();
    final previous = await ensureOwnProfile();
    if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
    final raw = await _request('setProfilePhoto', {'path': null});
    if (_requireUser() != owner) throw StateError('계정이 변경되었어요.');
    if (previous.avatarPath != null)
      await _removeUnusedPhoto(previous.avatarPath!);
    return SocialProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> _removeUnusedPhoto(String path) async {
    if (!path.startsWith('${client.auth.currentUser?.id}/')) return;
    try {
      // RLS denies deletion while a public profile still references the photo,
      // including when the preceding RPC succeeded but its reply was lost.
      await client.storage.from(profilePhotoBucket).remove([path]);
    } catch (_) {
      // A cleanup retry must never turn a committed profile change into failure.
    }
  }

  Future<SocialWork> _work(dynamic raw) async {
    final owner = client.auth.currentUser?.id;
    final data = Map<String, dynamic>.from(raw as Map);
    final paths = List<String>.from(
      data.remove('imagePaths') as List? ?? const [],
    );
    // Never accept source URLs or another bucket through an API response.
    if (paths.any(
      (path) =>
          !RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9]+\.png$').hasMatch(path),
    )) {
      throw const FormatException('공개 미리보기 경로를 확인할 수 없어요.');
    }
    if (data['isRestricted'] == true) {
      final author = data['author'];
      // Only the owner's management row may describe a restricted work. Its
      // absence of images is explicit, never a tolerated token/path mismatch.
      if (owner == null ||
          author is! Map ||
          author['userId'] != owner ||
          data['mediaVersion'] != 2 ||
          paths.isNotEmpty) {
        throw const FormatException('제한된 공개본 정보를 확인할 수 없어요.');
      }
    }
    if (data['mediaVersion'] == 2) {
      final id = data['id'];
      final tokens = data.remove('mediaTokens');
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      if (id is! String ||
          !uuid.hasMatch(id) ||
          tokens is! List ||
          tokens.length != paths.length ||
          tokens.length > 20) {
        throw const FormatException('공개 사진 정보를 확인할 수 없어요.');
      }
      final base = Uri.parse(client.rest.url);
      final urls = <String>[];
      for (var index = 0; index < tokens.length; index++) {
        final row = tokens[index];
        if (row is! Map ||
            row['position'] != index ||
            row['token'] is! String ||
            !RegExp(
              r'^v1\.[0-9]{1,12}\.[0-9]{1,19}\.(?:[0-9a-f-]{36}|-)\.[0-9a-f]{64}$',
            ).hasMatch(row['token'] as String)) {
          throw const FormatException('공개 사진 정보를 확인할 수 없어요.');
        }
        urls.add(
          base
              .replace(
                path: '/functions/v1/social-media',
                queryParameters: {
                  'work': id,
                  'position': '$index',
                  'token': row['token'] as String,
                },
                fragment: '',
              )
              .toString(),
        );
      }
      data['imageUrls'] = urls;
    } else {
      // Compatibility with older API fixtures and servers. The current server
      // always issues v2 capabilities and denies direct Storage signing.
      final signed = paths.isEmpty
          ? <SignedUrl>[]
          : await client.storage
                .from(snapshotBucket)
                .createSignedUrls(paths, snapshotUrlLifetimeSeconds);
      final urls = {for (final item in signed) item.path: item.signedUrl};
      if (paths.any((path) => !urls.containsKey(path))) {
        throw StateError('공개 상태가 바뀌었어요. 기록을 다시 확인해 주세요.');
      }
      data['imageUrls'] = paths.map((path) => urls[path]!).toList();
    }
    if (owner != client.auth.currentUser?.id) {
      throw StateError('계정이 변경되었어요. 다시 열어주세요.');
    }
    return SocialWork.fromJson(data);
  }

  Future<List<SocialWork>> _works(dynamic raw) =>
      Future.wait((raw as List).map(_work));

  Future<SocialWorkPage> _workPage(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final data = Map<String, dynamic>.from(
      await _request(action, payload) as Map,
    );
    return SocialWorkPage(
      items: await _works(data['items']),
      hasMore: data['hasMore'] == true,
      nextOffset: (data['nextOffset'] as num).toInt(),
      nextCursor: data['nextCursor'] is Map
          ? Map<String, dynamic>.unmodifiable(data['nextCursor'] as Map)
          : null,
    );
  }

  Future<SocialProfilePage> _profilePage(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final data = Map<String, dynamic>.from(
      await _request(action, payload) as Map,
    );
    return SocialProfilePage(
      items: (data['items'] as List)
          .map(
            (row) =>
                SocialProfile.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      hasMore: data['hasMore'] == true,
      nextOffset: (data['nextOffset'] as num).toInt(),
    );
  }

  Future<SocialWorkPage> fetchProfileWorksPage(
    String userId, {
    int offset = 0,
    int limit = 12,
  }) => _read(
    () => _workPage('profileWorksPage', {
      'userId': userId,
      'offset': offset,
      'limit': limit,
    }),
  );

  Future<SocialWorkPage> fetchOwnWorksPage({
    String status = 'all',
    int offset = 0,
    int limit = 12,
  }) {
    _requireUser();
    return _workPage('ownWorksPage', {
      'status': status,
      'offset': offset,
      'limit': limit,
    });
  }

  Future<SocialWorkPage> fetchSavedWorksPage({int offset = 0, int limit = 12}) {
    _requireUser();
    return _workPage('savedWorksPage', {'offset': offset, 'limit': limit});
  }

  Future<SocialWorkPage> searchPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) => _workPage('searchPage', {
    'query': query.trim(),
    'offset': offset,
    'limit': limit,
  });

  Future<SocialProfilePage> searchProfilesPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) => _profilePage('searchProfilesPage', {
    'query': query.trim(),
    'offset': offset,
    'limit': limit,
  });

  Future<SocialProfilePage> fetchRelationsPage(
    String userId, {
    bool followers = true,
    int offset = 0,
    int limit = 12,
  }) => _profilePage('relationsPage', {
    'userId': userId,
    'followers': followers,
    'offset': offset,
    'limit': limit,
  });

  Future<SocialCommentPage> fetchCommentsPage(
    String workId, {
    int offset = 0,
    int limit = 12,
  }) async {
    final data = Map<String, dynamic>.from(
      await _request('commentsPage', {
            'id': workId,
            'offset': offset,
            'limit': limit,
          })
          as Map,
    );
    return SocialCommentPage(
      items: (data['items'] as List)
          .map(
            (row) =>
                SocialComment.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      hasMore: data['hasMore'] == true,
      nextOffset: (data['nextOffset'] as num).toInt(),
    );
  }

  Future<SocialWorkPage> fetchFeed({
    bool following = false,
    String? topic,
    int offset = 0,
    int limit = 12,
  }) => _read(() async {
    final data = Map<String, dynamic>.from(
      await _request('feed', {
            'following': following,
            'topic': topic,
            'offset': offset,
            'limit': limit,
          })
          as Map,
    );
    return SocialWorkPage(
      items: await _works(data['items']),
      hasMore: data['hasMore'] == true,
      nextOffset: (data['nextOffset'] as num).toInt(),
      nextCursor: data['nextCursor'] is Map
          ? Map<String, dynamic>.unmodifiable(data['nextCursor'] as Map)
          : null,
    );
  });

  Future<SocialWorkPage> fetchFeedPage(SocialFeedQuery query) {
    if (query.cursor == null)
      return fetchFeed(
        following: query.following,
        topic: query.topic,
        offset: query.offset,
        limit: query.limit,
      );
    return _read(
      () => _workPage('feed', {
        'following': query.following,
        'topic': query.topic,
        'offset': 0,
        'limit': query.limit,
        'cursor': query.cursor,
      }),
    );
  }

  Future<SocialProfile?> fetchProfile(String userId) => _read(() async {
    final raw = await _request('profile', {'userId': userId});
    return raw == null
        ? null
        : SocialProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  });

  Future<SocialProfile> ensureOwnProfile() async {
    final owner = _requireUser();
    final existing = await fetchProfile(owner);
    if (existing != null) return existing;
    // Never copy names, email addresses or avatars from private account data.
    final raw = await _request('ensureProfile');
    return SocialProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<SocialProfile> upsertOwnProfile({
    required String displayName,
    required String handle,
    required String bio,
  }) async {
    _requireUser();
    final raw = await _request('upsertProfile', {
      'displayName': displayName.trim(),
      'handle': handle.trim().toLowerCase(),
      'bio': bio.trim(),
    });
    return SocialProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<SocialProfile>> fetchRelations(
    String userId, {
    bool followers = true,
  }) async =>
      ((await _request('relations', {'userId': userId, 'followers': followers}))
              as List)
          .map(
            (row) =>
                SocialProfile.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
  Future<bool> toggleFollow(String userId) async {
    _requireUser();
    return await _request('toggleFollow', {'userId': userId}) == true;
  }

  /// Repeating a desired state is safe when a server reply is lost.
  Future<bool> setFollowing(String userId, bool following) async {
    _requireUser();
    return await _request('setFollowing', {
          'userId': userId,
          'following': following,
        }) ==
        true;
  }

  Future<void> removeFollower(String userId) async {
    _requireUser();
    await _request('removeFollower', {'userId': userId});
  }

  Future<void> setBlocked(String userId, bool value) async {
    _requireUser();
    await _request('setBlocked', {'userId': userId, 'blocked': value});
  }

  Future<List<SocialProfile>> fetchBlockedProfiles() async {
    _requireUser();
    return ((await _request('blockedProfiles')) as List)
        .map(
          (row) =>
              SocialProfile.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<SocialWork?> fetchWork(String id) async {
    final raw = await _request('work', {'id': id});
    return raw == null ? null : _work(raw);
  }

  Future<List<SocialWork>> fetchProfileWorks(String userId) async =>
      _works(await _request('profileWorks', {'userId': userId}));
  Future<List<SocialWork>> fetchOwnWorks() async {
    _requireUser();
    return _works(await _request('ownWorks'));
  }

  Future<List<SocialWork>> fetchSavedWorks() async {
    _requireUser();
    return _works(await _request('savedWorks'));
  }

  Future<List<SocialWork>> search(String query) async =>
      _works(await _request('search', {'query': query.trim()}));
  Future<List<SocialProfile>> searchProfiles(String query) async =>
      ((await _request('searchProfiles', {'query': query.trim()})) as List)
          .map(
            (row) =>
                SocialProfile.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
  Future<bool> toggleLike(String id) async {
    _requireUser();
    return await _request('toggleLike', {'id': id}) == true;
  }

  Future<bool> setLiked(String id, bool liked) async {
    _requireUser();
    return await _request('setLiked', {'id': id, 'liked': liked}) == true;
  }

  Future<bool> toggleSave(String id) async {
    _requireUser();
    return await _request('toggleSave', {'id': id}) == true;
  }

  Future<bool> setSaved(String id, bool saved) async {
    _requireUser();
    return await _request('setSaved', {'id': id, 'saved': saved}) == true;
  }

  Future<List<SocialComment>> fetchComments(String id) async =>
      ((await _request('comments', {'id': id})) as List)
          .map(
            (row) =>
                SocialComment.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
  Future<SocialComment> addComment(
    String id,
    String body, {
    String? requestId,
    String? parentCommentId,
  }) async {
    _requireUser();
    final raw = await _request('addComment', {
      'id': id,
      'body': body.trim(),
      if (requestId != null) 'requestId': requestId,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    });
    return SocialComment.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<SocialPublicationDraft> beginPublication({
    required int albumId,
    required List<int> pageIndexes,
    required String title,
    String caption = '',
    String topic = '일상',
    String? requestId,
    String? expectedUpdatedAt,
    bool includeSourceTemplate = false,
  }) async {
    _requireUser();
    final raw = await _request('beginPublication', {
      'albumId': albumId,
      'pageIndexes': pageIndexes,
      'title': title.trim(),
      'caption': caption.trim(),
      'topic': topic,
      'requestId': requestId,
      'expectedUpdatedAt': expectedUpdatedAt,
      'includeSourceTemplate': includeSourceTemplate,
    });
    return SocialPublicationDraft.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<SocialPublicationDraft> beginMomentPublication({
    required String recordId,
    required String photoId,
    required int expectedRevision,
    required String requestId,
  }) async {
    _requireUser();
    final raw = await _request('beginMomentPublication', {
      'recordId': recordId,
      'photoId': photoId,
      'expectedRevision': expectedRevision,
      'requestId': requestId,
    });
    return SocialPublicationDraft.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>?> fetchMomentPublication(String recordId) async {
    _requireUser();
    final raw = await _request('momentPublication', {'recordId': recordId});
    return raw == null ? null : Map<String, dynamic>.from(raw as Map);
  }

  Future<SocialReport> reportContent({
    required String targetKind,
    required String targetId,
    required String reason,
    String details = '',
    required String requestId,
  }) async {
    _requireUser();
    final raw = await _request('reportContent', {
      'targetKind': targetKind,
      'targetId': targetId,
      'reason': reason,
      'details': details.trim(),
      'requestId': requestId,
    });
    return SocialReport.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<SocialReportsPage> _reportsPage(
    String action,
    Map<String, dynamic> payload,
  ) async {
    _requireUser();
    final raw = Map<String, dynamic>.from(
      await _request(action, payload) as Map,
    );
    return SocialReportsPage(
      items: (raw['items'] as List)
          .map(
            (row) =>
                SocialReport.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      hasMore: raw['hasMore'] == true,
      nextOffset: (raw['nextOffset'] as num).toInt(),
    );
  }

  Future<SocialReportsPage> fetchOwnReportsPage({
    int offset = 0,
    int limit = 12,
  }) => _reportsPage('ownReportsPage', {'offset': offset, 'limit': limit});
  Future<SocialReportsPage> fetchAdminReportsPage({
    String status = 'open',
    int offset = 0,
    int limit = 12,
  }) => _reportsPage('adminReportsPage', {
    'status': status,
    'offset': offset,
    'limit': limit,
  });
  Future<SocialReport> resolveReport({
    required String id,
    required String decision,
    required int expectedRevision,
    String note = '',
  }) async {
    _requireUser();
    return SocialReport.fromJson(
      Map<String, dynamic>.from(
        await _request('resolveReport', {
              'id': id,
              'decision': decision,
              'expectedRevision': expectedRevision,
              'note': note.trim(),
            })
            as Map,
      ),
    );
  }

  Future<MomentRecord?> fetchOwnMomentRecord(String workId) async {
    _requireUser();
    final raw = await _request('ownMomentRecord', {'workId': workId});
    return raw == null
        ? null
        : MomentRecord.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> setMomentMonthCover(DateTime month, String? workId) async {
    _requireUser();
    await _request('setMomentMonthCover', {
      'month': socialMomentMonthKey(month),
      'workId': workId,
    });
  }

  Future<SocialWorkPage> fetchProfileMomentsPage(
    String userId, {
    int offset = 0,
    int limit = 12,
  }) => _read(() async {
    final raw = Map<String, dynamic>.from(
      await _request('profileMomentsPage', {
            'userId': userId,
            'offset': offset,
            'limit': limit,
          })
          as Map,
    );
    return SocialWorkPage(
      items: await _works(raw['items']),
      hasMore: raw['hasMore'] == true,
      nextOffset: (raw['nextOffset'] as num).toInt(),
    );
  });

  Future<SocialMomentMonthsPage> fetchProfileMomentMonthsPage(
    String userId, {
    int offset = 0,
    int limit = 6,
    Map<String, dynamic>? cursor,
  }) => _read(() async {
    final owner = client.auth.currentUser?.id;
    final raw = Map<String, dynamic>.from(
      await _request('profileMomentMonthsPage', {
            'userId': userId,
            'offset': offset,
            'limit': limit,
            if (cursor != null) 'cursor': cursor,
          })
          as Map,
    );
    final items = <SocialMomentMonth>[];
    for (final value in raw['items'] as List) {
      final row = Map<String, dynamic>.from(value as Map);
      final key = row['month'];
      if (key is! String ||
          !RegExp(r'^\d{4}-(0[1-9]|1[0-2])-01$').hasMatch(key)) {
        throw const FormatException('월간 기록의 날짜를 확인하지 못했어요.');
      }
      final month = DateTime.parse('${key}T00:00:00Z');
      final count = (row['recordCount'] as num).toInt();
      final cover = await _work(row['cover']);
      if (count <= 0 ||
          !cover.isMoment ||
          !cover.isPublished ||
          cover.author.userId != userId ||
          cover.recordDate == null ||
          cover.recordDate!.year != month.year ||
          cover.recordDate!.month != month.month) {
        throw const FormatException('공개된 월간 기록을 다시 확인해 주세요.');
      }
      items.add(
        SocialMomentMonth(
          month: month,
          recordCount: count,
          cover: cover,
          selectedWorkId: row['selectedWorkId'] as String?,
        ),
      );
    }
    if (owner != client.auth.currentUser?.id)
      throw StateError('계정이 변경되었어요. 다시 열어주세요.');
    return SocialMomentMonthsPage(
      items: items,
      hasMore: raw['hasMore'] == true,
      nextOffset: (raw['nextOffset'] as num).toInt(),
      nextCursor: raw['nextCursor'] is Map
          ? Map<String, dynamic>.unmodifiable(raw['nextCursor'] as Map)
          : null,
    );
  });

  Future<SocialWorkPage> fetchProfileMomentMonthPage(
    String userId,
    DateTime month, {
    int offset = 0,
    int limit = 12,
    Map<String, dynamic>? cursor,
  }) => _read(
    () => _workPage('profileMomentMonthPage', {
      'userId': userId,
      'month': socialMomentMonthKey(month),
      'offset': offset,
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    }),
  );

  Future<SocialTemplateSource?> fetchAlbumTemplateSource(int albumId) async {
    _requireUser();
    return SocialTemplateSource.tryParse(
      await _request('albumTemplateSource', {'albumId': albumId}),
    );
  }

  Future<SocialTemplateSource?> resolveWorkTemplate(String workId) async =>
      SocialTemplateSource.tryParse(
        await _request('resolveWorkTemplate', {'id': workId}),
      );

  Future<void> deleteComment(String commentId) async {
    _requireUser();
    await _request('deleteComment', {'id': commentId});
  }

  Future<void> uploadPublicationPage(
    String draftId,
    int position,
    Uint8List png,
  ) async {
    final owner = _requireUser();
    if (!isSocialPng(png))
      throw const FormatException('공개할 페이지를 PNG 이미지로 준비해 주세요.');
    final upload = Map<String, dynamic>.from(
      await _request('publicationUploadPath', {
            'id': draftId,
            'position': position,
          })
          as Map,
    );
    final path = upload['path'];
    if (path is! String || path != '$owner/$draftId/$position.png') {
      throw StateError('공개용 저장 위치를 확인할 수 없어요.');
    }
    if (upload['uploaded'] == true) return;
    await client.storage
        .from(snapshotBucket)
        .uploadBinary(
          path,
          png,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            cacheControl: '0',
            upsert: false,
          ),
        );
    if (owner != client.auth.currentUser?.id) throw StateError('계정이 변경되었어요.');
  }

  Future<SocialWork> finalizePublication(String draftId) async {
    _requireUser();
    return _work(await _request('finalizePublication', {'id': draftId}));
  }

  Future<void> setWorkVisibility(String id, bool published) async {
    _requireUser();
    await _request('visibility', {'id': id, 'published': published});
  }

  Future<void> setMomentPublicationVisibility(
    String id,
    bool published, {
    required int expectedPublicationRevision,
  }) async {
    _requireUser();
    await _request('visibility', {
      'id': id,
      'published': published,
      'expectedPublicationRevision': expectedPublicationRevision,
    });
  }

  Future<void> deleteWork(String id) async {
    _requireUser();
    await _request('deleteWork', {'id': id});
  }

  Future<bool> discardPublication(String draftId) async {
    _requireUser();
    return await _request('discardDraft', {'id': draftId}) == true;
  }

  Future<int> discardUnfinishedPublications() async {
    _requireUser();
    return (await _request('discardDrafts') as num).toInt();
  }
}
