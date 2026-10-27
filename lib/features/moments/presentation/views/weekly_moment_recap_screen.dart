import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';

/// An untimed, private look back. Dates come from the server's current week,
/// rather than the journal month currently selected by the user.
class WeeklyMomentRecapScreen extends ConsumerStatefulWidget {
  const WeeklyMomentRecapScreen({
    super.key,
    required this.today,
    required this.weekStart,
    required this.records,
    required this.ownerUserId,
  });
  final DateTime today, weekStart;
  final List<MomentRecord> records;
  final String ownerUserId;

  @override
  ConsumerState<WeeklyMomentRecapScreen> createState() =>
      _WeeklyMomentRecapScreenState();
}

class _WeeklyMomentRecapScreenState
    extends ConsumerState<WeeklyMomentRecapScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _accountChanged = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) _accountChanged = true;
    });
    final records =
        widget.records
            .where(
              (record) =>
                  !record.recordDate.isBefore(widget.weekStart) &&
                  !record.recordDate.isAfter(widget.today),
            )
            .toList()
          ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    final photos = [
      for (final record in records)
        for (final photo in record.photos) (record: record, photo: photo),
    ];
    final end = widget.weekStart.add(const Duration(days: 6));
    return Scaffold(
      backgroundColor: SocialStyle.background(context),
      appBar: const ExperienceHeader(
        title: '이번 주 돌아보기',
        showNotifications: false,
      ),
      body: _accountChanged || owner != widget.ownerUserId
          ? const SocialEmpty(
              title: '계정이 변경되었어요',
              message: '현재 계정의 기록에서 다시 열어 주세요.',
              icon: Icons.lock_outline_rounded,
            )
          : photos.isEmpty
          ? const SocialEmpty(
              title: '이번 주의 첫 장을 기다려요',
              message: '사진을 남기면 여기서 차분히 돌아볼 수 있어요.',
              icon: Icons.photo_library_outlined,
            )
          : SafeArea(
              top: false,
              child: SocialContent(
                maxWidth: 720,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.weekStart.month}.${widget.weekStart.day} — ${end.month}.${end.day}',
                              style: ExperienceFormStyle.text(
                                context,
                                14,
                                weight: FontWeight.w600,
                              ).copyWith(letterSpacing: .3),
                            ),
                          ),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: SocialStyle.accent(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '나만 보는 회고',
                            style: ExperienceFormStyle.text(
                              context,
                              11,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('moments-week-recap-pages'),
                        controller: _pages,
                        itemCount: photos.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, index) {
                          final item = photos[index];
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: MomentPhotoView(
                                  photo: item.photo,
                                  aspectRatio: momentPhotoAspect(item.photo),
                                  label:
                                      '${momentDateLabel(item.record.recordDate)} 돌아보기 사진 ${index + 1}',
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                momentDateLabel(item.record.recordDate),
                                style: ExperienceFormStyle.text(
                                  context,
                                  13,
                                  color: SocialStyle.accent(context),
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.record.caption.trim().isEmpty
                                    ? '말없이 남겨도, 기억은 여기 있어요.'
                                    : item.record.caption,
                                style: ExperienceFormStyle.text(
                                  context,
                                  19,
                                  weight: FontWeight.w500,
                                ).copyWith(height: 1.7, letterSpacing: -.4),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '이전 돌아보기 사진',
                            onPressed: _index == 0
                                ? null
                                : () => _pages.previousPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 21,
                            ),
                          ),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                '${_index + 1} / ${photos.length}',
                                textAlign: TextAlign.center,
                                style: ExperienceFormStyle.text(
                                  context,
                                  13,
                                  secondary: true,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '다음 돌아보기 사진',
                            onPressed: _index == photos.length - 1
                                ? null
                                : () => _pages.nextPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  ),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
