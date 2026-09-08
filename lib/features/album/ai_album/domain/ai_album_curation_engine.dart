import 'ai_album_models.dart';

class AiAlbumCurationEngine {
  const AiAlbumCurationEngine();

  AlbumRecommendationDraft curate({
    required AlbumTheme theme,
    required List<PhotoCandidate> candidates,
  }) {
    final excluded = <String, ExcludedPhoto>{};
    final eligible = <RecommendedPhoto>[];

    for (final cluster in _timeClusters(candidates)) {
      final usable = <RecommendedPhoto>[];
      for (final candidate in cluster) {
        final exclusionReasons = _hardExclusionReasons(candidate);
        if (exclusionReasons.isNotEmpty) {
          excluded[candidate.assetId] = ExcludedPhoto(
            candidate: candidate,
            reasons: exclusionReasons,
          );
        } else {
          usable.add(_recommended(candidate, theme));
        }
      }
      if (usable.isEmpty) continue;

      usable.sort(_rankRecommended);
      final keepCount = cluster.length >= 5 ? 2 : 1;
      final keepers = usable.take(keepCount).toList(growable: false);
      final keeperIds = keepers.map((photo) => photo.assetId).toSet();
      for (final keeper in keepers) {
        eligible.add(
          _withReason(
            keeper,
            const AiCurationReason(
              type: AiCurationReasonType.timeClusterRepresentative,
              message: '비슷한 시간대 사진 중 대표로 골랐어요',
            ),
          ),
        );
      }
      if (cluster.length > keepers.length) {
        for (final candidate in cluster.where(
          (photo) => !keeperIds.contains(photo.assetId),
        )) {
          _addExcludedReason(
            excluded,
            candidate,
            const AiCurationReason(
              type: AiCurationReasonType.duplicateTimeExcluded,
              message: '비슷한 시간대 사진이 많아 대표 컷만 먼저 넣었어요',
            ),
          );
        }
      }
    }

    eligible.sort(
      (a, b) => a.candidate.createdAt.compareTo(b.candidate.createdAt),
    );
    final selected = _balancedByDate(eligible, excluded);
    final sections = _buildStorySections(theme, selected);
    final pageCount = _pageCountFor(selected.length);

    return AlbumRecommendationDraft(
      theme: theme,
      title: _titleFor(theme),
      pageCount: pageCount,
      templateTone: _templateToneFor(theme),
      recommendedPhotos: selected,
      excludedPhotos: excluded.values.toList(
        growable: false,
      )..sort((a, b) => a.candidate.createdAt.compareTo(b.candidate.createdAt)),
      storySections: sections,
      summary: _summaryFor(
        theme,
        selected.length,
        excluded.length,
        sections.length,
      ),
      templateSlots: _premiumTemplateSlotsFor(theme, pageCount, sections),
      curationNotes: _curationNotesFor(
        theme: theme,
        selected: selected,
        excluded: excluded.values.toList(growable: false),
        candidates: candidates,
      ),
    );
  }

  RecommendedPhoto _recommended(PhotoCandidate candidate, AlbumTheme theme) {
    return RecommendedPhoto(
      candidate: candidate,
      score: _score(candidate, theme),
      reasons: _reasons(candidate, theme),
    );
  }

