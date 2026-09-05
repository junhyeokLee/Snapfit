import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_template_builder.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  test('builds cover and story pages from AI recommendation draft', () {
    final firstAsset = _asset('photo-1', DateTime(2026, 8, 20));
    final secondAsset = _asset('photo-2', DateTime(2026, 8, 20));
    final draft = AlbumRecommendationDraft(
      theme: AlbumTheme.travel,
      title: '여행의 장면들',
      pageCount: 10,
      templateTone: '날짜 흐름이 보이는 따뜻한 여행 기록 템플릿',
      recommendedPhotos: [
        RecommendedPhoto(
          candidate: _candidate('photo-1', DateTime(2026, 8, 20), firstAsset),
          score: 0.9,
          reasons: const [
            AiCurationReason(
              type: AiCurationReasonType.themeOrientation,
              message: '여행 앨범에 어울리는 장소감',
            ),
          ],
        ),
        RecommendedPhoto(
          candidate: _candidate('photo-2', DateTime(2026, 8, 20), secondAsset),
          score: 0.8,
          reasons: const [
            AiCurationReason(
              type: AiCurationReasonType.dateFlow,
              message: '날짜 흐름을 이어주는 장면',
            ),
          ],
        ),
      ],
      excludedPhotos: const [],
      storySections: const [
        StorySection(
          title: '여행의 시작',
          description: '앨범의 첫 인상이 되는 대표 장면이에요.',
          photoAssetIds: ['photo-1', 'photo-2'],
        ),
      ],
      summary: '날짜별 흐름을 살려 1개 묶음으로 나누었어요.',
    );

    expect(const AiAlbumDraftTemplateBuilder().isEditorReady(draft), isTrue);

    final pages = const AiAlbumDraftTemplateBuilder().build(draft);
    final coverImage = pages.first.firstWhere((l) => l.type == LayerType.image);
    final storyImages = pages[1]
        .where((l) => l.type == LayerType.image)
        .toList();

    expect(pages.length, 11);
    expect(coverImage.asset, same(firstAsset));
    expect(
      pages.first.any((l) => l.type == LayerType.text && l.text == '여행의 장면들'),
      isTrue,
    );
    expect(storyImages, hasLength(2));
    expect(storyImages.first.asset, same(firstAsset));
    expect(storyImages.last.asset, same(secondAsset));
    expect(pages[1].any((l) => l.id.contains('photo-1')), isTrue);
    expect(
      pages[1].any((l) => l.type == LayerType.text && l.text == '여행의 시작'),
      isTrue,
    );
  });

  test(
    'fills extra editor pages with unused local assets after story sections',
    () {
      final assets = [
        for (var i = 1; i <= 6; i++)
          _asset('photo-$i', DateTime(2026, 8, 20, 10, i)),
      ];
      final draft = AlbumRecommendationDraft(
        theme: AlbumTheme.travel,
        title: '여행의 장면들',
        pageCount: 3,
        templateTone: '대표 컷 중심 여행 템플릿',
        recommendedPhotos: [
          for (var i = 0; i < assets.length; i++)
            RecommendedPhoto(
              candidate: _candidate(
                'photo-${i + 1}',
                DateTime(2026, 8, 20, 10, i),
                assets[i],
              ),
              score: 0.9 - (i * 0.02),
              reasons: const [
                AiCurationReason(
                  type: AiCurationReasonType.highResolution,
                  message: '크게 넣어도 선명한 사진이에요',
                ),
              ],
            ),
        ],
        excludedPhotos: const [],
        storySections: const [
          StorySection(
            title: '여행의 시작',
            description: '대표 장면을 먼저 배치해요.',
            photoAssetIds: ['photo-1', 'photo-2', 'photo-3', 'photo-4'],
          ),
        ],
        summary: '대표 컷 중심으로 초안을 만들었어요.',
      );

      final pages = const AiAlbumDraftTemplateBuilder().build(draft);
      final innerImageLayers = pages
          .skip(1)
          .expand(
            (page) => page.where((layer) => layer.type == LayerType.image),
          );

      expect(
        innerImageLayers.map((layer) => layer.id).toSet(),
        containsAll([
          'ai_photo_photo-1',
          'ai_photo_photo-2',
          'ai_photo_photo-3',
          'ai_photo_photo-4',
          'ai_photo_photo-5',
          'ai_photo_photo-6',
        ]),
      );
      expect(innerImageLayers.map((layer) => layer.id).toSet(), hasLength(6));
      expect(
        pages[2]
            .where((layer) => layer.type == LayerType.image)
            .map((layer) => layer.id),
        ['ai_photo_photo-5', 'ai_photo_photo-6'],
      );
      for (final layer in innerImageLayers) {
        expect(layer.asset, isNotNull);
        expect(layer.imageUrl, isNull);
        expect(layer.originalUrl, isNull);
        expect(layer.previewUrl, isNull);
      }
    },
  );

  test('reports draft without local image assets as not editor-ready', () {
    final draft = AlbumRecommendationDraft(
      theme: AlbumTheme.daily,
      title: '일상의 장면들',
      pageCount: 3,
      templateTone: '일상 기록 템플릿',
      recommendedPhotos: [
        RecommendedPhoto(
          candidate: PhotoCandidate(
            assetId: 'missing-local-asset',
            createdAt: DateTime(2026, 8, 20),
            width: 4000,
            height: 3000,
            orientation: PhotoOrientation.landscape,
          ),
          score: 0.9,
          reasons: const [
            AiCurationReason(
              type: AiCurationReasonType.highResolution,
              message: '크게 넣어도 선명한 사진이에요',
            ),
          ],
        ),
      ],
      excludedPhotos: const [],
      storySections: const [
        StorySection(
          title: '일상의 시작',
          description: '첫 장면이에요.',
          photoAssetIds: ['missing-local-asset'],
        ),
      ],
      summary: '초안을 준비했어요.',
    );

    expect(const AiAlbumDraftTemplateBuilder().isEditorReady(draft), isFalse);
  });

  test('reports draft with page count mismatch as not editor-ready', () {
    final asset = _asset('photo-1', DateTime(2026, 8, 20));
    final draft = AlbumRecommendationDraft(
      theme: AlbumTheme.daily,
      title: '일상의 장면들',
      pageCount: 0,
      templateTone: '일상 기록 템플릿',
      recommendedPhotos: [
        RecommendedPhoto(
          candidate: _candidate('photo-1', DateTime(2026, 8, 20), asset),
          score: 0.9,
          reasons: const [
            AiCurationReason(
              type: AiCurationReasonType.highResolution,
              message: '크게 넣어도 선명한 사진이에요',
            ),
          ],
        ),
      ],
      excludedPhotos: const [],
      storySections: const [],
      summary: '초안을 준비했어요.',
    );

    expect(const AiAlbumDraftTemplateBuilder().isEditorReady(draft), isFalse);
  });
}

PhotoCandidate _candidate(String id, DateTime createdAt, AssetEntity asset) {
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: 4000,
    height: 3000,
    orientation: PhotoOrientation.landscape,
    asset: asset,
  );
}

AssetEntity _asset(String id, DateTime createdAt) {
  return AssetEntity(
    id: id,
    typeInt: AssetType.image.index,
    width: 4000,
    height: 3000,
    createDateSecond: createdAt.millisecondsSinceEpoch ~/ 1000,
  );
}
