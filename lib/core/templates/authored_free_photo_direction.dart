part of 'authored_collections.dart';

const _samplePhotoRoot = 'assets/frame_preview/';

// Sample photography is replaceable content, not a purchased decoration.
// Cover choices are independent of the photo slot order in each composition.
const _freeCoverPhotos = <FreeCollectionVolume, String>{
  FreeCollectionVolume.vows: 'lightbound_twilight.png',
  FreeCollectionVolume.garden: 'petal_bouquet.png',
  FreeCollectionVolume.cinema: 'cover_cinema_dance.png',
  FreeCollectionVolume.letters: 'petal_veil.png',
  FreeCollectionVolume.seaside: '${_samplePhotoRoot}ocean_shore.jpg',
  FreeCollectionVolume.city: '${_samplePhotoRoot}city_skyline.jpg',
  FreeCollectionVolume.walking: '${_samplePhotoRoot}misty_hills.jpg',
  FreeCollectionVolume.postcards: 'travel_street.png',
  FreeCollectionVolume.table: 'small_days_breakfast.png',
  FreeCollectionVolume.objects: '${_samplePhotoRoot}artist_palette.jpg',
  FreeCollectionVolume.together: 'cover_friends_evening.png',
  FreeCollectionVolume.weekend: 'daily_book.png',
  FreeCollectionVolume.firstYear: 'growth_sleep.png',
  FreeCollectionVolume.littleSteps: 'growth_walk.png',
  FreeCollectionVolume.babyBloom: 'growth_hand.png',
  FreeCollectionVolume.playroom: 'growth_play.png',
  FreeCollectionVolume.birthday: 'growth_birthday.png',
  FreeCollectionVolume.homeYear: 'family_kitchen.png',
  FreeCollectionVolume.familyTable: 'family_table.png',
  FreeCollectionVolume.friendsUs: 'family_friends.png',
  FreeCollectionVolume.generations: 'cover_generations_home.png',
  FreeCollectionVolume.familyOuting: 'daily_picnic.png',
  FreeCollectionVolume.usDays: 'couple_cafe.png',
  FreeCollectionVolume.dateFilm: 'couple_walk.png',
  FreeCollectionVolume.loveSeason: '${_samplePhotoRoot}spring_flowers.jpg',
  FreeCollectionVolume.anniversary: 'couple_anniversary.png',
  FreeCollectionVolume.twoTickets: 'journey_train.png',
  FreeCollectionVolume.pawDiary: 'pet_dog.png',
  FreeCollectionVolume.catNap: 'pet_cat.png',
  FreeCollectionVolume.walkClub: 'pet_walk.png',
  FreeCollectionVolume.petHome: 'pet_nap.png',
  FreeCollectionVolume.petPortrait: 'pet_rest.png',
};

// Smaller cover slots have their own photography too; a catalog hero must not
// reappear as a thumbnail on another book's cover.
const _freeCoverCompanionPhotos = <FreeCollectionVolume, String>{
  FreeCollectionVolume.objects: '${_samplePhotoRoot}studio_laptop.jpg',
  FreeCollectionVolume.littleSteps:
      'assets/templates/soft_babybook/images/approved_stock/parent_hand.jpg',
  FreeCollectionVolume.playroom:
      'assets/templates/soft_babybook/images/approved_stock/soft_clips.jpg',
  FreeCollectionVolume.familyTable: 'journey_market.png',
  FreeCollectionVolume.friendsUs: '${_samplePhotoRoot}celebration.jpg',
  FreeCollectionVolume.usDays:
      'assets/templates/jeju_travel/images/approved_stock/sunset_people.jpg',
  FreeCollectionVolume.twoTickets: 'couple_keepsakes.png',
  FreeCollectionVolume.petHome: 'pet_keepsakes.png',
};

List<String> _freeDirectedPhotos(FreeCollectionVolume volume) {
  final originals = volume == FreeCollectionVolume.city
      ? const [
          'travel_street.png',
          'travel_cafe.png',
          'journey_train.png',
          'journey_market.png',
          '${_samplePhotoRoot}quiet_room.jpg',
          '${_samplePhotoRoot}artist_palette.jpg',
        ]
      : _lifePhotos(volume) ??
            switch (volume.category) {
              '웨딩' => _weddingPhotos,
              '여행' => _travelPhotos,
              _ => _dailyPhotos,
            };
  final additional = switch (volume.category) {
    '웨딩' => const ['petal_evening.png', 'lightbound_cake.png'],
    '여행' => switch (volume) {
      FreeCollectionVolume.seaside => const [
        '${_samplePhotoRoot}ocean_shore.jpg',
        '${_samplePhotoRoot}alpine_lake.jpg',
        '${_samplePhotoRoot}mountain_light.jpg',
      ],
      FreeCollectionVolume.city => const [
        '${_samplePhotoRoot}city_skyline.jpg',
        '${_samplePhotoRoot}night_city.jpg',
        '${_samplePhotoRoot}concert_lights.jpg',
      ],
      FreeCollectionVolume.walking => const [
        '${_samplePhotoRoot}misty_hills.jpg',
        '${_samplePhotoRoot}forest_trail.jpg',
        '${_samplePhotoRoot}mountain_light.jpg',
      ],
      _ => const [
        '${_samplePhotoRoot}desert_walk.jpg',
        '${_samplePhotoRoot}ocean_shore.jpg',
        '${_samplePhotoRoot}city_skyline.jpg',
      ],
    },
    '일상' => switch (volume) {
      FreeCollectionVolume.objects => const [
        '${_samplePhotoRoot}artist_palette.jpg',
        '${_samplePhotoRoot}studio_laptop.jpg',
        '${_samplePhotoRoot}wardrobe.jpg',
      ],
      FreeCollectionVolume.together => const [
        'family_friends.png',
        'couple_cafe.png',
        '${_samplePhotoRoot}celebration.jpg',
      ],
      FreeCollectionVolume.table => const [
        'family_table.png',
        'family_kitchen.png',
        'travel_cafe.png',
      ],
      _ => const [
        '${_samplePhotoRoot}quiet_room.jpg',
        '${_samplePhotoRoot}spring_flowers.jpg',
        'travel_cafe.png',
      ],
    },
    '가족·친구' => const [
      'small_days_breakfast.png',
      'small_days_walk.png',
      'daily_fruit.png',
      'couple_keepsakes.png',
    ],
    '커플·기념일' => const [
      'petal_evening.png',
      'daily_book.png',
      'journey_train.png',
      '${_samplePhotoRoot}spring_flowers.jpg',
    ],
    '반려동물' =>
      volume == FreeCollectionVolume.catNap ||
              volume == FreeCollectionVolume.petHome
          ? const ['pet_cat.png', 'pet_nap.png', 'pet_keepsakes.png']
          : const [
              'pet_dog.png',
              'pet_rest.png',
              'pet_walk.png',
              'pet_keepsakes.png',
            ],
    _ => const <String>[],
  };
  return {
    ...originals,
    ...additional,
    if (volume.category == '반려동물') '${_samplePhotoRoot}quiet_room.jpg',
    _freeCoverPhotos[volume]!,
  }.toList();
}

String _freePhotoPath(String file) =>
    file.startsWith('assets/') ? file : '$_editorial$file';
