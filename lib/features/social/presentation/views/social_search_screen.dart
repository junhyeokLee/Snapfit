import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/social_models.dart';
import '../../domain/social_topics.dart';
import '../providers/social_providers.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_page_header.dart';
import '../widgets/social_profile_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

final socialWorkSearchProvider = FutureProvider.autoDispose
    .family<SocialWorkPage, SocialSearchQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .searchPage(query.query, offset: query.offset, limit: query.limit);
    });
final socialProfileSearchProvider = FutureProvider.autoDispose
    .family<SocialProfilePage, SocialSearchQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .searchProfilesPage(
            query.query,
            offset: query.offset,
            limit: query.limit,
          );
    });

class SocialSearchScreen extends ConsumerStatefulWidget {
  const SocialSearchScreen({super.key});
  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen> {
  final _controller = TextEditingController();
  final _recent = <String>[];
  String _query = '';
  bool _users = false;
  final _workOffsets = <int>[0];
  final _profileOffsets = <int>[0];
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search([String? text]) {
    final query = (text ?? _controller.text).trim();
    _controller.text = query;
    if (query.isNotEmpty) _refreshResults(query);
    setState(() {
      _query = query;
      _workOffsets
        ..clear()
        ..add(0);
      _profileOffsets
        ..clear()
        ..add(0);
      if (query.isNotEmpty) {
        _recent.remove(query);
        _recent.insert(0, query);
      }
      if (_recent.length > 6) _recent.removeLast();
    });
  }

  void _refreshResults(String query) {
    for (final offset in _workOffsets) {
      ref.invalidate(
        socialWorkSearchProvider(SocialSearchQuery(query, offset: offset)),
      );
    }
    for (final offset in _profileOffsets) {
      ref.invalidate(
        socialProfileSearchProvider(SocialSearchQuery(query, offset: offset)),
      );
    }
  }

  Future<void> _openResult(Future<Object?> Function() open) async {
    final query = _query;
    final actor = ref.read(socialCurrentUserIdProvider);
    await open();
    // A work can be withdrawn or its creator blocked on the destination.
    // Search providers are separate from the feed's invalidation scope.
    if (mounted &&
        query.isNotEmpty &&
        _query == query &&
        ref.read(socialCurrentUserIdProvider) == actor) {
      _refreshResults(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next && mounted)
        setState(() {
          _recent.clear();
          _query = '';
          _controller.clear();
          _users = false;
          _workOffsets
            ..clear()
            ..add(0);
          _profileOffsets
            ..clear()
            ..add(0);
        });
    });
    final workPages = [
      if (_query.isNotEmpty)
        for (final offset in _workOffsets)
          ref.watch(
            socialWorkSearchProvider(SocialSearchQuery(_query, offset: offset)),
          ),
    ];
    final profilePages = [
      if (_query.isNotEmpty)
        for (final offset in _profileOffsets)
          ref.watch(
            socialProfileSearchProvider(
              SocialSearchQuery(_query, offset: offset),
            ),
          ),
    ];
    final shownWorks = <String>{};
    final shownProfiles = <String>{};
    return SocialWebFrame(
      child: Scaffold(
        appBar: const SocialPageHeader(title: '검색'),
        backgroundColor: SocialStyle.background(context),
        body: SocialContent(
          child: ListView(
            cacheExtent: 800,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              TextField(
                controller: _controller,
                maxLength: 80,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  labelText: '기록·앨범·사용자 검색',
                  counterText: '',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '검색어 지우기',
                        icon: const ExperienceIcon('X'),
                        onPressed: () => _search(''),
                      ),
                      IconButton(
                        tooltip: '검색하기',
                        icon: const ExperienceIcon('Search'),
                        onPressed: _search,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_query.isEmpty) ...[
                Text(
                  '어떤 기록을 찾고 있나요?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final topic in socialTopicLabels)
                      ActionChip(
                        label: Text(topic),
                        onPressed: () => _search(topic),
                      ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(child: Text('최근 검색')),
                    if (_recent.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_recent.clear),
                        child: const Text('전체 지우기'),
                      ),
                  ],
                ),
                for (final query in _recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const ExperienceIcon('History'),
                    title: Text(query),
                    onTap: () => _search(query),
                    trailing: IconButton(
                      tooltip: '$query 검색 기록 삭제',
                      onPressed: () => setState(() => _recent.remove(query)),
                      icon: const ExperienceIcon('X'),
                    ),
                  ),
              ] else ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('기록·앨범')),
                    ButtonSegment(value: true, label: Text('사용자')),
                  ],
                  selected: {_users},
                  onSelectionChanged: (value) =>
                      setState(() => _users = value.first),
                ),
                const SizedBox(height: 20),
                Semantics(liveRegion: true, child: Text('‘$_query’ 검색 결과')),
                const SizedBox(height: 20),
                if (_users)
                  for (var index = 0; index < profilePages.length; index++)
                    _results(
                      profilePages[index],
                      (page) => Column(
                        children: [
                          _people(
                            page.items
                                .where(
                                  (person) => shownProfiles.add(person.userId),
                                )
                                .toList(),
                            showEmpty: index == 0,
                          ),
                          if (index == _profileOffsets.length - 1 &&
                              page.hasMore &&
                              page.nextOffset > _profileOffsets[index])
                            _loadMore(
                              '사용자 더 보기',
                              _profileOffsets,
                              _profileOffsets[index],
                              page.nextOffset,
                            ),
                        ],
                      ),
                      () => ref.invalidate(
                        socialProfileSearchProvider(
                          SocialSearchQuery(
                            _query,
                            offset: _profileOffsets[index],
                          ),
                        ),
                      ),
                    )
                else
                  for (var index = 0; index < workPages.length; index++)
                    _results(
                      workPages[index],
                      (page) => Column(
                        children: [
                          _works(
                            page.items
                                .where((work) => shownWorks.add(work.id))
                                .toList(),
                            showEmpty: index == 0,
                            onRetry: () => ref.invalidate(
                              socialWorkSearchProvider(
                                SocialSearchQuery(
                                  _query,
                                  offset: _workOffsets[index],
                                ),
                              ),
                            ),
                          ),
                          if (index == _workOffsets.length - 1 &&
                              page.hasMore &&
                              page.nextOffset > _workOffsets[index])
                            _loadMore(
                              '기록·앨범 더 보기',
                              _workOffsets,
                              _workOffsets[index],
                              page.nextOffset,
                            ),
                        ],
                      ),
                      () => ref.invalidate(
                        socialWorkSearchProvider(
                          SocialSearchQuery(
                            _query,
                            offset: _workOffsets[index],
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _results<T>(
    AsyncValue<T> result,
    Widget Function(T) data,
    VoidCallback onRetry,
  ) => result.when(
    // Preserve each image's bounded recovery state while its signature renews.
    skipLoadingOnRefresh: true,
    loading: () =>
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    error: (_, _) => SocialFailure(onRetry: onRetry),
    data: data,
  );

  Widget _loadMore(String label, List<int> offsets, int current, int next) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: OutlinedButton(
          onPressed: () {
            if (offsets.last != current || offsets.contains(next)) return;
            setState(() => offsets.add(next));
          },
          child: Text(label),
        ),
      );

  Widget _works(
    List<SocialWork> works, {
    required bool showEmpty,
    required VoidCallback onRetry,
  }) => works.isEmpty
      ? showEmpty
            ? const SocialEmpty(
                title: '찾는 기록이나 앨범이 아직 없어요.',
                message: '다른 제목이나 주제로 찾아보세요.',
              )
            : const SizedBox.shrink()
      : LayoutBuilder(
          builder: (context, bounds) {
            final columns = bounds.maxWidth >= 600 ? 3 : 2;
            final width = (bounds.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 20,
              children: [
                for (final work in works)
                  SizedBox(
                    key: ValueKey(work.id),
                    width: width,
                    child: SocialWorkTile(
                      work: work,
                      onRetry: onRetry,
                      onTap: () =>
                          _openResult(() => openSocialWork(context, work.id)),
                    ),
                  ),
              ],
            );
          },
        );
  Widget _people(List<SocialProfile> people, {required bool showEmpty}) =>
      people.isEmpty
      ? showEmpty
            ? const SocialEmpty(
                title: '찾는 사용자가 없어요.',
                message: '닉네임이나 아이디를 확인해 주세요.',
              )
            : const SizedBox.shrink()
      : Column(
          children: [
            for (final person in people)
              ListTile(
                key: ValueKey(person.userId),
                contentPadding: EdgeInsets.zero,
                title: Text(person.displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('@${person.handle}'),
                    Text(
                      '기록 ${person.momentsCount} · 앨범 ${person.worksCount}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                leading: SocialProfileAvatar(
                  name: person.displayName,
                  imageUrl: person.avatarUrl,
                  size: 44,
                ),
                trailing: const ExperienceIcon('ChevronRight'),
                onTap: () => _openResult(
                  () => openSocialProfile(context, person.userId),
                ),
              ),
          ],
        );
}
