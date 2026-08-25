import 'package:firebase_storage/firebase_storage.dart';
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

Future<String> resolveStorageImageUrl(
  String urlOrStorageUri, {
  SupabaseClient? supabase,
  int signedUrlExpiresInSeconds = 60 * 60 * 6,
}) async {
  final supabaseUri = parseSupabaseStorageUri(urlOrStorageUri);
  if (supabaseUri != null) {
    final client = supabase ?? Supabase.instance.client;
    return client.storage
        .from(supabaseUri.bucket)
        .createSignedUrl(supabaseUri.path, signedUrlExpiresInSeconds);
  }

  if (urlOrStorageUri.startsWith('gs://')) {
    final ref = FirebaseStorage.instance.refFromURL(urlOrStorageUri);
    return ref.getDownloadURL();
  }

  return urlOrStorageUri;
}
