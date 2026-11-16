import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../data/support_inquiry_repository.dart';
import '../../domain/order_visibility_owner.dart';
import '../../domain/support_inquiry.dart';
import '../widgets/customer_web_page.dart';
import '../widgets/support_inquiry_owner_guard.dart';
import 'support_inquiry_screen.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// 내 문의를 읽고 같은 화면에서 보낸 내용을 펼쳐 확인한다.
class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  ConsumerState<SupportCenterScreen> createState() =>
      _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  late final _repository = ref.read(supportInquiryRepositoryProvider);
  final _scroll = ScrollController();
  List<SupportInquiry> _items = const [];
  String? _ownerId;
  int? _nextBeforeId;
  int _generation = 0;
  int _request = 0;
  bool _scheduled = false;
  bool _invalidated = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _failed = false;
  bool _moreFailed = false;
  bool _openingForm = false;
  bool _submitted = false;

  bool _current(String owner, int generation) =>
      mounted &&
      !_invalidated &&
      generation == _generation &&
      ref.read(visibleOrderOwnerProvider) == owner &&
      _repository.currentUserId == owner;

  void _invalidate() {
    if (_invalidated) return;
    _invalidated = true;
    _generation++;
    _items = const [];
  }

  Future<void> _load({bool more = false, bool afterSubmission = false}) async {
    final owner = _ownerId;
    final generation = _generation;
    if (owner == null || !_current(owner, generation)) return;
    if ((_loading || _loadingMore) && !afterSubmission) return;
    if (more && (!_hasMore || _nextBeforeId == null)) return;
    final request = ++_request;
    final cursor = more ? _nextBeforeId : null;
    setState(() {
      _scheduled = false;
      _loading = !more;
      _loadingMore = more;
      if (more) {
        _moreFailed = false;
      } else {
        _failed = false;
      }
    });
    try {
      final page = await _repository
          .fetchMyInquiries(ownerId: owner, beforeId: cursor, limit: 20)
          .timeout(const Duration(seconds: 25));
      if (!_current(owner, generation) || request != _request) return;
      final next = page.nextBeforeId;
      if (page.items.any((item) => item.userId != owner) ||
          (page.hasMore && (page.items.isEmpty || next == null)) ||
          (cursor != null && page.items.any((item) => item.id >= cursor))) {
        throw StateError('support_history_invalid_page');
      }
      setState(() {
        _items = more ? [..._items, ...page.items] : List.of(page.items);
        _hasMore = page.hasMore;
        _nextBeforeId = next;
        _moreFailed = false;
        _submitted = false;
      });
    } catch (_) {
      if (!_current(owner, generation) || request != _request) return;
      setState(() {
        if (more) {
          _moreFailed = true;
        } else {
          _failed = true;
        }
      });
    } finally {
      if (_current(owner, generation) && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _write() async {
    final owner = _ownerId;
    final generation = _generation;
    if (owner == null || _openingForm || !_current(owner, generation)) return;
    setState(() => _openingForm = true);
    var confirmed = false;
    final sent = await Navigator.of(context).push<bool>(
      snapFitRoute<bool>(
        page: SupportInquiryOwnerGuard(
          ownerId: owner,
          onInvalidated: _invalidate,
          child: SupportInquiryScreen(
            isOwnerCurrent: () => _current(owner, generation),
            onSubmitted: () {
              if (_current(owner, generation)) confirmed = true;
            },
          ),
        ),
      ),
    );
    if (!_current(owner, generation)) return;
    setState(() => _openingForm = false);
    // 시스템 뒤로가기는 route 결과가 null이어도 이미 확인된 접수를 유지한다.
    if (sent == true || confirmed) {
      _submitted = true;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      // 접수는 성공했다. 목록 재조회 실패를 재전송으로 연결하지 않는다.
      await _load(afterSubmission: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleOwner = ref.watch(visibleOrderOwnerProvider);
    if (_ownerId == null &&
        visibleOwner != null &&
        _repository.currentUserId == visibleOwner) {
      _ownerId = visibleOwner;
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
    final owner = _ownerId;
    if (owner == null) {
      final content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('로그인한 계정을 확인한 뒤 고객센터를 다시 열어주세요.'),
        ),
      );
      return _page(context, content);
    }
    return SupportInquiryOwnerGuard(
      ownerId: owner,
      onInvalidated: _invalidate,
      child: _page(context, _history(context)),
    );
  }

  Widget _page(BuildContext context, Widget content) {
    final current = _ownerId != null && _current(_ownerId!, _generation);
    final busy = _loading || _loadingMore || _scheduled;
    final refresh = IconButton(
      key: const ValueKey('support-history-refresh'),
      tooltip: '문의 새로고침',
      onPressed: current && !busy ? () => _load() : null,
      icon: const ExperienceIcon('RefreshCw'),
    );
    final create = FilledButton.icon(
      key: const ValueKey('support-history-new'),
      onPressed: current && !_openingForm ? _write : null,
      icon: const ExperienceIcon('PenLine', size: 19),
      label: const Text('새 문의 작성'),
    );
    if (kIsWeb) {
      return CustomerWebPage(
        title: '고객센터',
        actions: [if (current) refresh, if (current) create],
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '고객센터',
        showNotifications: false,
        actions: [if (current) refresh],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: content,
          ),
        ),
      ),
      bottomNavigationBar: current
          ? SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: SizedBox(width: double.infinity, child: create),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _history(BuildContext context) {
    if (_items.isEmpty && (_loading || _scheduled)) {
      return Center(
        child: Semantics(
          label: '문의 내역을 불러오고 있어요',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        key: const ValueKey('support-history-list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '내 문의',
                  style: ExperienceFormStyle.text(
                    context,
                    18,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading) const LinearProgressIndicator(),
                if (_failed) ...[
                  if (_submitted) const Text('문의는 접수되었어요. 목록을 다시 확인해 주세요.'),
                  _retry(
                    '문의 내역을 불러오지 못했어요',
                    'support-history-retry',
                    () => _load(),
                  ),
                ],
                if (_items.isEmpty && !_failed && !_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text('아직 보낸 문의가 없어요', textAlign: TextAlign.center),
                  ),
              ],
            );
          }
          if (index <= _items.length)
            return _inquiry(context, _items[index - 1]);
          if (_moreFailed) {
            return _retry(
              '이전 문의를 불러오지 못했어요',
              'support-history-more-retry',
              () => _load(more: true),
            );
          }
          if (!_hasMore) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              key: const ValueKey('support-history-more'),
              onPressed: _loadingMore || _loading
                  ? null
                  : () => _load(more: true),
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('이전 문의 더 보기'),
            ),
          );
        },
      ),
    );
  }

  Widget _retry(String message, String key, VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: ValueKey(key),
          onPressed: _loading || _loadingMore ? null : onRetry,
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );

  Widget _inquiry(BuildContext context, SupportInquiry inquiry) {
    final date = inquiry.createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
    final muted = ExperienceFormStyle.muted(context);
    return ExpansionTile(
      key: ValueKey('support-inquiry-${inquiry.id}'),
      tilePadding: const EdgeInsets.symmetric(vertical: 8),
      childrenPadding: const EdgeInsets.only(bottom: 20),
      shape: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
      collapsedShape: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
      title: Text(
        inquiry.subject,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              inquiry.statusLabel,
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              inquiry.categoryLabel,
              style: TextStyle(color: muted, fontSize: 13),
            ),
            Text(timestamp, style: TextStyle(color: muted, fontSize: 13)),
          ],
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '접수번호 #${inquiry.id}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SelectableText(inquiry.subject),
              const SizedBox(height: 12),
              Padding(
                key: ValueKey('support-inquiry-body-${inquiry.id}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(inquiry.message),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
