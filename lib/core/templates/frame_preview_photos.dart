// Stable editorial preview assignments: one distinct photograph per frame.
const framePreviewPhotos = <String, String>{
  'storyVowGate':
      'assets/templates/atelier_editions_2026/velvet-vow-reading.png',
  'storyVowCotton':
      'assets/templates/atelier_editions_2026/velvet-vow-archive.png',
  'storyDiscoverySlide':
      'assets/templates/atelier_editions_2026/little-explorer-drawing.png',
  'storyDiscoveryStitch':
      'assets/templates/atelier_editions_2026/little-explorer-finds.png',
  'signatureVowPocket': 'assets/templates/atelier_editions_2026/night-vows.png',
  'signatureRailWallet': 'assets/templates/atelier_editions_2026/slow-rail.png',
  'signatureHerbariumSleeve':
      'assets/templates/atelier_editions_2026/green-hours.png',
  'signatureOrbitQuilt':
      'assets/templates/atelier_editions_2026/first-orbit.png',
  'signatureKitchenFold':
      'assets/templates/atelier_editions_2026/family-recipe-book.png',
  'signatureCinemaGate':
      'assets/templates/atelier_editions_2026/private-cinema.png',
  'signatureTrailPocket': 'assets/templates/atelier_editions_2026/walk-map.png',
  'materialLaceMount':
      'assets/templates/original_editorial/images/petal_veil.png',
  'materialLinenOval':
      'assets/templates/original_editorial/images/growth_sleep.png',
  'materialNotebookMount':
      'assets/templates/original_editorial/images/daily_book.png',
  'materialScallopMount':
      'assets/templates/original_editorial/images/petal_bouquet.png',
  'editionHeart':
      'assets/templates/original_editorial/images/couple_anniversary.png',
  'studioDiagonal': 'assets/frame_preview/desert_walk.jpg',
  'studioGallery': 'assets/frame_preview/alpine_lake.jpg',
  'studioArch': 'assets/frame_preview/forest_trail.jpg',
  'circle': 'assets/templates/original_editorial/images/pet_cat.png',
  'heartFrame': 'assets/templates/original_editorial/images/couple_walk.png',
  'sketch': 'assets/frame_preview/artist_palette.jpg',
  'win95': 'assets/frame_preview/studio_laptop.jpg',
  'pixel8': 'assets/frame_preview/city_skyline.jpg',
  'vhs': 'assets/frame_preview/concert_lights.jpg',
  'neon': 'assets/frame_preview/night_city.jpg',
  'floatingGlass': 'assets/frame_preview/misty_hills.jpg',
  'atelierCoastline': 'assets/frame_preview/ocean_shore.jpg',
  'materialTwinWindow':
      'assets/templates/original_editorial/images/daily_desk.png',
  'materialSlideMount':
      'assets/templates/original_editorial/images/journey_market.png',
  'zineContact': 'assets/templates/original_editorial/images/couple_cafe.png',
  'zineDeckle': 'assets/templates/original_editorial/images/daily_friends.png',
  'zineTab': 'assets/templates/original_editorial/images/daily_fruit.png',
  'editionLace': 'assets/templates/original_editorial/images/petal_couple.png',
  'editionPostage':
      'assets/templates/original_editorial/images/journey_train.png',
  'editionScallop':
      'assets/templates/original_editorial/images/petal_details.png',
  'editionCameo':
      'assets/templates/original_editorial/images/petal_evening.png',
  'editionTriptych':
      'assets/templates/original_editorial/images/daily_picnic.png',
  'studyArchWindow':
      'assets/templates/original_editorial/images/couple_keepsakes.png',
  'studyFloatMount':
      'assets/templates/original_editorial/images/family_friends.png',
  'studyNotchedMat':
      'assets/templates/original_editorial/images/lightbound_ceremony.png',
  'studioDoubleMat':
      'assets/templates/original_editorial/images/family_kitchen.png',
  'studioPhotoCorners':
      'assets/templates/original_editorial/images/petal_table.png',
  'studioOvalMat':
      'assets/templates/family_weekend/images/sources/ceremony_moment.png',
  'studioLinen': 'assets/templates/original_editorial/images/family_picnic.png',
  'studioPostcard':
      'assets/templates/original_editorial/images/travel_cafe.png',
  'studioPostage':
      'assets/templates/original_editorial/images/travel_coast.png',
  'studioCapsule':
      'assets/templates/original_editorial/images/family_table.png',
  'studioWave': 'assets/templates/original_editorial/images/pet_dog.png',
  'studioTicket':
      'assets/templates/original_editorial/images/travel_harbor.png',
  'studioDeckle':
      'assets/templates/original_editorial/images/pet_keepsakes.png',
  'studioInstant':
      'assets/templates/original_editorial/images/lightbound_guests.png',
  'studioFilm': 'assets/templates/original_editorial/images/travel_street.png',
  'studioOval': 'assets/templates/original_editorial/images/pet_nap.png',
  'studioRounded': 'assets/templates/original_editorial/images/pet_rest.png',
  'studioTorn': 'assets/templates/original_editorial/images/pet_walk.png',
  'studioSticker':
      'assets/templates/original_editorial/images/small_days_breakfast.png',
  'studioScallop':
      'assets/templates/family_weekend/images/sources/flower_table.png',
  'archSoft': 'assets/templates/original_editorial/images/small_days_walk.png',
  'round': 'assets/templates/original_editorial/images/growth_birthday.png',
  'polaroid': 'assets/frame_preview/mountain_light.jpg',
  'polaroidClassic':
      'assets/templates/family_weekend/images/sources/city_weekend.png',
  'polaroidWide': 'assets/templates/family_weekend/images/sources/hands_bw.png',
  'polaroidFilm':
      'assets/templates/save_the_date/images/approved_stock/closing_couple.jpg',
  'film':
      'assets/templates/jeju_travel/images/approved_stock/arrival_station.jpg',
  'vintage': 'assets/templates/original_editorial/images/growth_hand.png',
  'softGlow': 'assets/templates/original_editorial/images/growth_keepsakes.png',
  'sticker': 'assets/templates/original_editorial/images/growth_play.png',
  'crayon': 'assets/templates/original_editorial/images/growth_walk.png',
  'notebook': 'assets/templates/original_editorial/images/lightbound_cake.png',
  'tapeClip':
      'assets/templates/original_editorial/images/lightbound_twilight.png',
  'comicBubble':
      'assets/templates/anniversary_days/images/sources/anniversary_sample.png',
  'blob': 'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg',
  'ticketStub':
      'assets/templates/jeju_travel/images/approved_stock/cafe_detail.jpg',
  'thinDoubleLine':
      'assets/templates/jeju_travel/images/approved_stock/fruit_detail.jpg',
  'offsetColorBlock':
      'assets/templates/jeju_travel/images/approved_stock/guesthouse_detail.jpg',
  'gradientEdge':
      'assets/templates/jeju_travel/images/approved_stock/photo_dump.jpg',
  'tornNotebook':
      'assets/templates/jeju_travel/images/approved_stock/road_window.jpg',
  'oldNewspaper':
      'assets/templates/jeju_travel/images/approved_stock/sunset_people.jpg',
  'postalStamp': 'assets/templates/jeju_travel/images/sources/jeju_aerial.jpg',
  'kraftPaper': 'assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
  'goldFrame':
      'assets/templates/wedding_editorial/images/approved_stock/bouquet_hand.jpg',
  'pinkSplatter':
      'assets/templates/jeju_travel/images/sources/jeju_rocky_coast.jpg',
  'toxicGlow': 'assets/templates/jeju_travel/images/sources/jeju_seongsan.jpg',
  'stencilBlock': 'assets/templates/jeju_travel/images/sources/jeju_sunset.jpg',
  'midnightDrip': 'assets/frame_preview/celebration.jpg',
  'vaporStreet':
      'assets/templates/save_the_date/images/approved_stock/hands_flowers.jpg',
  'atelierDeepMat':
      'assets/templates/wedding_editorial/images/approved_stock/ribbon_detail.jpg',
  'atelierFolio':
      'assets/templates/wedding_editorial/images/approved_stock/window_shadow.jpg',
  'atelierKeyhole': 'assets/frame_preview/spring_flowers.jpg',
  'atelierCrossRibbon':
      'assets/templates/save_the_date/images/approved_stock/rings_detail.jpg',
  'atelierNegative':
      'assets/templates/save_the_date/images/approved_stock/table_detail.jpg',
  'atelierEnvelope':
      'assets/templates/soft_babybook/images/approved_stock/baby_detail.jpg',
  'atelierOxford': 'assets/frame_preview/wardrobe.jpg',
  'atelierWeave': 'assets/frame_preview/quiet_room.jpg',
  'atelierDeco':
      'assets/templates/atelier_editions_2026/little-explorer-play.png',
  'atelierAccordion':
      'assets/templates/soft_babybook/images/approved_stock/parent_back.jpg',
  'atelierCornerFold':
      'assets/templates/soft_babybook/images/approved_stock/parent_hand.jpg',
};
