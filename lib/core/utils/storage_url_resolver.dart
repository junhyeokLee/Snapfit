import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageUri {
  final String bucket;
  final String path;

  const SupabaseStorageUri({required this.bucket, required this.path});
}

SupabaseStorageUri? parseSupabaseStorageUri(String value) {
  const prefix = 'supabase://';
  if (!value.startsWith(prefix)) return null;

  final raw = value.substring(prefix.length);
  final slash = raw.indexOf('/');
  if (slash <= 0 || slash == raw.length - 1) return null;

  final bucket = raw.substring(0, slash).trim();
  final path = raw.substring(slash + 1).trim();
  if (bucket.isEmpty || path.isEmpty) return null;

  return SupabaseStorageUri(bucket: bucket, path: path);
}

/// Only this project's persisted album URLs are aliases for private objects.
/// External images and another project's URLs keep their original meaning.
SupabaseStorageUri? parseLegacyAlbumAssetUrl(
  String value, {
  required String storageBaseUrl,
}) {
  final source = Uri.tryParse(value);
  final base = Uri.tryParse(storageBaseUrl);
  if (source == null ||
      base == null ||
      source.scheme != base.scheme ||
      source.host != base.host ||
      source.port != base.port ||
      source.userInfo.isNotEmpty)
    return null;
  final prefix = '${base.path.replaceFirst(RegExp(r'/+$'), '')}/object/';
  if (!source.path.startsWith(prefix)) return null;
  final parts = source.path.substring(prefix.length).split('/');
  if (parts.length < 3 ||
      !const ['public', 'sign', 'authenticated'].contains(parts.first) ||
      parts[1] != 'album-assets')
    return null;
  final path = parts.skip(2).join('/');
  if (path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..') ||
      path.contains('\\'))
    return null;
  return SupabaseStorageUri(bucket: 'album-assets', path: path);
}

SupabaseStorageUri? privateAlbumAssetReference(
  String source, {
  SupabaseClient? supabase,
}) {
  final marker = parseSupabaseStorageUri(source);
  if (marker != null) return marker.bucket == 'album-assets' ? marker : null;
  if (!source.contains('/object/') || !source.contains('/album-assets/'))
    return null;
  try {
    return parseLegacyAlbumAssetUrl(
      source,
      storageBaseUrl: (supabase ?? Supabase.instance.client).storage.url,
    );
  } catch (_) {
    // No initialized Supabase client, e.g. an unrelated local image preview.
    return null;
  }
}

Future<String> resolveStorageImageUrl(
  String urlOrStorageUri, {
  SupabaseClient? supabase,
  int signedUrlExpiresInSeconds = 60 * 60 * 6,
}) async {
  final supabaseUri =
      parseSupabaseStorageUri(urlOrStorageUri) ??
      privateAlbumAssetReference(urlOrStorageUri, supabase: supabase);
  if (supabaseUri != null) {
    final client = supabase ?? Supabase.instance.client;
    final actor = client.auth.currentUser?.id;
    final lifetime = supabaseUri.bucket == 'album-assets'
        ? signedUrlExpiresInSeconds.clamp(1, 60)
        : signedUrlExpiresInSeconds;
    final signed = await client.storage
        .from(supabaseUri.bucket)
        .createSignedUrl(supabaseUri.path, lifetime);
    if (client.auth.currentUser?.id != actor) {
      throw StateError('storage_image_account_changed');
    }
    return signed;
  }

  if (urlOrStorageUri.startsWith('gs://')) {
    final ref = FirebaseStorage.instance.refFromURL(urlOrStorageUri);
    return ref.getDownloadURL();
  }

  return urlOrStorageUri;
}

/// Resolves persisted private image references before handing them to Flutter's
/// network decoder. Bundled assets retain their existing local render path.
Future<ImageProvider> resolveStorageImageProvider(
  String source, {
  Future<String> Function(String)? resolveStorageUrl,
}) async {
  if (source.startsWith('asset:')) {
    return AssetImage(source.substring('asset:'.length));
  }
  final url = await (resolveStorageUrl ?? resolveStorageImageUrl)(source);
  return NetworkImage(url);
}
