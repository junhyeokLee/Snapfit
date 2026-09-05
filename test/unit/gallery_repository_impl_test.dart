import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/repositories/gallery_repository_impl.dart';

void main() {
  test('requestPermission treats limited photo access as usable', () async {
    final repository = GalleryRepositoryImpl(
      requestPermissionExtend: () async => PermissionState.limited,
    );

    final permitted = await repository.requestPermission();

    expect(permitted, isTrue);
  });
}
