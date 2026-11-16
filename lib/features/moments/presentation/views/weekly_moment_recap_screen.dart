import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_extensions.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import '../providers/private_moment_archive_providers.dart';
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
  bool _loadingChoices = true, _savingChoices = false, _saved = false;
  String? _choiceError;
  final _selected = <String>[];
  List<String> _persisted = const [];
  int _identity = 0;
  StreamSubscription<String?>? _authChanges;
  StreamSubscription<int>? _archiveSession;
  PrivateMomentArchiveRepository? _archive;
  ProviderSubscription<AsyncValue<List<String>>>? _choiceSubscription;
  int _choiceLoadGeneration = 0;

  List<({MomentRecord record, MomentPhoto photo})> get _photos {
    final records =
        widget.records
            .where(
              (record) =>
                  !record.recordDate.isBefore(momentDate(widget.weekStart)) &&
                  !record.recordDate.isAfter(momentDate(widget.today)) &&
                  record.recordDate.isBefore(
                    momentDate(widget.weekStart).add(const Duration(days: 7)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    final seen = <String>{};
    return [
      for (final record in records)
        for (final photo in record.photos)
          if (seen.add(photo.id)) (record: record, photo: photo),
    ];
  }

  @override
  void initState() {
    super.initState();
    final repository = ref.read(momentsRepositoryProvider);
    _accountChanged = repository.currentUserId != widget.ownerUserId;
    _authChanges = repository.authChanges.listen((owner) {
      if (owner != widget.ownerUserId) _lockSession();
    }, onError: (Object _, StackTrace __) => _lockSession());
    unawaited(_loadChoices());
  }

  void _lockSession() {
    if (!mounted || _accountChanged) return;
    setState(() {
      _accountChanged = true;
      _identity++;
      _choiceLoadGeneration++;
      _choiceSubscription?.close();
      _choiceSubscription = null;
      _selected.clear();
      _persisted = const [];
      _choiceError = null;
      _savingChoices = false;
    });
  }

  bool _current(int identity) =>
      mounted &&
      !_accountChanged &&
      _identity == identity &&
      ref.read(momentsCurrentUserIdProvider) == widget.ownerUserId;

  Future<void> _loadChoices({bool refresh = false}) async {
    final identity = _identity;
    final generation = ++_choiceLoadGeneration;
    if (!_current(identity)) return;
    setState(() {
      _loadingChoices = true;
      _choiceError = null;
    });
    try {
      final archive = ref.read(privateMomentArchiveRepositoryProvider);
      _archive = archive;
      _archiveSession ??= archive.sessionChanges.listen(
        (_) => _lockSession(),
        onError: (Object _, StackTrace __) => _lockSession(),
      );
      final revision = archive.sessionRevision;
      final query = MomentWeeklyChoicesQuery(
        widget.ownerUserId,
        widget.weekStart,
      );
      _choiceSubscription?.close();
      _choiceSubscription = ref.listenManual(
        weeklyMomentPhotoChoicesProvider(query),
        (_, __) {},
      );
      final choices = await (refresh
          ? ref.refresh(weeklyMomentPhotoChoicesProvider(query).future)
          : ref.read(weeklyMomentPhotoChoicesProvider(query).future));
      if (!_current(identity) ||
          generation != _choiceLoadGeneration ||
          revision != archive.sessionRevision)
        return;
      final available = _photos.map((item) => item.photo.id).toSet();
      final current = choices
          .where(available.contains)
          .toSet()
          .take(3)
          .toList();
      setState(() {
        _selected
          ..clear()
          ..addAll(current);
        _persisted = List.of(current);
        _loadingChoices = false;
        _saved = current.isNotEmpty;
      });
    } catch (_) {
      if (_current(identity) && generation == _choiceLoadGeneration)
        setState(() {
          _loadingChoices = false;
          _choiceError = '이전에 고른 후보를 불러오지 못했어요.';
        });
    }
  }

  void _toggleChoice(String photoId) {
    if (_accountChanged ||
        _loadingChoices ||
        _savingChoices ||
        _choiceError != null)
      return;
    if (!_selected.contains(photoId) && _selected.length == 3) {
      context.showSnack('이번 주에는 세 장까지 고를 수 있어요.');
      return;
    }
    setState(() {
      if (_selected.contains(photoId)) {
        _selected.remove(photoId);
      } else {
        _selected.add(photoId);
      }
      _saved = false;
    });
  }

  Future<void> _saveChoices() async {
    final identity = _identity;
    final archive = _archive;
    if (!_current(identity) ||
        archive == null ||
        _loadingChoices ||
        _savingChoices ||
        _choiceError != null)
      return;
    if (_selected.isEmpty && _persisted.isEmpty) return;
    final revision = archive.sessionRevision;
    final selected = List<String>.of(_selected);
    setState(() {
      _savingChoices = true;
      _choiceError = null;
    });
    try {
      await archive.saveWeeklyPhotoChoices(
        ownerId: widget.ownerUserId,
        weekStart: widget.weekStart,
        photoIds: selected,
      );
      if (!_current(identity) || revision != archive.sessionRevision) return;
      ref.invalidate(
        weeklyMomentPhotoChoicesProvider(
          MomentWeeklyChoicesQuery(widget.ownerUserId, widget.weekStart),
        ),
      );
      for (final month
          in _photos
              .map((item) => momentMonth(item.record.recordDate))
              .toSet()) {
        ref.invalidate(
          monthlyMomentPhotoChoicesProvider(
            MomentPhotoChoicesQuery(widget.ownerUserId, month),
          ),
        );
      }
      setState(() {
        _persisted = selected;
        _saved = true;
      });
    } catch (_) {
      if (_current(identity))
        setState(() {
          _choiceError = '후보를 저장하지 못했어요. 고른 사진은 그대로 있어요.';
        });
    } finally {
      if (_current(identity)) setState(() => _savingChoices = false);
    }
  }

  Widget _choiceActions(
    List<({MomentRecord record, MomentPhoto photo})> photos,
  ) {
    final photo = photos[_index.clamp(0, photos.length - 1)].photo;
    final changed = _selected.join('\u0000') != _persisted.join('\u0000');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_choiceError != null) ...[
            Text(
              _choiceError!,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('weekly-choices-retry'),
                onPressed: _savingChoices
                    ? null
                    : () {
                        if (_archive == null ||
                            _loadingChoices ||
                            _persisted.isEmpty && _selected.isEmpty) {
                          unawaited(_loadChoices(refresh: true));
                        } else {
                          setState(() => _choiceError = null);
                          unawaited(_saveChoices());
                        }
                      },
                child: const Text('다시 시도'),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              key: ValueKey('weekly-photo-choice-${photo.id}'),
              onPressed: _loadingChoices || _savingChoices
                  ? null
                  : () => _toggleChoice(photo.id),
              icon: Icon(
                _selected.contains(photo.id)
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                size: 19,
              ),
              label: Text(
                _selected.contains(photo.id) ? '월간 후보에서 빼기' : '월간 앨범 후보에 담기',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadingChoices
                  ? '고른 후보를 불러오고 있어요…'
                  : '이번 주 후보 ${_selected.length} / 3',
              key: const ValueKey('weekly-choices-count'),
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('weekly-choices-save'),
              style: SocialStyle.primary(context),
              onPressed: !_loadingChoices && !_savingChoices && changed
                  ? _saveChoices
                  : null,
              child: Text(
                _savingChoices
                    ? '저장하고 있어요…'
                    : _saved && !changed
                    ? '비공개 후보로 저장됨'
                    : _selected.isEmpty && _persisted.isNotEmpty
                    ? '이번 주 후보 선택 해제'
                    : '고른 ${_selected.length}장 후보로 저장',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WeeklyMomentRecapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _lockSession();
      return;
    }
    if (_accountChanged) return;
    if (momentDate(oldWidget.weekStart) != momentDate(widget.weekStart)) {
      _identity++;
      _selected.clear();
      _persisted = const [];
      _index = 0;
      _saved = false;
      _savingChoices = false;
      if (_pages.hasClients) _pages.jumpToPage(0);
      unawaited(_loadChoices());
    } else if (!identical(oldWidget.records, widget.records)) {
      final available = _photos.map((item) => item.photo.id).toSet();
      _selected.removeWhere((id) => !available.contains(id));
      _persisted = _persisted.where(available.contains).toList();
      if (_index >= _photos.length) {
        _index = 0;
        if (_pages.hasClients) _pages.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _identity++;
    _choiceLoadGeneration++;
    _choiceSubscription?.close();
    unawaited(_authChanges?.cancel());
    unawaited(_archiveSession?.cancel());
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next && next != widget.ownerUserId) _lockSession();
    });
    final photos = _photos;
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
              icon: ExperienceIcon('Lock'),
            )
          : photos.isEmpty
          ? const SocialEmpty(
              title: '이번 주의 첫 장을 기다려요',
              message: '사진을 남기면 여기서 차분히 돌아볼 수 있어요.',
              icon: ExperienceIcon('Image'),
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
                          ExperienceIcon('Lock', size: 13, color: SocialStyle.accent(context),
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
                            cacheExtent: 800,
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
                            icon: const ExperienceIcon('ArrowLeft', size: 21),
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
                            icon: const ExperienceIcon('ArrowRight', size: 21),
                          ),
                        ],
                      ),
                    ),
                    _choiceActions(photos),
                  ],
                ),
              ),
            ),
    );
  }
}
