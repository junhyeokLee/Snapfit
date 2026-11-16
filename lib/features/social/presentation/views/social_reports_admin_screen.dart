import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../data/social_repository.dart' show socialActionMessage;
import '../../../profile/presentation/views/admin_point_shop_management_screen.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_page_header.dart';
import '../widgets/social_report_sheet.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_widgets.dart';

class SocialReportsAdminScreen extends ConsumerStatefulWidget {
  const SocialReportsAdminScreen({super.key});

  @override
  ConsumerState<SocialReportsAdminScreen> createState() =>
      _SocialReportsAdminScreenState();
}

class _SocialReportsAdminScreenState
    extends ConsumerState<SocialReportsAdminScreen> {
  final _reports = <SocialReport>[];
  String _status = 'open';
  String? _error, _resolvingId;
  int _nextOffset = 0, _generation = 0, _mutationRevision = 0;
  bool _hasMore = true, _loading = false;
  DialogRoute<bool>? _decisionRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
  }

  @override
  void dispose() {
    _generation++;
    _dismissDecision();
    super.dispose();
  }

  bool _current(String actor, int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(socialCurrentUserIdProvider) == actor &&
      ref.read(pointShopAdminAccessProvider);

  void _dismissDecision() {
    final route = _decisionRoute;
    _decisionRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  void _changedSession() {
    _dismissDecision();
    _generation++;
    _mutationRevision++;
    setState(() {
      _reports.clear();
      _nextOffset = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
      _resolvingId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null || !ref.read(pointShopAdminAccessProvider)) return;
    if (_loading && !reset) return;
    if (reset) _generation++;
    final generation = _generation;
    final offset = reset ? 0 : _nextOffset;
    final status = _status;
    setState(() {
      if (reset) {
        _reports.clear();
        _nextOffset = 0;
        _hasMore = true;
      }
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(socialRepositoryProvider)
          .fetchAdminReportsPage(status: status, offset: offset);
      if (!_current(actor, generation) || status != _status) return;
      setState(() {
        final seen = _reports.map((report) => report.id).toSet();
        _reports.addAll(
          page.items.where(
            (report) => report.status == status && seen.add(report.id),
          ),
        );
        _nextOffset = page.nextOffset;
        _hasMore = page.hasMore && page.nextOffset > offset;
      });
    } catch (error) {
      if (_current(actor, generation)) {
        setState(
          () => _error = socialActionMessage(
            error,
            fallback: '신고 목록을 불러오지 못했어요. 권한과 연결 상태를 확인해 주세요.',
          ),
        );
      }
    } finally {
      if (_current(actor, generation)) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(SocialReport report, String decision) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null ||
        _resolvingId != null ||
        !ref.read(pointShopAdminAccessProvider))
      return;
    final generation = _generation;
    final mutation = ++_mutationRevision;
    setState(() => _resolvingId = report.id);
    try {
      final route = DialogRoute<bool>(
        context: context,
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            ref.watch(pointShopAdminAccessProvider);
            ref.watch(socialCurrentUserIdProvider);
            if (!_current(actor, generation)) return const SizedBox.shrink();
            return AlertDialog(
              title: Text(
                decision == 'hide' ? '신고된 내용을 숨길까요?' : '이 신고를 기각할까요?',
              ),
              content: Text(
                decision == 'hide'
                    ? '신고된 게시물이나 댓글을 공개 화면에서 숨기고 처리 내역을 남겨요.'
                    : '공개 상태를 유지하고 신고를 처리 완료해요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const ValueKey('social-report-admin-confirm'),
                  onPressed: () => Navigator.pop(context, true),
                  style: SocialStyle.primary(context),
                  child: Text(decision == 'hide' ? '숨김 처리' : '기각 처리'),
                ),
              ],
            );
          },
        ),
      );
      _decisionRoute = route;
      final confirmed = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (identical(_decisionRoute, route)) _decisionRoute = null;
      if (confirmed != true || !_current(actor, generation)) return;
      await ref
          .read(socialRepositoryProvider)
          .resolveReport(
            id: report.id,
            decision: decision,
            expectedRevision: report.revision,
          );
      if (!_current(actor, generation)) return;
      invalidateSocial(ref);
      await _load(reset: true);
    } catch (error) {
      if (_current(actor, generation)) {
        socialError(
          context,
          message: socialActionMessage(
            error,
            fallback: '처리 결과를 확인하지 못했어요. 목록을 새로 확인한 뒤 다시 시도해 주세요.',
          ),
        );
        await _load(reset: true);
      }
    } finally {
      if (mounted &&
          mutation == _mutationRevision &&
          ref.read(socialCurrentUserIdProvider) == actor) {
        setState(() => _resolvingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(socialCurrentUserIdProvider);
    final admin = ref.watch(pointShopAdminAccessProvider);
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) _changedSession();
    });
    ref.listen(pointShopAdminAccessProvider, (previous, next) {
      if (previous != next) _changedSession();
    });
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: const SocialPageHeader(title: '신고 관리'),
        body: actor == null || !admin
            ? const Center(child: Text('신고를 확인할 관리자 권한이 필요해요.'))
            : SocialContent(
                maxWidth: 960,
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const {
                            'open': '검토 대기',
                            'hidden': '숨김 처리',
                            'dismissed': '기각',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _status == entry.key,
                              onSelected: _resolvingId != null
                                  ? null
                                  : (_) {
                                      if (_status == entry.key) return;
                                      setState(() => _status = entry.key);
                                      _load(reset: true);
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (final report in _reports) _reportCard(report),
                      if (_loading)
                        const SocialLoading(message: '신고를 확인하고 있어요.'),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: ExperienceFormStyle.text(context, 13),
                        ),
                        TextButton(
                          onPressed: () => _load(reset: _reports.isEmpty),
                          child: const Text('신고 다시 불러오기'),
                        ),
                      ] else if (!_loading && _reports.isEmpty)
                        const SocialEmpty(
                          title: '이 상태의 신고가 없어요.',
                          message: '새로운 신고가 접수되면 이곳에서 확인할 수 있어요.',
                        ),
                      if (!_loading && _error == null && _hasMore)
                        OutlinedButton(
                          key: const ValueKey('social-report-admin-more'),
                          onPressed: () => _load(),
                          child: const Text('신고 더 보기'),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _reportCard(SocialReport report) => Container(
    key: ValueKey('social-report-admin-${report.id}'),
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      border: Border.all(color: SocialStyle.line(context)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          socialReportReasonLabels[report.reason] ?? report.reason,
          style: ExperienceFormStyle.text(context, 17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '${report.targetKind == 'comment'
              ? '댓글'
              : report.targetKind == 'user'
              ? '사용자'
              : '게시물'} · ${socialDate(report.createdAt)}',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 6),
        SelectableText(
          report.targetId,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        if (report.targetPreview case final preview?) ...[
          const SizedBox(height: 12),
          Text(
            '신고된 내용',
            style: ExperienceFormStyle.text(
              context,
              13,
              weight: FontWeight.w600,
            ),
          ),
          if (preview['title'] case final String title) ...[
            const SizedBox(height: 6),
            Text(title, style: ExperienceFormStyle.text(context, 15)),
          ],
          if ((preview['body'] ?? preview['caption'] ?? preview['bio'])
              case final String text) ...[
            const SizedBox(height: 6),
            Text(text, style: ExperienceFormStyle.text(context, 14)),
          ],
        ],
        if (report.targetWorkId != null ||
            report.targetKind == 'work' ||
            report.targetKind == 'user')
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: ValueKey('social-report-admin-open-${report.id}'),
              onPressed: () => report.targetKind == 'user'
                  ? openSocialProfile(context, report.targetId)
                  : openSocialWork(
                      context,
                      report.targetWorkId ?? report.targetId,
                      showComments: report.targetKind == 'comment',
                    ),
              child: const Text('대상 확인하기'),
            ),
          ),
        if (report.resolutionNote?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            report.resolutionNote!,
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        ],
        if (report.details.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(report.details, style: ExperienceFormStyle.text(context, 14)),
        ],
        if (report.status == 'open') ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: ValueKey('social-report-admin-hide-${report.id}'),
                onPressed: _resolvingId != null
                    ? null
                    : () => _resolve(report, 'hide'),
                child: const Text('내용 숨기기'),
              ),
              TextButton(
                key: ValueKey('social-report-admin-dismiss-${report.id}'),
                onPressed: _resolvingId != null
                    ? null
                    : () => _resolve(report, 'dismiss'),
                child: const Text('신고 기각'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
