import 'dart:convert';
import 'dart:io';

const _assetDir = 'assets/templates/save_the_date/images';

final _imageSources = <String, String>{
  'cover_full_bleed': 'https://www.figma.com/api/mcp/asset/9fde010a-b44a-4d02-8e64-4a4cd19af7d0',
  'p01_arch_editorial': 'https://www.figma.com/api/mcp/asset/5c78e48f-cfbf-43b9-99be-2ba4bf14665c',
  'p02_circle_card': 'https://www.figma.com/api/mcp/asset/235d2996-9a02-4764-a909-8df2ef77a631',
  'p03_strip_editorial': 'https://www.figma.com/api/mcp/asset/4fd79b87-da91-484b-a3f0-a5b3ee849ccc',
  'p10_photo_notes_left': 'https://www.figma.com/api/mcp/asset/fd893845-f6a1-4f78-9266-7cd12066a0d6',
  'p10_photo_notes_center': 'https://www.figma.com/api/mcp/asset/db83fa8f-2b18-4d2e-a47e-c19329188a11',
  'p10_photo_notes_bottom': 'https://www.figma.com/api/mcp/asset/5fc2c110-f498-4098-a04c-bbd78b43df8a',
  'p12_closing_photo': 'https://www.figma.com/api/mcp/asset/657fb709-69c5-4fb3-b790-47a7ebea17e5',
};

String _assetPath(String name) => 'asset:$_assetDir/$name.png';

String _resolveTemplateImage(String name) {
  final remote = _imageSources[name];
  if (remote == null) {
    throw ArgumentError('Unknown save_the_date image key: $name');
  }
  final localFile = File('$_assetDir/$name.png');
  if (localFile.existsSync()) {
    return _assetPath(name);
  }
  return remote;
}

final String _coverImage = _resolveTemplateImage('cover_full_bleed');
final List<String> _previewImages = <String>[
  _resolveTemplateImage('cover_full_bleed'),
  _resolveTemplateImage('p01_arch_editorial'),
  _resolveTemplateImage('p02_circle_card'),
  _resolveTemplateImage('p03_strip_editorial'),
  _resolveTemplateImage('p10_photo_notes_left'),
  _resolveTemplateImage('p10_photo_notes_center'),
  _resolveTemplateImage('p10_photo_notes_bottom'),
  _resolveTemplateImage('p12_closing_photo'),
];

void main() async {
  final handoff = _buildHandoff();
  const handoffPath = 'assets/templates/save_the_date_handoff.json';
  const storePath = 'assets/templates/generated/save_the_date_store.json';
  const storeLatestPath = 'assets/templates/generated/store_latest.json';

  await File(
    handoffPath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(handoff));

  final result = await Process.run('dart', [
    'run',
    'tool/build_store_templates_from_handoff.dart',
    '--input=$handoffPath',
    '--output=$storePath',
    '--pages=13',
    '--exact=true',
  ]);

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exit(result.exitCode);
  }

  await _syncIntoStoreLatest(
    generatedStorePath: storePath,
    storeLatestPath: storeLatestPath,
  );

  stdout.writeln('Generated save_the_date template');
  stdout.writeln('Handoff: $handoffPath');
  stdout.writeln('Store: $storePath');
  stdout.writeln('Synced: $storeLatestPath');
}