  double _score(PhotoCandidate candidate, AlbumTheme theme) {
    var score = 0.55;
    if (candidate.isHighResolution) score += 0.18;
    if (_albumNameMatchesTheme(candidate.albumName, theme)) score += 0.08;

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

  List<List<PhotoCandidate>> _timeClusters(List<PhotoCandidate> candidates) {
    if (candidates.isEmpty) return const [];
    final sorted = [...candidates]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final clusters = <List<PhotoCandidate>>[];
    var current = <PhotoCandidate>[sorted.first];
    for (final candidate in sorted.skip(1)) {
      final previous = current.last;
      final isClose =
          candidate.createdAt.difference(previous.createdAt).abs().inMinutes <=
          3;
      if (isClose) {
        current.add(candidate);
      } else {
        clusters.add(current);
        current = [candidate];
      }
    }
    clusters.add(current);
    return clusters;
  }

  List<AiCurationReason> _hardExclusionReasons(PhotoCandidate candidate) {
    final reasons = <AiCurationReason>[];
    if (candidate.isScreenshot) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.screenshotExcluded,
          message: '스크린샷이라 사진 앨범 초안에서는 잠시 빼뒀어요',
        ),
      );
    }
    if (candidate.isLowResolution) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.lowResolutionExcluded,
          message: '크게 넣기엔 해상도가 낮아 잠시 빼뒀어요',
        ),
      );
    }
    return reasons;
  }

  int _rankRecommended(RecommendedPhoto a, RecommendedPhoto b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.candidate.createdAt.compareTo(b.candidate.createdAt);
  }

  RecommendedPhoto _withReason(
    RecommendedPhoto photo,
    AiCurationReason reason,
  ) {
    final hasReason = photo.reasons.any(
      (existing) => existing.type == reason.type,
    );
    if (hasReason) return photo;
    return RecommendedPhoto(
      candidate: photo.candidate,
      score: photo.score,
      reasons: [...photo.reasons, reason],
    );
  }

  void _addExcludedReason(
    Map<String, ExcludedPhoto> excluded,
    PhotoCandidate candidate,
    AiCurationReason reason,
  ) {
    final existing = excluded[candidate.assetId];
    if (existing == null) {
      excluded[candidate.assetId] = ExcludedPhoto(
        candidate: candidate,
        reasons: [reason],
      );
      return;
    }
    if (existing.reasons.any((current) => current.type == reason.type)) return;
    excluded[candidate.assetId] = ExcludedPhoto(
      candidate: candidate,
      reasons: [...existing.reasons, reason],
    );
  }

  bool _albumNameMatchesTheme(String? albumName, AlbumTheme theme) {
    final normalized = albumName?.toLowerCase() ?? '';
    if (normalized.isEmpty) return false;
    return switch (theme) {
      AlbumTheme.travel =>
        normalized.contains('travel') ||
            normalized.contains('trip') ||
            normalized.contains('여행'),
      AlbumTheme.family =>
        normalized.contains('family') || normalized.contains('가족'),
      AlbumTheme.baby =>
        normalized.contains('baby') ||
            normalized.contains('아기') ||
            normalized.contains('성장'),
      AlbumTheme.birthday =>
        normalized.contains('birthday') ||
            normalized.contains('생일') ||
            normalized.contains('기념'),
      AlbumTheme.friends =>
        normalized.contains('friends') || normalized.contains('친구'),
      AlbumTheme.couple =>
        normalized.contains('couple') ||
            normalized.contains('date') ||
            normalized.contains('커플'),
      AlbumTheme.daily || AlbumTheme.custom => false,
    };
  }

  List<AiCurationReason> _reasons(PhotoCandidate candidate, AlbumTheme theme) {
    final reasons = <AiCurationReason>[];
    if (candidate.isHighResolution) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.highResolution,
          message: '크게 넣어도 선명한 사진이에요',
        ),
      );
    }
    if (candidate.orientation == PhotoOrientation.landscape &&
        theme == AlbumTheme.travel) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.themeOrientation,
          message: '풍경과 장소감이 잘 살아나는 컷이에요',
        ),
      );
    }
    if (candidate.orientation == PhotoOrientation.portrait &&
        (theme == AlbumTheme.couple ||
            theme == AlbumTheme.family ||
            theme == AlbumTheme.baby)) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.themeOrientation,
          message: '표정과 분위기를 크게 담기 좋은 비율이에요',
        ),
      );
    }
    if (_albumNameMatchesTheme(candidate.albumName, theme)) {
      reasons.add(
        const AiCurationReason(
          type: AiCurationReasonType.weakThemeFitExcluded,
          message: '선택한 주제와 맞는 앨범/폴더의 사진이에요',
        ),
      );
    }
    reasons.add(
      const AiCurationReason(
        type: AiCurationReasonType.dateFlow,
        message: '이날의 이야기를 이어주는 장면이에요',
      ),
    );
    return reasons;
  }

  List<RecommendedPhoto> _balancedByDate(
    Iterable<RecommendedPhoto> photos,
    Map<String, ExcludedPhoto> excluded,
  ) {
    final byDay = <String, List<RecommendedPhoto>>{};
    for (final photo in photos) {
      byDay.putIfAbsent(photo.candidate.dayKey, () => []).add(photo);
    }
    for (final dayPhotos in byDay.values) {
      dayPhotos.sort(_rankRecommended);
    }

    final result = <RecommendedPhoto>[];
    for (final day in byDay.keys.toList()..sort()) {
      final dayPhotos = byDay[day]!;
      result.addAll(dayPhotos.take(6));
      for (final photo in dayPhotos.skip(6)) {
        excluded[photo.assetId] = ExcludedPhoto(
          candidate: photo.candidate,
          reasons: const [
            AiCurationReason(
              type: AiCurationReasonType.dailyLimitExcluded,
              message: '이날 사진이 많아 균형을 맞추려고 일부만 골랐어요',
            ),
          ],
        );
      }
    }
    result.sort(
      (a, b) => a.candidate.createdAt.compareTo(b.candidate.createdAt),
    );
    final selected = result.take(32).toList(growable: false);
    for (final photo in result.skip(32)) {
      excluded[photo.assetId] = ExcludedPhoto(
        candidate: photo.candidate,
        reasons: const [
          AiCurationReason(
            type: AiCurationReasonType.totalLimitExcluded,
            message: '전체 앨범 길이에 맞춰 우선순위가 높은 사진부터 담았어요',
          ),
        ],
      );
    }
    return selected;
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
    if (days.length == 1) return _oneDayStorySections(theme, selected);

    return [
      StorySection(
        title: _sectionStartTitleFor(theme),
        description: _sectionStartDescriptionFor(theme),
        photoAssetIds: byDay[days.first]!.take(3).toList(growable: false),
      ),
      if (days.length > 1)
        ...days
            .skip(1)
            .take(days.length - 2)
            .map(
              (day) => StorySection(
                title: '$day 흐름',
                description: _sectionMiddleDescriptionFor(theme),
                photoAssetIds: byDay[day]!.take(6).toList(growable: false),
              ),
            ),
      if (days.length > 1)
        StorySection(
          title: _sectionEndingTitleFor(theme),
          description: _sectionEndingDescriptionFor(theme),
          photoAssetIds: byDay[days.last]!.take(3).toList(growable: false),
        ),
    ];
  }

  List<StorySection> _oneDayStorySections(
    AlbumTheme theme,
    List<RecommendedPhoto> selected,
  ) {
    final buckets = <_TimeBucket, List<String>>{};
    for (final photo in selected) {
      buckets
          .putIfAbsent(_bucketFor(photo.candidate.createdAt.hour), () => [])
          .add(photo.assetId);
    }
    if (buckets.length == 1) {
      return [
        StorySection(
          title: _sectionStartTitleFor(theme),
          description: '한 날짜 안에서 대표 장면이 겹치지 않도록 먼저 묶었어요.',
          photoAssetIds: selected
              .map((photo) => photo.assetId)
              .take(6)
              .toList(growable: false),
        ),
      ];
    }
    final order = [
      _TimeBucket.morning,
      _TimeBucket.afternoon,
      _TimeBucket.evening,
    ];
    return [
      for (final bucket in order)
        if (buckets[bucket] != null)
          StorySection(
            title: _timeBucketTitle(bucket),
            description: _timeBucketDescription(bucket, theme),
            photoAssetIds: buckets[bucket]!.take(6).toList(growable: false),
          ),
    ];
  }

  _TimeBucket _bucketFor(int hour) {
    if (hour < 12) return _TimeBucket.morning;
    if (hour < 18) return _TimeBucket.afternoon;
    return _TimeBucket.evening;
  }

  String _timeBucketTitle(_TimeBucket bucket) {
    return switch (bucket) {
      _TimeBucket.morning => '오전의 준비',
      _TimeBucket.afternoon => '오후의 하이라이트',
      _TimeBucket.evening => '저녁의 마무리',
    };
  }

  String _timeBucketDescription(_TimeBucket bucket, AlbumTheme theme) {
    return switch (bucket) {
      _TimeBucket.morning => '하루가 시작되는 분위기와 첫 장면을 앞쪽에 뒀어요.',
      _TimeBucket.afternoon => '${_themeLabel(theme)} 앨범의 중심이 되는 장면을 묶었어요.',
      _TimeBucket.evening => '앨범 끝에 두면 여운이 남는 장면을 뒤쪽에 배치했어요.',
    };
  }

  int _pageCountFor(int photoCount) {
    if (photoCount <= 10) return 10;
    if (photoCount <= 18) return 14;
    if (photoCount <= 26) return 18;
    return 24;
  }

  List<AiTemplateSlot> _premiumTemplateSlotsFor(
    AlbumTheme theme,
    int pageCount,
    List<StorySection> sections,
  ) {
    final slots = <AiTemplateSlot>[];
    slots.add(
      _slot(
        'cover-hero',
        0,
        'cover',
        _coverHintFor(theme),
        left: 0.08,
        top: 0.08,
        width: 0.84,
        height: 0.56,
        imageTemplate: _coverImageTemplateFor(theme),
        imageBackground: _premiumImageBackgroundFor(theme, isCover: true),
        emphasis: 1.7,
      ),
    );

    for (var page = 1; page <= pageCount; page += 1) {
      final section = page - 1 < sections.length ? sections[page - 1] : null;
      final pattern = _pagePatternFor(theme, page);
      for (var index = 0; index < pattern.length; index += 1) {
        final spec = pattern[index];
        slots.add(
          _slot(
            'p$page-${spec.role}-$index',
            page,
            spec.role,
            _slotHintFor(theme, spec.role, section),
            left: spec.left,
            top: spec.top,
            width: spec.width,
            height: spec.height,
            rotation: spec.rotation,
            imageTemplate: spec.imageTemplate,
            imageBackground: _premiumImageBackgroundFor(theme),
            caption: spec.caption,
            emphasis: spec.emphasis,
          ),
        );
      }
    }
    return slots;
  }

  AiTemplateSlot _slot(
    String slotId,
    int pageIndex,
    String role,
    String hint, {
    required double left,
    required double top,
    required double width,
    required double height,
    double rotation = 0,
    String? imageTemplate,
    String? imageBackground,
    String? caption,
    double emphasis = 1,
  }) {
    return AiTemplateSlot(
      slotId: slotId,
      pageIndex: pageIndex,
      role: role,
      hint: hint,
      left: left,
      top: top,
      width: width,
      height: height,
      rotation: rotation,
      imageTemplate: imageTemplate,
      imageBackground: imageBackground,
      caption: caption,
      emphasis: emphasis,
    );
  }

  List<_SlotSpec> _pagePatternFor(AlbumTheme theme, int page) {
    final phase = page % 4;
    return switch (theme) {
      AlbumTheme.travel => switch (phase) {
        1 => const [
          _SlotSpec(0.06, 0.26, 0.60, 0.38, 'landscape', '4:3', emphasis: 1.35),
          _SlotSpec(0.69, 0.17, 0.25, 0.25, 'detail', '1:1', caption: 'detail'),
          _SlotSpec(
            0.53,
            0.68,
            0.36,
            0.20,
            'panorama',
            '16:9',
            caption: 'place',
          ),
        ],
        2 => const [
          _SlotSpec(
            0.12,
            0.13,
            0.76,
            0.42,
            'landscape',
            '16:9',
            emphasis: 1.55,
          ),
          _SlotSpec(0.16, 0.63, 0.29, 0.24, 'detail', '1:1'),
          _SlotSpec(0.53, 0.61, 0.30, 0.27, 'portrait', '3:4'),
        ],
        3 => const [
          _SlotSpec(0.08, 0.18, 0.38, 0.56, 'portrait', '3:4', emphasis: 1.2),
          _SlotSpec(0.52, 0.21, 0.37, 0.24, 'detail', '4:3'),
          _SlotSpec(0.52, 0.51, 0.37, 0.24, 'ending', '4:3'),
        ],
        _ => const [
          _SlotSpec(0.07, 0.20, 0.86, 0.55, 'hero', '4:3', emphasis: 1.7),
        ],
      },
      AlbumTheme.family => switch (phase) {
        1 => const [
          _SlotSpec(0.10, 0.18, 0.36, 0.36, 'together', '1:1'),
          _SlotSpec(0.54, 0.18, 0.36, 0.36, 'portrait', '1:1'),
          _SlotSpec(0.18, 0.62, 0.64, 0.24, 'detail', '4:3'),
        ],
        2 => const [
          _SlotSpec(0.12, 0.15, 0.76, 0.52, 'hero', '4:3', emphasis: 1.5),
        ],
        _ => const [
          _SlotSpec(0.09, 0.17, 0.38, 0.58, 'portrait', '3:4'),
          _SlotSpec(0.53, 0.19, 0.36, 0.25, 'detail', '4:3'),
          _SlotSpec(0.53, 0.50, 0.36, 0.25, 'together', '4:3'),
        ],
      },
      AlbumTheme.baby => switch (phase) {
        1 => const [
          _SlotSpec(0.19, 0.13, 0.62, 0.48, 'portrait', '1:1', emphasis: 1.45),
          _SlotSpec(0.14, 0.68, 0.28, 0.20, 'detail', '1:1'),
          _SlotSpec(0.58, 0.68, 0.28, 0.20, 'detail', '1:1'),
        ],
        _ => const [
          _SlotSpec(0.11, 0.16, 0.34, 0.50, 'portrait', '3:4'),
          _SlotSpec(0.52, 0.18, 0.37, 0.24, 'detail', '4:3'),
          _SlotSpec(0.52, 0.50, 0.31, 0.31, 'daily', '1:1'),
        ],
      },
      AlbumTheme.couple => switch (phase) {
        1 => const [
          _SlotSpec(0.10, 0.18, 0.80, 0.48, 'hero', '4:3', emphasis: 1.6),
          _SlotSpec(0.19, 0.72, 0.27, 0.20, 'detail', '1:1', rotation: -1.5),
          _SlotSpec(0.55, 0.70, 0.27, 0.20, 'detail', '1:1', rotation: 1.2),
        ],
        _ => const [
          _SlotSpec(0.12, 0.14, 0.34, 0.58, 'portrait', '3:4', rotation: -1),
          _SlotSpec(0.54, 0.22, 0.34, 0.48, 'portrait', '3:4', rotation: 1),
        ],
      },
      _ => switch (phase) {
        1 => const [
          _SlotSpec(0.10, 0.16, 0.80, 0.48, 'hero', '4:3', emphasis: 1.45),
          _SlotSpec(0.18, 0.71, 0.26, 0.18, 'detail', '1:1'),
          _SlotSpec(0.56, 0.71, 0.26, 0.18, 'detail', '1:1'),
        ],
        2 => const [
          _SlotSpec(0.12, 0.15, 0.33, 0.54, 'portrait', '3:4'),
          _SlotSpec(0.52, 0.18, 0.36, 0.24, 'detail', '4:3'),
          _SlotSpec(0.52, 0.49, 0.36, 0.24, 'daily', '4:3'),
        ],
        _ => const [
          _SlotSpec(0.09, 0.19, 0.82, 0.54, 'hero', '4:3', emphasis: 1.5),
        ],
      },
    };
  }

  String _coverHintFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행의 장소감이 가장 크게 느껴지는 대표 컷',
      AlbumTheme.family => '가족이 함께 보이는 가장 따뜻한 장면',
      AlbumTheme.baby => '표정과 성장감이 또렷한 메인 사진',
      AlbumTheme.couple => '둘의 분위기를 한 번에 보여주는 표지 컷',
      AlbumTheme.birthday => '축하 분위기가 가장 강한 대표 장면',
      AlbumTheme.friends => '함께한 에너지가 잘 보이는 단체/하이라이트 컷',
      AlbumTheme.daily => '하루의 온도가 느껴지는 가장 조용한 장면',
      AlbumTheme.custom => '앨범의 분위기를 정하는 대표 사진',
    };
  }

  String _slotHintFor(AlbumTheme theme, String role, StorySection? section) {
    final sectionPrefix = section == null ? '' : '${section.title}에 어울리는 ';
    return switch (role) {
      'hero' => '${sectionPrefix}가장 크게 보여줄 대표 사진',
      'panorama' => '${sectionPrefix}공간감이 살아나는 넓은 사진',
      'portrait' => '${sectionPrefix}표정이나 인물이 또렷한 세로 사진',
      'detail' => '${sectionPrefix}작은 디테일이나 분위기 컷',
      'ending' => '${sectionPrefix}앨범을 닫는 여운 있는 장면',
      'together' => '${sectionPrefix}함께 있는 순간이 잘 보이는 사진',
      'daily' => '${sectionPrefix}일상의 질감이 느껴지는 컷',
      _ => '${sectionPrefix}${_themeLabel(theme)} 흐름에 맞는 사진',
    };
  }

  String _coverImageTemplateFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.baby || AlbumTheme.family => '1:1',
      AlbumTheme.couple => 'polaroid',
      _ => '4:3',
    };
  }

  String _premiumImageBackgroundFor(AlbumTheme theme, {bool isCover = false}) {
    return switch (theme) {
      AlbumTheme.family => isCover ? 'soft-shadow' : 'mat',
      AlbumTheme.baby => 'pastel',
      AlbumTheme.couple => isCover ? 'warm-paper' : 'polaroid',
      AlbumTheme.birthday => 'sticker',
      AlbumTheme.friends => 'film',
      AlbumTheme.daily => 'soft-shadow',
      AlbumTheme.travel || AlbumTheme.custom => isCover ? 'mat' : 'soft-shadow',
    };
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
      AlbumTheme.travel => '여행의 첫 장면',
      AlbumTheme.couple => '둘의 시작 장면',
      AlbumTheme.family => '함께한 시작',
      AlbumTheme.baby => '성장의 시작',
      AlbumTheme.birthday => '축하의 시작',
      AlbumTheme.friends => '우리의 시작',
      AlbumTheme.daily => '하루의 시작',
      AlbumTheme.custom => '이야기의 시작',
    };
  }

  String _sectionEndingTitleFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '돌아보고 싶은 마무리',
      AlbumTheme.birthday => '축하의 마무리',
      _ => '마지막 장면',
    };
  }

  String _sectionStartDescriptionFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '출발의 설렘과 장소 분위기가 보이는 사진을 앞쪽에 뒀어요.',
      _ => '앨범의 첫 인상이 되는 대표 장면이에요.',
    };
  }

  String _sectionMiddleDescriptionFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '날짜 흐름에 맞춰 여행의 장면이 자연스럽게 이어지도록 묶었어요.',
      _ => '날짜별로 자연스럽게 이어지는 장면을 묶었어요.',
    };
  }

  String _sectionEndingDescriptionFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '앨범 끝에 두면 여운이 남는 장면을 뒤쪽에 배치했어요.',
      _ => '앨범을 닫는 느낌의 사진을 뒤쪽에 배치해요.',
    };
  }

  List<String> _curationNotesFor({
    required AlbumTheme theme,
    required List<RecommendedPhoto> selected,
    required List<ExcludedPhoto> excluded,
    required List<PhotoCandidate> candidates,
  }) {
    final notes = <String>[];
    final selectedDays = selected
        .map((photo) => photo.candidate.dayKey)
        .toSet();
    if (selectedDays.length >= 2) {
      notes.add('날짜가 이어지는 장면을 앞·중간·마지막 흐름으로 나눴어요.');
    } else {
      notes.add('한 날짜 안에서도 시간대별 대표 장면이 겹치지 않게 골랐어요.');
    }

    final screenshotCount = excluded
        .where(
          (photo) => photo.reasons.any(
            (reason) => reason.type == AiCurationReasonType.screenshotExcluded,
          ),
        )
        .length;
    if (screenshotCount > 0) {
      notes.add('스크린샷처럼 보이는 사진 $screenshotCount장은 초안에서 제외했어요.');
    }

    final burstGroupCount = _burstGroupCount(candidates);
    if (burstGroupCount > 0) {
      notes.add('연속 촬영처럼 가까운 사진은 대표 장면 위주로 남겼어요.');
    }

    if (selected.any(
      (photo) => _albumNameMatchesTheme(photo.candidate.albumName, theme),
    )) {
      notes.add('선택한 주제와 맞는 앨범/폴더 이름의 사진을 조금 더 우선했어요.');
    }

    final themeRatioNote = switch (theme) {
      AlbumTheme.travel => '여행 앨범은 장소감이 보이는 가로 사진을 우선 확인했어요.',
      AlbumTheme.couple ||
      AlbumTheme.family ||
      AlbumTheme.baby => '인물 중심 앨범은 표정이 잘 보이는 세로 사진을 우선 확인했어요.',
      AlbumTheme.birthday ||
      AlbumTheme.friends ||
      AlbumTheme.daily ||
      AlbumTheme.custom => '사진 비율이 한쪽으로 치우치지 않게 섞었어요.',
    };
    notes.add(themeRatioNote);

    return notes.take(4).toList(growable: false);
  }

  int _burstGroupCount(List<PhotoCandidate> candidates) {
    return _timeClusters(
      candidates,
    ).where((cluster) => cluster.length > 1).length;
  }

  String _summaryFor(
    AlbumTheme theme,
    int selectedCount,
    int excludedCount,
    int sectionCount,
  ) {
    return '기기 안에서만 사진 정보를 살펴봤어요. 날짜 흐름과 비슷한 장면을 대표 컷 중심으로 정리해 '
        '$sectionCount개 흐름으로 나누고, ${_themeLabel(theme)} 앨범에 어울리는 '
        '$selectedCount장을 먼저 골랐어요. $excludedCount장은 편집 단계에서 다시 추가할 수 있어요.';
  }

  String _themeLabel(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행',
      AlbumTheme.couple => '커플',
      AlbumTheme.family => '가족',
      AlbumTheme.baby => '아기/성장',
      AlbumTheme.birthday => '생일/기념일',
      AlbumTheme.friends => '친구',
      AlbumTheme.daily => '일상',
      AlbumTheme.custom => '맞춤',
    };
  }
}

enum _TimeBucket { morning, afternoon, evening }

class _SlotSpec {
  const _SlotSpec(
    this.left,
    this.top,
    this.width,
    this.height,
    this.role,
    this.imageTemplate, {
    this.rotation = 0,
    this.caption,
    this.emphasis = 1,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String role;
  final String imageTemplate;
  final double rotation;
  final String? caption;
  final double emphasis;
}
