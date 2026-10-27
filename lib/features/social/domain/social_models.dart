import 'dart:typed_data';

/// Deliberately separate from the private account profile and album documents.
class SocialProfile {
  const SocialProfile({
    required this.userId,
    required this.displayName,
    required this.handle,
    this.bio = '',
    this.avatarUrl,
    this.avatarPath,
    this.followersCount = 0,
    this.followingCount = 0,
    this.worksCount = 0,
    this.isFollowing = false,
  });
  final String userId, displayName, handle, bio;
  final String? avatarUrl;
  final String? avatarPath;
  final int followersCount, followingCount, worksCount;
  final bool isFollowing;
  factory SocialProfile.fromJson(Map<String, dynamic> json) => SocialProfile(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    handle: json['handle'] as String,
    bio: json['bio'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    avatarPath: json['avatarPath'] as String?,
    followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
    followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
    worksCount: (json['worksCount'] as num?)?.toInt() ?? 0,
    isFollowing: json['isFollowing'] == true,
  );
}

/// A server-verified link to a current official design. This contains no source
/// album ID, personal layers, photographs or client-supplied price.
class SocialTemplateSource {
  const SocialTemplateSource({required this.productKey, required this.title});
  final String productKey;
  final String title;

  static SocialTemplateSource? tryParse(dynamic value) {
    if (value is! Map) return null;
    final key = value['productKey'], title = value['title'];
    if (key is! String ||
        !RegExp(r'^template:[a-zA-Z0-9_-]{1,120}$').hasMatch(key) ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 200) {
      return null;
    }
    return SocialTemplateSource(productKey: key, title: title.trim());
  }
}

class SocialWork {
  const SocialWork({
    required this.id,
    required this.author,
    required this.title,
    this.caption = '',
    this.topic = '일상',
    this.imageUrls = const [],
    this.status = 'published',
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.aspectRatio = 1,
    this.sourceTemplate,
  });
  final String id, title, caption, topic, status;
  final SocialProfile author;

  /// Short-lived URLs for isolated raster snapshots, never source album assets.
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likeCount, commentCount;
  final bool isLiked, isSaved;
  final double aspectRatio;
  final SocialTemplateSource? sourceTemplate;
  bool get isPublished => status == 'published';
  bool get allowsStyleImport => false;
  factory SocialWork.fromJson(Map<String, dynamic> json) => SocialWork(
    id: json['id'] as String,
    author: SocialProfile.fromJson(
      Map<String, dynamic>.from(json['author'] as Map),
    ),
    title: json['title'] as String,
    caption: json['caption'] as String? ?? '',
    topic: json['topic'] as String? ?? '일상',
    status: json['status'] as String? ?? 'published',
    imageUrls: List<String>.from(json['imageUrls'] as List? ?? const []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    isLiked: json['isLiked'] == true,
    isSaved: json['isSaved'] == true,
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1,
    sourceTemplate: json['status'] == null || json['status'] == 'published'
        ? SocialTemplateSource.tryParse(json['sourceTemplate'])
        : null,
  );
}

class SocialWorkPage {
  const SocialWorkPage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });
  final List<SocialWork> items;
  final bool hasMore;
  final int nextOffset;
}

class SocialProfilePage {
  const SocialProfilePage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });
  final List<SocialProfile> items;
  final bool hasMore;
  final int nextOffset;
}

class SocialCommentPage {
  const SocialCommentPage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });
  final List<SocialComment> items;
  final bool hasMore;
  final int nextOffset;
}

class SocialPageQuery {
  const SocialPageQuery({this.offset = 0, this.limit = 12, this.ownerId});
  final int offset, limit;
  // Private saved collections must not reuse another account's cached page.
  final String? ownerId;
  @override
  bool operator ==(Object other) =>
      other is SocialPageQuery &&
      offset == other.offset &&
      limit == other.limit &&
      ownerId == other.ownerId;
  @override
  int get hashCode => Object.hash(offset, limit, ownerId);
}

class SocialOwnWorksQuery {
  const SocialOwnWorksQuery({
    this.status = 'all',
    this.offset = 0,
    this.limit = 12,
  });
  final String status;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialOwnWorksQuery &&
      status == other.status &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(status, offset, limit);
}

class SocialSearchQuery {
  const SocialSearchQuery(this.query, {this.offset = 0, this.limit = 12});
  final String query;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialSearchQuery &&
      query == other.query &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(query, offset, limit);
}

class SocialProfileWorksQuery {
  const SocialProfileWorksQuery(
    this.userId, {
    this.offset = 0,
    this.limit = 12,
  });
  final String userId;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialProfileWorksQuery &&
      userId == other.userId &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(userId, offset, limit);
}

class SocialCommentsQuery {
  const SocialCommentsQuery(this.workId, {this.offset = 0, this.limit = 12});
  final String workId;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialCommentsQuery &&
      workId == other.workId &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(workId, offset, limit);
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });
  final String id, body;
  final SocialProfile author;
  final DateTime createdAt;
  factory SocialComment.fromJson(Map<String, dynamic> json) => SocialComment(
    id: json['id'] as String,
    body: json['body'] as String,
    author: SocialProfile.fromJson(
      Map<String, dynamic>.from(json['author'] as Map),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class SocialPublicationDraft {
  const SocialPublicationDraft({
    required this.id,
    required this.pageIndexes,
    this.status = 'draft',
  });
  final String id;
  final String status;

  /// Zero-based positions in the saved document's pages array; 0 is the cover.
  final List<int> pageIndexes;
  factory SocialPublicationDraft.fromJson(Map<String, dynamic> json) =>
      SocialPublicationDraft(
        id: json['id'] as String,
        pageIndexes: List<int>.from(json['pageIndexes'] as List),
        status: json['status'] as String? ?? 'draft',
      );
}

class SocialFeedQuery {
  const SocialFeedQuery({
    this.following = false,
    this.topic,
    this.offset = 0,
    this.limit = 12,
  });
  final bool following;
  final String? topic;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialFeedQuery &&
      following == other.following &&
      topic == other.topic &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(following, topic, offset, limit);
}

class SocialRelationsQuery {
  const SocialRelationsQuery(
    this.userId, {
    this.followers = true,
    this.offset = 0,
    this.limit = 12,
  });
  final String userId;
  final bool followers;
  final int offset, limit;
  @override
  bool operator ==(Object other) =>
      other is SocialRelationsQuery &&
      userId == other.userId &&
      followers == other.followers &&
      offset == other.offset &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(userId, followers, offset, limit);
}

/// Rejects documents/URLs and non-raster input before any network request.
bool isSocialPng(Uint8List bytes) {
  if (bytes.length < 24 ||
      bytes.length > 8 * 1024 * 1024 ||
      List.generate(8, (i) => bytes[i]).join(',') != '137,80,78,71,13,10,26,10')
    return false;
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(16), height = header.getUint32(20);
  return width > 0 &&
      height > 0 &&
      width <= 8000 &&
      height <= 8000 &&
      width * height <= 32000000;
}
