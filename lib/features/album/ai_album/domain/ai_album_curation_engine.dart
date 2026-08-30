import 'ai_album_models.dart';

class AiAlbumCurationEngine {
  const AiAlbumCurationEngine();

  AlbumRecommendationDraft curate({
    required AlbumTheme theme,
    required List<PhotoCandidate> candidates,
  }) {
    final scored =
        candidates.map((candidate) {
          return RecommendedPhoto(
            candidate: candidate,
            score: _score(candidate, theme, candidates),
            reasons: _reasons(candidate, theme),
          );
        }).toList()..sort((a, b) {
          final scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return a.candidate.createdAt.compareTo(b.candidate.createdAt);
        });

    final excluded = scored
        .where((photo) => photo.score < 0.45)
        .map((photo) => photo.candidate)
        .toList(growable: false);

    final selected = _balancedByDate(
      scored.where((photo) => photo.score >= 0.45),
    );
    final sections = _buildStorySections(theme, selected);

    return AlbumRecommendationDraft(
      theme: theme,
      title: _titleFor(theme),
      pageCount: _pageCountFor(selected.length),
      templateTone: _templateToneFor(theme),
      recommendedPhotos: selected,
      excludedPhotos: excluded,
      storySections: sections,
      summary: _summaryFor(
        theme,
        selected.length,
        excluded.length,
        sections.length,
      ),
    );
  }

  double _score(
    PhotoCandidate candidate,
    AlbumTheme theme,
    List<PhotoCandidate> all,
  ) {
    var score = 0.55;
    if (candidate.isHighResolution) score += 0.18;
    if (candidate.isScreenshot) score -= 0.7;

    final closeNeighborCount = all.where((other) {
      if (other.assetId == candidate.assetId) return false;
      return other.createdAt.difference(candidate.createdAt).abs().inMinutes <=
          3;
    }).length;
    if (closeNeighborCount > 0) score -= 0.18 * closeNeighborCount;

    switch (theme) {
      case AlbumTheme.travel:
        if (candidate.orientation == PhotoOrientation.landscape) score += 0.16;
      case AlbumTheme.couple:
      case AlbumTheme.family:
      case AlbumTheme.baby:
        if (candidate.orientation == PhotoOrientation.portrait) score += 0.12;
      case AlbumTheme.birthday:
      case AlbumTheme.friends:
      case AlbumTheme.daily:
      case AlbumTheme.custom:
        score += 0.04;
    }

    return score.clamp(0.0, 1.0).toDouble();
  }

  List<String> _reasons(PhotoCandidate candidate, AlbumTheme theme) {
    final reasons = <String>[];
    if (candidate.isHighResolution) reasons.add('선명한 원본 후보');
    if (candidate.orientation == PhotoOrientation.landscape &&
        theme == AlbumTheme.travel) {
      reasons.add('여행 앨범에 어울리는 장소감');
    }
    if (candidate.orientation == PhotoOrientation.portrait &&
        (theme == AlbumTheme.couple ||
            theme == AlbumTheme.family ||
            theme == AlbumTheme.baby)) {
      reasons.add('인물 중심 앨범에 어울리는 비율');
    }
    if (reasons.isEmpty) reasons.add('날짜 흐름을 이어주는 장면');
    return reasons;
  }

