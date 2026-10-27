import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/utils/saved_album_experience.dart';

void main() {
  test(
    'ordinary saves and reader return do not force another result screen',
    () {
      expect(
        shouldCelebrateAlbumSave(
          creationFlow: false,
          previouslyComplete: true,
          nowComplete: true,
          returnToPrevious: false,
        ),
        isFalse,
      );
      expect(
        shouldCelebrateAlbumSave(
          creationFlow: false,
          previouslyComplete: false,
          nowComplete: false,
          returnToPrevious: false,
        ),
        isFalse,
      );
      expect(
        shouldCelebrateAlbumSave(
          creationFlow: true,
          previouslyComplete: false,
          nowComplete: true,
          returnToPrevious: true,
        ),
        isFalse,
      );
    },
  );

  test('new-book save and first authored completion have a result', () {
    expect(
      shouldCelebrateAlbumSave(
        creationFlow: true,
        previouslyComplete: false,
        nowComplete: false,
        returnToPrevious: false,
      ),
      isTrue,
    );
    expect(
      shouldCelebrateAlbumSave(
        creationFlow: false,
        previouslyComplete: false,
        nowComplete: true,
        returnToPrevious: false,
      ),
      isTrue,
    );
  });

  test(
    'same array position in another revision cannot be exported silently',
    () {
      const shown = Album(
        id: 5,
        userId: 'owner',
        updatedAt: 'revision-1',
        coverLayersJson: '{saved}',
      );
      expect(isSameSavedAlbumRevision(shown, shown), isTrue);
      expect(
        isSameSavedAlbumRevision(
          shown,
          shown.copyWith(updatedAt: 'revision-2'),
        ),
        isFalse,
      );
      expect(
        isSameSavedAlbumRevision(
          shown,
          shown.copyWith(coverLayersJson: '{changed}'),
        ),
        isFalse,
      );
      expect(
        isSameSavedAlbumRevision(shown, shown.copyWith(userId: 'other')),
        isFalse,
      );
      expect(isSameSavedAlbumRevision(shown, shown.copyWith(id: 6)), isFalse);
    },
  );

  test('export names contain only stable album/page IDs', () {
    expect(savedAlbumPageFileName(5, 0), 'snapfit-album-5-cover.png');
    expect(savedAlbumPageFileName(5, 2), 'snapfit-album-5-page-2.png');
  });
}