Map<String, dynamic> _buildHandoff() {
  final cover = _coverLayers();
  final pages = <Map<String, dynamic>>[
    _pageSpec(
      1,
      role: 'cover',
      layoutId: 'cover_full_bleed',
      recommendedPhotoCount: 1,
      layers: cover,
    ),
    _pageSpec(
      2,
      layoutId: 'p01_arch_editorial',
      recommendedPhotoCount: 1,
      layers: [
        _deco(
          'bg',
          0,
          0,
          1,
          1,
          'paperWarm',
          z: 0,
          fillColor: '#FFEADBCF',
        ),
        _deco(
          'arch_shell',
          0.1111,
          0.0722,
          0.7778,
          0.8194,
          'cloudSkyBlue',
          z: 2,
          radius: 0.3889,
        ),
        _text(
          'eyebrow',
          0.0833,
          0.0583,
          0.8333,
          0.0236,
          'florals, vows, and a little ocean light',
          fontSize: 26,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
        ),
        _image(
          'arch_photo',
          0.1556,
          0.1167,
          0.6889,
          0.6347,
          _previewImages[1],
          z: 8,
          frame: 'archOval',
        ),
        _deco(
          'caption_card',
          0.1296,
          0.7708,
          0.7407,
          0.1056,
          'paperWhite',
          z: 10,
          radius: 0.0259,
          borderColor: '#FFC9D2DA',
          borderWidth: 0.00093,
        ),
        _text(
          'desc',
          0.1574,
          0.7958,
          0.6852,
          0.0292,
          'A design note with a softer editorial mood.',
          fontSize: 34,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF24374A',
        ),
        _text(
          'footer',
          0.2037,
          0.8528,
          0.5926,
          0.0472,
          'Save the date for an intimate celebration\nOctober 12, 2025',
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
          lineHeight: 1.42,
        ),
      ],
    ),
    _pageSpec(
      3,
      layoutId: 'p02_circle_card',
      recommendedPhotoCount: 1,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'cloudSkyBlue', z: 0),
        _deco(
          'card',
          0.0704,
          0.0597,
          0.8593,
          0.8806,
          'paperWhiteWarm',
          z: 2,
          radius: 0.0333,
        ),
        _image(
          'circle_photo',
          0.1574,
          0.1361,
          0.6852,
          0.5139,
          _previewImages[2],
          z: 8,
          frame: 'circleRing',
        ),
        _deco(
          'caption_card',
          0.1056,
          0.6694,
          0.7889,
          0.1139,
          'paperWhite',
          z: 9,
          radius: 0.0222,
          borderColor: '#FFC9D2DA',
          borderWidth: 0.00093,
        ),
        _text(
          'desc',
          0.1407,
          0.6944,
          0.7185,
          0.0306,
          'We are getting married and would love for you to mark the date with us.',
          fontSize: 34,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF24374A',
          lineHeight: 1.29,
        ),
        _text(
          'footer',
          0.1426,
          0.8306,
          0.7148,
          0.0236,
          'Keep this card close. Formal invitation to follow.',
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
          lineHeight: 1.42,
        ),
        _deco(
          'cta_bg',
          0.3593,
          0.8903,
          0.2815,
          0.0361,
          'deepNavy',
          z: 12,
          radius: 0.0241,
        ),
        _text(
          'cta',
          0.3852,
          0.8993,
          0.2296,
          0.0167,
          'SAVE THIS WEEKEND',
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FFF7F1E8',
          letterSpacing: 1.8,
        ),
      ],
    ),
    _pageSpec(
      4,
      layoutId: 'p03_strip_editorial',
      recommendedPhotoCount: 1,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhiteWarm', z: 0),
        _text(
          'date',
          0.09,
          0.07,
          0.36,
          0.07,
          'OCT 12',
          fontSize: 74,
          fontFamily: 'Inter',
          fontWeight: 9,
          color: '#FF24374A',
          align: 'left',
          letterSpacing: 1.0,
        ),
        _text(
          'desc',
          0.09,
          0.17,
          0.76,
          0.06,
          'A quiet gathering, a long table, and a soft aisle framed in\nflowers.',
          fontSize: 20,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
          align: 'left',
          lineHeight: 1.3,
        ),
        _image('main_photo', 0.09, 0.31, 0.82, 0.31, _previewImages[3], z: 10),
        _text(
          'venue_label',
          0.09,
          0.68,
          0.16,
          0.02,
          'Venue',
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF6E7A86',
          align: 'left',
          letterSpacing: 1.3,
        ),
        _text(
          'venue_value',
          0.09,
          0.72,
          0.40,
          0.07,
          'Garden House, Seoul\nForest',
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
          align: 'left',
          lineHeight: 1.18,
        ),
        _text(
          'time_label',
          0.54,
          0.68,
          0.12,
          0.02,
          'Time',
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF6E7A86',
          align: 'left',
          letterSpacing: 1.3,
        ),
        _text(
          'time_value',
          0.54,
          0.72,
          0.24,
          0.04,
          '2:00 PM',
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
          align: 'left',
        ),
        _text(
          'footer',
          0.09,
          0.86,
          0.74,
          0.03,
          'Dinner and celebration continue until sunset.',
          fontSize: 18,
          fontFamily: 'Inter',
          color: '#FF6E7A86',
          align: 'left',
        ),
      ],
    ),
    _pageSpec(
      5,
      layoutId: 'p04_type_invitation',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhiteWarm', z: 0),
        _deco(
          'border_frame',
          0.0537,
          0.0403,
          0.8926,
          0.9194,
          'paperWhiteWarm',
          z: 1,
          radius: 0.035,
        ),
        _deco('line_top', 0.1481, 0.1472, 0.7037, 0.0014, 'minimalGray', z: 3),
        _deco(
          'line_bottom',
          0.1481,
          0.8042,
          0.7037,
          0.0014,
          'minimalGray',
          z: 3,
        ),
        _text(
          'eyebrow',
          0.1481,
          0.1014,
          0.7037,
          0.0153,
          'INVITATION PREVIEW',
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF6E7A86',
          align: 'center',
          letterSpacing: 1.5,
        ),
        _text(
          'title',
          0.1481,
          0.2208,
          0.7037,
          0.1833,
          'Save the date for a wedding weekend full of quiet joy, old songs, good food, and the people who feel like home.',
          fontSize: 54,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          align: 'left',
          lineHeight: 1.12,
        ),
        _text(
          'names',
          0.2593,
          0.5583,
          0.4815,
          0.1333,
          'JULIA KIM\nand\nMINHO PARK',
          fontSize: 42,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          lineHeight: 1.12,
        ),
        _text(
          'footer',
          0.1481,
          0.8542,
          0.7037,
          0.025,
          'Formal invitation and RSVP details will arrive soon.',
          fontSize: 20,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
          align: 'center',
        ),
      ],
    ),
    _pageSpec(
      6,
      layoutId: 'p05_detail_grid',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhiteWarm', z: 0),
        _text(
          'eyebrow',
          0.0833,
          0.0653,
          0.8333,
          0.0236,
          'WEDDING DETAILS',
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF6E7A86',
          align: 'left',
          letterSpacing: 1.8,
        ),
        _text(
          'title',
          0.0833,
          0.1111,
          0.8333,
          0.0417,
          'Everything you need for the day',
          fontSize: 46,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          align: 'left',
        ),
        ..._detailCard(
          'ceremony',
          0.0833,
          0.2222,
          'Ceremony',
          '2:00 PM\nGarden House',
        ),
        ..._detailCard('dinner', 0.5278, 0.2222, 'Dinner', '5:30 PM\nBlue Hall'),
        ..._detailCard(
          'dress',
          0.0833,
          0.4111,
          'Dress',
          'Soft formal\nMuted tones welcome',
        ),
        ..._detailCard(
          'parking',
          0.5278,
          0.4111,
          'Parking',
          'Valet available\nEntrance B',
        ),
        ..._detailCard(
          'children',
          0.0833,
          0.6000,
          'Children',
          'A family room is prepared',
        ),
        ..._detailCard(
          'gift',
          0.5278,
          0.6000,
          'Gift note',
          'Your presence means the most',
        ),
      ],
    ),
    _pageSpec(
      7,
      layoutId: 'p06_timeline',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhite', z: 0),
        _text(
          'eyebrow',
          0.0833,
          0.0764,
          0.8333,
          0.0208,
          'WEEKEND FLOW',
          fontSize: 22,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF6E7A86',
          align: 'left',
          letterSpacing: 1.8,
        ),
        _text(
          'title',
          0.0833,
          0.1181,
          0.8333,
          0.0833,
          'A gentle pace from ceremony to dinner',
          fontSize: 44,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF24374A',
          align: 'left',
          lineHeight: 1.18,
        ),
        _deco('line', 0.1741, 0.2194, 0.0037, 0.5694, 'minimalGray', z: 2),
        ..._timelineRow(
          0.1481,
          0.2361,
          '1:30',
          'Arrival and welcome tea',
          '',
        ),
        ..._timelineRow(
          0.1481,
          0.3431,
          '2:00',
          'Ceremony begins',
          '',
        ),
        ..._timelineRow(
          0.1481,
          0.4500,
          '3:00',
          'Family portraits',
          '',
        ),
        ..._timelineRow(
          0.1481,
          0.5569,
          '5:30',
          'Dinner reception',
          '',
        ),
        ..._timelineRow(
          0.1481,
          0.6639,
          '7:00',
          'Toasts and music',
          '',
        ),
      ],
    ),
    _pageSpec(
      8,
      layoutId: 'p07_quote_poster',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperPink', z: 0),
        _deco(
          'border_frame',
          0.05,
          0.06,
          0.90,
          0.86,
          'paperPink',
          z: 1,
          radius: 0.04,
        ),
        _text(
          'eyebrow',
          0.74,
          0.15,
          0.10,
          0.02,
          'NOTE',
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FF24374A',
          letterSpacing: 1.8,
        ),
        _text(
          'title',
          0.10,
          0.17,
          0.58,
          0.44,
          'We loved the idea of\nbeginning our\nmarriage in a room full\nof familiar faces, soft\nmusic, and one slow,\nunforgettable\nafternoon.',
          fontSize: 44,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          lineHeight: 1.14,
          align: 'left',
        ),
        _text(
          'sign',
          0.10,
          0.77,
          0.18,
          0.03,
          'J + M',
          fontSize: 26,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
          align: 'left',
        ),
        _text(
          'foot',
          0.10,
          0.83,
          0.38,
          0.02,
          'A note from the couple',
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FF6E7A86',
          align: 'left',
        ),
      ],
    ),
    _pageSpec(
      9,
      layoutId: 'p08_rsvp_card',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhiteWarm', z: 0),
        _deco('outer', 0.08, 0.12, 0.84, 0.56, 'deepNavy', z: 2, radius: 0.04),
        _text(
          'eyebrow',
          0.34,
          0.16,
          0.32,
          0.02,
          'RSVP TICKET',
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FFF8FAFC',
          letterSpacing: 1.8,
        ),
        _deco(
          'inner',
          0.12,
          0.16,
          0.76,
          0.48,
          'paperWhiteWarm',
          z: 3,
          radius: 0.03,
        ),
        _text(
          'title',
          0.20,
          0.26,
          0.60,
          0.10,
          'Please reply by\nSeptember 15',
          fontSize: 34,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          lineHeight: 1.12,
        ),
        _deco(
          'link_chip',
          0.20,
          0.46,
          0.60,
          0.05,
          'cloudSkyBlue',
          z: 4,
          radius: 0.04,
        ),
        _text(
          'link',
          0.25,
          0.474,
          0.50,
          0.02,
          'snapfit.app/rsvp/julia-minho',
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
        ),
        _deco('line', 0.20, 0.56, 0.60, 0.002, 'minimalGray', z: 4),
        _text(
          'contact',
          0.22,
          0.60,
          0.56,
          0.06,
          'Planner 010-1234-5678\nBride 010-2345-6789',
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
          lineHeight: 1.32,
        ),
        _text(
          'footer',
          0.22,
          0.76,
          0.56,
          0.03,
          'Formal invitation follows soon',
          fontSize: 14,
          fontFamily: 'Inter',
          color: '#FF6E7A86',
        ),
      ],
    ),
    _pageSpec(
      10,
      layoutId: 'p09_end_poster',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'deepNavy', z: 0),
        _text(
          'title',
          0.0889,
          0.1528,
          0.8222,
          0.1583,
          'SEE YOU IN\nOCTOBER',
          fontSize: 82,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FFF8FAFC',
          lineHeight: 0.96,
          align: 'left',
        ),
        _text(
          'body',
          0.0889,
          0.4028,
          0.6481,
          0.0667,
          'Thank you for saving the date. We cannot wait to celebrate together.',
          fontSize: 28,
          fontFamily: 'Inter',
          color: '#FFDCE7F1',
          align: 'left',
          lineHeight: 1.18,
        ),
        _deco('line', 0.0889, 0.7153, 0.2778, 0.0014, 'paperWhiteWarm', z: 3),
        _text(
          'names',
          0.0889,
          0.7431,
          0.4815,
          0.0236,
          'JULIA + MINHO',
          fontSize: 28,
          fontFamily: 'Inter',
          fontWeight: 6,
          color: '#FFF8FAFC',
          align: 'left',
          letterSpacing: 3.0,
        ),
        _text(
          'date',
          0.0889,
          0.7875,
          0.4815,
          0.0208,
          'October 12, 2025',
          fontSize: 22,
          fontFamily: 'Inter',
          fontWeight: 5,
          color: '#FFDCE7F1',
          align: 'left',
        ),
      ],
    ),
    _pageSpec(
      11,
      layoutId: 'p10_photo_notes',
      recommendedPhotoCount: 3,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'paperWhiteWarm', z: 0),
        _text(
          'eyebrow',
          0.10,
          0.08,
          0.28,
          0.02,
          'PHOTO NOTES',
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF51606F',
          align: 'left',
          letterSpacing: 1.4,
        ),
        _text(
          'title',
          0.10,
          0.13,
          0.62,
          0.05,
          'Moments we want to remember',
          fontSize: 34,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF243B53',
          align: 'left',
        ),
        _image(
          'left_photo',
          0.0833,
          0.2083,
          0.3889,
          0.3611,
          _previewImages[4],
          z: 10,
          frame: 'rounded28',
        ),
        _image(
          'center_photo',
          0.5278,
          0.2083,
          0.3889,
          0.1667,
          _previewImages[5],
          z: 10,
          frame: 'rounded28',
        ),
        _image(
          'bottom_photo',
          0.5278,
          0.4028,
          0.3889,
          0.1667,
          _previewImages[6],
          z: 10,
          frame: 'rounded28',
        ),
        _text(
          'caption',
          0.0833,
          0.6056,
          0.8333,
          0.0556,
          'Ceremony details, intimate portraits, and warm editorial accents can be mixed across later pages.',
          fontSize: 22,
          fontFamily: 'Inter',
          color: '#FF64748B',
          align: 'left',
          lineHeight: 1.28,
        ),
      ],
    ),
    _pageSpec(
      12,
      layoutId: 'p11_dress_code',
      recommendedPhotoCount: 0,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'cloudSkyBlue', z: 0),
        _deco(
          'card',
          0.0796,
          0.0653,
          0.8407,
          0.8694,
          'paperWhiteWarm',
          z: 3,
          opacity: 0.97,
          radius: 0.04,
        ),
        _text(
          'eyebrow',
          0.34,
          0.11,
          0.32,
          0.02,
          'DRESS CODE',
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF51606F',
          letterSpacing: 1.6,
        ),
        _text(
          'title',
          0.1574,
          0.1806,
          0.6852,
          0.1750,
          'Soft formal\nMuted tones welcome',
          fontSize: 56,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF243B53',
          lineHeight: 0.95,
        ),
        _deco(
          'tone_a',
          0.1926,
          0.4375,
          0.1760,
          0.1319,
          'paperPink',
          z: 5,
          radius: 0.09,
        ),
        _deco(
          'tone_b',
          0.4130,
          0.4375,
          0.1760,
          0.1319,
          'cloudSkyBlue',
          z: 5,
          radius: 0.09,
        ),
        _deco(
          'tone_c',
          0.6333,
          0.4375,
          0.1760,
          0.1319,
          'deepNavy',
          z: 5,
          radius: 0.09,
        ),
        _text(
          'desc',
          0.1648,
          0.5917,
          0.7222,
          0.0583,
          'Cream, navy, soft peach, and gentle neutrals fit the day beautifully.',
          fontSize: 20,
          fontFamily: 'Inter',
          color: '#FF6B7280',
          lineHeight: 1.28,
        ),
        _text(
          'footer',
          0.2037,
          0.7819,
          0.6481,
          0.0528,
          'Think elegant tailoring, relaxed dresses, and textures that feel light in natural sunlight.',
          fontSize: 18,
          fontFamily: 'Inter',
          color: '#FF64748B',
          lineHeight: 1.28,
        ),
      ],
    ),
    _pageSpec(
      13,
      role: 'end',
      layoutId: 'p12_closing_photo',
      recommendedPhotoCount: 1,
      layers: [
        _deco('bg', 0, 0, 1, 1, 'deepNavy', z: 0),
        _deco(
          'card',
          0.0648,
          0.0486,
          0.8704,
          0.9028,
          'paperWhiteWarm',
          z: 2,
          radius: 0.035,
        ),
        _image(
          'main',
          0.1204,
          0.0958,
          0.7593,
          0.5278,
          _previewImages[7],
          z: 10,
          frame: 'rounded28',
        ),
        _text(
          'title',
          0.1204,
          0.6611,
          0.7593,
          0.0917,
          'We cannot wait to celebrate\ntogether.',
          fontSize: 44,
          fontFamily: 'Inter',
          fontWeight: 8,
          color: '#FF24374A',
          lineHeight: 1.08,
        ),
        _text(
          'body',
          0.2130,
          0.7556,
          0.5741,
          0.0556,
          'Invitation and RSVP details will follow soon. Thank you for saving the date with us.',
          fontSize: 18,
          fontFamily: 'Inter',
          color: '#FF6E7A86',
          lineHeight: 1.4,
        ),
        _text(
          'footer',
          0.3130,
          0.8667,
          0.3741,
          0.0194,
          'JULIA + MINHO  ·  OCT 12',
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: 7,
          color: '#FF24374A',
          letterSpacing: 1.2,
        ),
      ],
    ),
  ];
  final syncedPages = pages.toList(growable: false);
  final squareVariant = _buildVariant(
    aspect: 'square',
    width: 1440,
    height: 1440,
    cover: cover,
    pages: syncedPages,
  );
  final landscapeVariant = _buildVariant(
    aspect: 'landscape',
    width: 1440,
    height: 1080,
    cover: cover,
    pages: syncedPages,
  );

  return {
    'title': 'SAVE THE DATE',
    'name': 'SAVE THE DATE',
    'category': '웨딩',
    'style': 'editorial',
    'tags': ['웨딩', '세이브더데이트', '청첩장', '모던', '리파인'],
    'coverImageUrl': _coverImage,
    'previewImages': [
      _coverImage,
      ..._previewImages.where((url) => url != _coverImage),
    ],
    'templateId': 'save_the_date_v1',
    'version': 1,
    'lifecycleStatus': 'published',
    'aspect': 'portrait',
    'ratio': '0.75',
    'designWidth': 1080,
    'designHeight': 1440,
    'recommendedPhotoCount': 13,
    'strictLayout': true,
    'autoFit': false,
    'cover': {'theme': 'auto', 'layers': cover},
    'pages': syncedPages,
    'variants': {'square': squareVariant, 'landscape': landscapeVariant},
    'metadata': {
      'source': 'figma_section_57_8_refined_master',
      'sourceNodeId': '57:8',
      'sourceRootNodeId': '37:2',
      'designWidth': 1080,
      'designHeight': 1440,
      'strictLayout': true,
      'autoFit': false,
      'notes': [
        'portrait_master_with_generated_square_landscape_variants',
        'preview_and_step2_editor_parity_required',
        'cover_background_image_required',
        'rebuilt_from_figma_59_2_master',
        'figma_frame_count_synced_to_refined_master_13',
      ],
    },
  };
}