  List<RecommendedPhoto> _balancedByDate(Iterable<RecommendedPhoto> photos) {
    final byDay = <String, List<RecommendedPhoto>>{};
    for (final photo in photos) {
      byDay.putIfAbsent(photo.candidate.dayKey, () => []).add(photo);
    }
    for (final dayPhotos in byDay.values) {
      dayPhotos.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        return a.candidate.createdAt.compareTo(b.candidate.createdAt);
      });
    }

    final result = <RecommendedPhoto>[];
    for (final day in byDay.keys.toList()..sort()) {
      result.addAll(byDay[day]!.take(6));
    }
    result.sort(
      (a, b) => a.candidate.createdAt.compareTo(b.candidate.createdAt),
    );
    return result.take(32).toList(growable: false);
  }

  List<StorySection> _buildStorySections(
    AlbumTheme theme,
    List<RecommendedPhoto> selected,
  ) {
    if (selected.isEmpty) {
      return [
        StorySection(
          title: '시작할 사진이 필요해요',
          description: '허용한 사진 범위를 넓히면 다시 추천할 수 있어요.',
          photoAssetIds: const [],
        ),
      ];
    }

    final byDay = <String, List<String>>{};
    for (final photo in selected) {
      byDay.putIfAbsent(photo.candidate.dayKey, () => []).add(photo.assetId);
    }

    final days = byDay.keys.toList()..sort();
    return [
      StorySection(
        title: _sectionStartTitleFor(theme),
        description: '앨범의 첫 인상이 되는 대표 장면이에요.',
        photoAssetIds: byDay[days.first]!.take(3).toList(growable: false),
      ),
      if (days.length > 1)
        ...days
            .skip(1)
            .take(days.length - 2)
            .map(
              (day) => StorySection(
                title: '$day 흐름',
                description: '날짜별로 자연스럽게 이어지는 장면을 묶었어요.',
                photoAssetIds: byDay[day]!.take(6).toList(growable: false),
              ),
            ),
      if (days.length > 1)
        StorySection(
          title: '마지막 장면',
          description: '앨범을 닫는 느낌의 사진을 뒤쪽에 배치해요.',
          photoAssetIds: byDay[days.last]!.take(3).toList(growable: false),
        ),
    ];
  }

  int _pageCountFor(int photoCount) {
    if (photoCount <= 10) return 10;
    if (photoCount <= 18) return 14;
    if (photoCount <= 26) return 18;
    return 24;
  }

  String _titleFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행의 장면들',
      AlbumTheme.couple => '우리의 따뜻한 순간',
      AlbumTheme.family => '함께 보낸 날들',
      AlbumTheme.baby => '작고 반짝인 성장 기록',
      AlbumTheme.birthday => '축하로 채운 하루',
      AlbumTheme.friends => '우리들의 기록',
      AlbumTheme.daily => '작고 반짝인 하루들',
      AlbumTheme.custom => '나만의 이야기',
    };
  }

  String _templateToneFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '날짜 흐름이 보이는 따뜻한 여행 기록 템플릿',
      AlbumTheme.couple => '둘의 분위기를 살리는 여백 많은 커플 템플릿',
      AlbumTheme.family => '사진이 크게 보이는 따뜻한 가족 템플릿',
      AlbumTheme.baby => '작은 표정과 성장 흐름을 담는 베이비북 템플릿',
      AlbumTheme.birthday => '축하 장면과 하이라이트가 또렷한 기념일 템플릿',
      AlbumTheme.friends => '여러 장면을 경쾌하게 묶는 친구 기록 템플릿',
      AlbumTheme.daily => '담백한 여백으로 하루를 정리하는 일상 템플릿',
      AlbumTheme.custom => '직접 입력한 주제에 맞춰 조정 가능한 기본 템플릿',
    };
  }

  String _sectionStartTitleFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행의 시작',
      AlbumTheme.couple => '둘의 시작 장면',
      AlbumTheme.family => '함께한 시작',
      AlbumTheme.baby => '성장의 시작',
      AlbumTheme.birthday => '축하의 시작',
      AlbumTheme.friends => '우리의 시작',
      AlbumTheme.daily => '하루의 시작',
      AlbumTheme.custom => '이야기의 시작',
    };
  }

  String _summaryFor(
    AlbumTheme theme,
    int selectedCount,
    int excludedCount,
    int sectionCount,
  ) {
    return '날짜별 흐름을 살려 $sectionCount개 묶음으로 나누고, '
        '비슷한 사진은 대표 장면만 남겼어요. '
        '${_themeLabel(theme)} 앨범에 어울리는 사진 $selectedCount장을 골랐고, '
        '$excludedCount장은 접어두었어요.';
  }

  String _themeLabel(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행',
      AlbumTheme.couple => '커플',
      AlbumTheme.family => '가족',
      AlbumTheme.baby => '아기/성장',
      AlbumTheme.birthday => '생일/기념일',
      AlbumTheme.friends => '친구',
      AlbumTheme.daily => '일상 기록',
      AlbumTheme.custom => '직접 입력',
    };
  }
}
