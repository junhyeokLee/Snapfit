import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import 'album_api.dart';

final albumApiProvider = Provider<AlbumApi>((ref) {
  final dio = ref.read(dioProvider);
  return AlbumApi(dio);
});