Future<void> _syncIntoStoreLatest({
  required String generatedStorePath,
  required String storeLatestPath,
}) async {
  final generatedRaw = await File(generatedStorePath).readAsString();
  final generatedItems = (jsonDecode(generatedRaw) as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  if (generatedItems.isEmpty) return;

  final generatedItem = generatedItems.first;
  final generatedTitle = _normalizeTitle(
    generatedItem['title']?.toString() ?? '',
  );

  final storeLatestFile = File(storeLatestPath);
  final existing = storeLatestFile.existsSync()
      ? (jsonDecode(await storeLatestFile.readAsString()) as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  existing.removeWhere(
    (item) =>
        _normalizeTitle(item['title']?.toString() ?? '') == generatedTitle,
  );
  existing.add(generatedItem);

  await storeLatestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(existing),
  );
}

String _normalizeTitle(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '');

Map<String, dynamic> _buildVariant({
  required String aspect,
  required double width,
  required double height,
  required List<Map<String, dynamic>> cover,
  required List<Map<String, dynamic>> pages,
}) {
  return {
    'aspect': aspect,
    'designWidth': width,
    'designHeight': height,
    'cover': {
      'theme': 'auto',
      'layers': _transformLayersForAspect(
        cover,
        targetWidth: width,
        targetHeight: height,
      ),
    },
    'pages': pages
        .map(
          (page) => {
            ...page,
            'layers': _transformLayersForAspect(
              (page['layers'] as List<dynamic>)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(growable: false),
              targetWidth: width,
              targetHeight: height,
            ),
          },
        )
        .toList(growable: false),
  };
}

List<Map<String, dynamic>> _transformLayersForAspect(
  List<Map<String, dynamic>> layers, {
  required double targetWidth,
  required double targetHeight,
}) {
  const portraitWidth = 1080.0;
  const portraitHeight = 1440.0;
  final scale = (targetWidth / portraitWidth) < (targetHeight / portraitHeight)
      ? (targetWidth / portraitWidth)
      : (targetHeight / portraitHeight);
  final scaledWidth = portraitWidth * scale;
  final scaledHeight = portraitHeight * scale;
  final offsetX = (targetWidth - scaledWidth) / 2;
  final offsetY = (targetHeight - scaledHeight) / 2;

  return layers
      .map((layer) {
        final next = Map<String, dynamic>.from(layer);
        final payload = layer['payload'] is Map
            ? Map<String, dynamic>.from(layer['payload'] as Map)
            : null;

        final isFullBleed =
            (layer['type'] == 'DECORATION' || layer['type'] == 'decoration') &&
            ((layer['x'] as num?)?.toDouble() ?? 0) == 0 &&
            ((layer['y'] as num?)?.toDouble() ?? 0) == 0 &&
            ((layer['width'] as num?)?.toDouble() ?? 0) == 1 &&
            ((layer['height'] as num?)?.toDouble() ?? 0) == 1;

        if (!isFullBleed) {
          final x = ((layer['x'] as num?)?.toDouble() ?? 0) * portraitWidth;
          final y = ((layer['y'] as num?)?.toDouble() ?? 0) * portraitHeight;
          final w = ((layer['width'] as num?)?.toDouble() ?? 0) * portraitWidth;
          final h =
              ((layer['height'] as num?)?.toDouble() ?? 0) * portraitHeight;

          next['x'] = ((x * scale) + offsetX) / targetWidth;
          next['y'] = ((y * scale) + offsetY) / targetHeight;
          next['width'] = (w * scale) / targetWidth;
          next['height'] = (h * scale) / targetHeight;
        }

        if (payload != null && payload['textStyle'] is Map) {
          final textStyle = Map<String, dynamic>.from(
            payload['textStyle'] as Map,
          );
          final fontSize = (textStyle['fontSize'] as num?)?.toDouble();
          if (fontSize != null) {
            final scaledFontSize = double.parse(
              (fontSize * scale).toStringAsFixed(2),
            );
            textStyle['fontSize'] = scaledFontSize;
            textStyle['fontSizeRatio'] = scaledFontSize / targetWidth;
          }
          payload['textStyle'] = textStyle;
          next['payload'] = payload;
        }

        return next;
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _coverLayers() => [
  _image(
    'cover_bg',
    0.0,
    0.0,
    1.0,
    1.0,
    _coverImage,
    z: 0,
    frame: 'free',
  ),
  _deco('cover_overlay', 0.0, 0.0, 1.0, 1.0, 'deepNavy', z: 1, opacity: 0.26),
  _deco(
    'date_chip',
    0.0667,
    0.05,
    0.1667,
    0.0278,
    'paperWhiteWarm',
    z: 3,
    radius: 0.0185,
  ),
  _text(
    'date',
    0.074,
    0.0569,
    0.137,
    0.0222,
    '2025.10.12 SAT',
    fontSize: 20,
    fontFamily: 'Inter',
    fontWeight: 6,
    color: '#FF24374A',
    letterSpacing: 1.2,
    z: 4,
  ),
  _text(
    'title',
    0.0778,
    0.6556,
    0.8444,
    0.1444,
    'SAVE THE\nDATE',
    fontSize: 116,
    fontFamily: 'Inter',
    fontWeight: 8,
    color: '#FFF7F1E8',
    lineHeight: 0.90,
    align: 'left',
    letterSpacing: 1.4,
    z: 4,
  ),
  _text(
    'subtitle',
    0.0778,
    0.8431,
    0.6481,
    0.0264,
    'A floral aisle, sea light, and one October promise.',
    fontSize: 28,
    fontFamily: 'Inter',
    fontWeight: 5,
    color: '#FFF7F1E8',
    align: 'left',
    lineHeight: 1.1,
    z: 4,
  ),
  _text(
    'names',
    0.0778,
    0.9056,
    0.50,
    0.0236,
    'JULIA + MINHO',
    fontSize: 28,
    fontFamily: 'Inter',
    fontWeight: 6,
    color: '#FFF7F1E8',
    align: 'left',
    letterSpacing: 3.0,
    z: 4,
  ),
];

List<Map<String, dynamic>> _heroBase({
  required int photoIndex,
  required String haze,
}) {
  return [
    _deco('bg_dark_mask', 0, 0, 1, 1, 'darkVignette', z: 0),
    _image(
      'hero_main',
      0.0833,
      0.1458,
      0.8334,
      0.62,
      _previewImages[photoIndex],
      z: 3,
    ),
    _deco(
      'hero_top_tint',
      0.0833,
      0.1458,
      0.8334,
      0.26,
      'cloudSkyBlue',
      z: 4,
      opacity: 0.32,
    ),
    _deco(
      'hero_bottom_tint',
      0.0833,
      0.5070,
      0.8334,
      0.26,
      'paperPink',
      z: 5,
      opacity: 0.30,
    ),
    _deco(
      'haze_$haze',
      haze == 'left' ? 0.10 : (haze == 'center' ? 0.38 : 0.63),
      haze == 'center' ? 0.20 : 0.18,
      haze == 'center' ? 0.24 : 0.20,
      haze == 'center' ? 0.40 : 0.48,
      'minimalGray',
      z: 6,
      opacity: 0.18,
      radius: 0.22,
    ),
    _text(
      'photo_hint',
      0.31,
      0.44,
      0.38,
      0.024,
      '사진을 넣어주세요',
      fontSize: 20,
      fontFamily: 'Inter',
      fontWeight: 6,
      color: '#CCDDE7F4',
    ),
  ];
}

List<Map<String, dynamic>> _detailCard(
  String id,
  double x,
  double y,
  String title,
  String body,
) {
  return [
    _deco(
      '${id}_card',
      x,
      y,
      0.3889,
      0.1528,
      'paperWhite',
      z: 3,
      radius: 0.026,
    ),
    _text(
      '${id}_title',
      x + 0.0278,
      y + 0.0194,
      0.3333,
      0.0208,
      title,
      fontSize: 20,
      fontFamily: 'Inter',
      fontWeight: 7,
      color: '#FF24374A',
      align: 'left',
    ),
    _text(
      '${id}_body',
      x + 0.0278,
      y + 0.0569,
      0.3333,
      0.0639,
      body,
      fontSize: 24,
      fontFamily: 'Inter',
      fontWeight: 5,
      color: '#FF24374A',
      align: 'left',
      lineHeight: 1.22,
    ),
  ];
}

List<Map<String, dynamic>> _timelineRow(
  double x,
  double y,
  String time,
  String title,
  String body,
) {
  return [
    _deco(
      'dot_${time}_$title',
      x,
      y + 0.006,
      0.0556,
      0.0417,
      'deepNavy',
      z: 4,
      radius: 0.04,
    ),
    _text(
      'time_${time}_$title',
      x + 0.0926,
      y,
      0.2037,
      0.0264,
      time,
      fontSize: 20,
      fontFamily: 'Inter',
      fontWeight: 7,
      color: '#FF6E7A86',
      align: 'left',
      letterSpacing: 1.0,
    ),
    _text(
      'title_${time}_$title',
      x + 0.3020,
      y + 0.0014,
      0.3889,
      0.0264,
      title,
      fontSize: 20,
      fontFamily: 'Inter',
      fontWeight: 6,
      color: '#FF24374A',
      align: 'left',
    ),
    if (body.trim().isNotEmpty)
      _text(
        'body_${time}_$title',
        x + 0.3020,
        y + 0.0320,
        0.3889,
        0.0264,
        body,
        fontSize: 16,
        fontFamily: 'Inter',
        fontWeight: 5,
        color: '#FF6E7A86',
        align: 'left',
      ),
  ];
}

Map<String, dynamic> _pageSpec(
  int pageNumber, {
  String role = 'inner',
  required String layoutId,
  required int recommendedPhotoCount,
  required List<Map<String, dynamic>> layers,
}) {
  return {
    'pageNumber': pageNumber,
    'role': role,
    'layoutId': layoutId,
    'recommendedPhotoCount': recommendedPhotoCount,
    'layers': layers,
  };
}

Map<String, dynamic> _image(
  String id,
  double x,
  double y,
  double width,
  double height,
  String imageUrl, {
  int z = 10,
  double rotation = 0,
  String frame = 'free',
  String imageTemplate = 'free',
  double opacity = 1.0,
}) {
  return {
    'id': id,
    'type': 'IMAGE',
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': z,
    'scale': 1.0,
    'rotation': rotation,
    'opacity': opacity,
    'payload': {
      'imageBackground': frame,
      'imageTemplate': imageTemplate,
      'imageUrl': imageUrl,
      'previewUrl': imageUrl,
      'originalUrl': imageUrl,
    },
  };
}

Map<String, dynamic> _deco(
  String id,
  double x,
  double y,
  double width,
  double height,
  String background, {
  int z = 1,
  double rotation = 0,
  double opacity = 1.0,
  double? radius,
  String? fillColor,
  String? borderColor,
  double? borderWidth,
}) {
  return {
    'id': id,
    'type': 'DECORATION',
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': z,
    'scale': 1.0,
    'rotation': rotation,
    'opacity': opacity,
    'payload': {
      'imageBackground': background,
      'imageTemplate': 'free',
      if (radius != null) 'cornerRadius': radius,
      if (fillColor != null) 'fillColor': fillColor,
      if (borderColor != null) 'borderColor': borderColor,
      if (borderWidth != null) 'borderWidth': borderWidth,
    },
  };
}

Map<String, dynamic> _pill(
  String id,
  double x,
  double y,
  double width,
  double height, {
  double opacity = 0.4,
}) {
  return _deco(
    id,
    x,
    y,
    width,
    height,
    'darkVignette',
    z: 12,
    opacity: opacity,
    radius: 0.08,
  );
}

Map<String, dynamic> _text(
  String id,
  double x,
  double y,
  double width,
  double height,
  String text, {
  String align = 'center',
  int z = 20,
  required double fontSize,
  String fontFamily = 'Inter',
  int fontWeight = 5,
  String color = '#FF1F2937',
  double letterSpacing = 0,
  double? lineHeight,
}) {
  return {
    'id': id,
    'type': 'TEXT',
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': z,
    'scale': 1.0,
    'rotation': 0.0,
    'opacity': 1.0,
    'payload': {
      'text': text,
      'textAlign': align,
      'textStyleType': 'none',
      'textBackground': null,
      'bubbleColor': null,
      'textStyle': {
        'fontSize': fontSize,
        'fontSizeRatio': fontSize / 1080,
        'fontWeight': fontWeight,
        'fontStyle': 0,
        'fontFamily': fontFamily,
        'color': color,
        'letterSpacing': letterSpacing,
        if (lineHeight != null) 'height': lineHeight,
      },
    },
  };
}
