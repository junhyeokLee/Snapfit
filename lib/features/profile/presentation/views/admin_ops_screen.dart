import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../data/admin_ops_repository.dart';
import '../../domain/entities/order_history_item.dart';

class AdminOpsScreen extends ConsumerStatefulWidget {
  const AdminOpsScreen({super.key});

  @override
  ConsumerState<AdminOpsScreen> createState() => _AdminOpsScreenState();
}

class _AdminOpsScreenState extends ConsumerState<AdminOpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final _adminKeyCtl = TextEditingController(text: Env.orderAdminKey);
  final _searchCtl = TextEditingController();
  final _templateTitleCtl = TextEditingController();
  final _templateIdCtl = TextEditingController();
  final _templateCoverCtl = TextEditingController();
  final _templatePreviewCtl = TextEditingController(text: '[]');
  final _templateTagsCtl = TextEditingController(text: '[]');
  final _templateJsonCtl = TextEditingController();
  final _templatePageCountCtl = TextEditingController(text: '12');
  final _courierCtl = TextEditingController(text: 'CJ대한통운');
  final _trackingCtl = TextEditingController();

  AdminDashboardData? _dashboard;
  List<OrderHistoryItem> _orders = const [];
  List<AdminCsSignal> _signals = const [];
  List<AdminTemplateSummary> _templates = const [];
  bool _loading = false;
  bool _loadingMoreOrders = false;
  int _orderPage = 0;
  bool _hasNextOrderPage = true;

  String get _adminKey => _adminKeyCtl.text.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    _tab.dispose();
    _adminKeyCtl.dispose();
    _searchCtl.dispose();
    _templateTitleCtl.dispose();
    _templateIdCtl.dispose();
    _templateCoverCtl.dispose();
    _templatePreviewCtl.dispose();
    _templateTagsCtl.dispose();
    _templateJsonCtl.dispose();
    _templatePageCountCtl.dispose();
    _courierCtl.dispose();
    _trackingCtl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshAll() async {
    if (_adminKey.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminOpsRepositoryProvider);
      final dashboard = await repo.fetchDashboard(adminKey: _adminKey);
      final cs = await repo.fetchCsSignals(adminKey: _adminKey, limit: 50);
      final page = await repo.fetchAdminOrders(
        adminKey: _adminKey,
        page: 0,
        size: 20,
        keyword: _searchCtl.text.trim(),
      );
      final templatePage = await repo.fetchAdminTemplates(
        adminKey: _adminKey,
        page: 0,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _signals = cs;
        _orders = page.items;
        _templates = templatePage.items;
        _orderPage = 0;
        _hasNextOrderPage = page.hasNext;
      });
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMoreOrders || !_hasNextOrderPage || _adminKey.isEmpty) return;
    setState(() => _loadingMoreOrders = true);
    try {
      final repo = ref.read(adminOpsRepositoryProvider);
      final next = _orderPage + 1;
      final page = await repo.fetchAdminOrders(
        adminKey: _adminKey,
        page: next,
        size: 20,
        keyword: _searchCtl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _orders = [..._orders, ...page.items];
        _orderPage = next;
        _hasNextOrderPage = page.hasNext;
      });
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loadingMoreOrders = false);
      }
    }
  }

  Future<void> _markShipping(OrderHistoryItem order) async {
    if (_adminKey.isEmpty) return _toast('관리자 키를 입력해주세요.');
    final tracking = _trackingCtl.text.trim();
    if (tracking.isEmpty) return _toast('운송장 번호를 입력해주세요.');
    try {
      await ref.read(adminOpsRepositoryProvider).markShipping(
            adminKey: _adminKey,
            orderId: order.orderId,
            courier: _courierCtl.text.trim().isEmpty ? 'CJ대한통운' : _courierCtl.text.trim(),
            trackingNumber: tracking,
          );
      _toast('배송중으로 변경했습니다.');
      await _refreshAll();
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _markDelivered(OrderHistoryItem order) async {
    if (_adminKey.isEmpty) return _toast('관리자 키를 입력해주세요.');
    try {
      await ref.read(adminOpsRepositoryProvider).markDelivered(
            adminKey: _adminKey,
            orderId: order.orderId,
          );
      _toast('배송완료로 변경했습니다.');
      await _refreshAll();
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _upsertTemplate() async {
    if (_adminKey.isEmpty) return _toast('관리자 키를 입력해주세요.');
    final title = _templateTitleCtl.text.trim();
    final cover = _templateCoverCtl.text.trim();
    final templateJson = _templateJsonCtl.text.trim();
    final id = int.tryParse(_templateIdCtl.text.trim());
    final pageCount = int.tryParse(_templatePageCountCtl.text.trim()) ?? 12;
    if (title.isEmpty || cover.isEmpty || templateJson.isEmpty) {
      return _toast('제목/커버URL/templateJson은 필수입니다.');
    }
    try {
      await ref.read(adminOpsRepositoryProvider).upsertTemplate(
        adminKey: _adminKey,
        payload: {
          if (id != null) 'id': id,
          'title': title,
          'coverImageUrl': cover,
          'previewImagesJson': _templatePreviewCtl.text.trim().isEmpty
              ? '[]'
              : _templatePreviewCtl.text.trim(),
          'tagsJson': _templateTagsCtl.text.trim().isEmpty
              ? '[]'
              : _templateTagsCtl.text.trim(),
          'pageCount': pageCount,
          'likeCount': 0,
          'userCount': 0,
          'isBest': false,
          'isPremium': false,
          'category': 'general',
          'active': true,
          'templateJson': templateJson,
        },
      );
      _toast('템플릿 등록 완료');
      _templateTitleCtl.clear();
      _templateCoverCtl.clear();
      _templateJsonCtl.clear();
      await _refreshAll();
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _fillTemplateForEdit(AdminTemplateSummary item) async {
    if (_adminKey.isEmpty) {
      _toast('관리자 키를 입력해주세요.');
      return;
    }
    try {
      final detail = await ref.read(adminOpsRepositoryProvider).fetchAdminTemplateDetail(
            adminKey: _adminKey,
            templateId: item.id,
          );
      _templateIdCtl.text = item.id.toString();
      _templateTitleCtl.text = detail['title']?.toString() ?? item.title;
      _templateCoverCtl.text = detail['coverImageUrl']?.toString() ?? '';
      _templatePageCountCtl.text =
          (detail['pageCount']?.toString() ?? item.pageCount.toString());
      _templatePreviewCtl.text = detail['previewImagesJson']?.toString() ?? '[]';
      _templateTagsCtl.text = detail['tagsJson']?.toString() ?? '[]';
      _templateJsonCtl.text = detail['templateJson']?.toString() ?? '';
      _toast('템플릿 #${item.id} 수정 모드로 불러왔습니다.');
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _toggleTemplateActive(AdminTemplateSummary item) async {
    if (_adminKey.isEmpty) return _toast('관리자 키를 입력해주세요.');
    try {
      await ref.read(adminOpsRepositoryProvider).setTemplateActive(
            adminKey: _adminKey,
            templateId: item.id,
            active: !item.active,
          );
      _toast(item.active ? '템플릿 비노출 처리' : '템플릿 노출 처리');
      await _refreshAll();
    } catch (e) {
      _toast(AppErrorMapper.toUserMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text('운영센터', style: context.sfTitle(size: 16.sp)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: '대시보드'),
            Tab(text: '주문관리'),
            Tab(text: 'CS 로그'),
            Tab(text: '템플릿 등록'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 8.h),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _adminKeyCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'X-Admin-Key',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                FilledButton(
                  onPressed: _loading ? null : _refreshAll,
                  child: const Text('연결'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildDashboardTab(context),
                _buildOrderTab(context),
                _buildCsTab(context),
                _buildTemplateTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    final data = _dashboard;
    if (data == null) {
      return const Center(child: Text('관리자 키 입력 후 연결해주세요.'));
    }
    Widget metric(String label, String value) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.sfSub(size: 11.sp)),
            SizedBox(height: 6.h),
            Text(value, style: context.sfBody(size: 16.sp, weight: FontWeight.w800)),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Text('갱신: ${data.generatedAt}', style: context.sfSub(size: 11.sp)),
        SizedBox(height: 10.h),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10.h,
          crossAxisSpacing: 10.w,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.65,
          children: [
            metric('총 사용자', '${data.usersTotal}'),
            metric('신규(24h)', '${data.users24h}'),
            metric('템플릿(활성/전체)', '${data.templatesActive}/${data.templatesTotal}'),
            metric('주문(24h/전체)', '${data.orders24h}/${data.ordersTotal}'),
            metric('결제승인(24h)', '${data.billingApproved24h}'),
            metric('결제실패(24h)', '${data.billingFailed24h}'),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtl,
                  decoration: const InputDecoration(
                    hintText: '주문번호/유저ID/수령인 검색',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OutlinedButton(
                onPressed: _refreshAll,
                child: const Text('검색'),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _courierCtl,
                  decoration: const InputDecoration(
                    labelText: '택배사',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: _trackingCtl,
                  decoration: const InputDecoration(
                    labelText: '운송장 번호',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            itemCount: _orders.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              if (index >= _orders.length) {
                return Center(
                  child: _hasNextOrderPage
                      ? TextButton(
                          onPressed: _loadingMoreOrders ? null : _loadMoreOrders,
                          child: Text(_loadingMoreOrders ? '불러오는 중...' : '더 보기'),
                        )
                      : Text('마지막 페이지', style: context.sfSub(size: 11.sp)),
                );
              }
              final order = _orders[index];
              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.orderId} · ${order.statusLabel}',
                      style: context.sfBody(size: 12.sp, weight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.h),
                    Text(order.title, style: context.sfSub(size: 11.sp)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        OutlinedButton(
                          onPressed: () => _markShipping(order),
                          child: const Text('배송중'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _markDelivered(order),
                          child: const Text('배송완료'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCsTab(BuildContext context) {
    if (_signals.isEmpty) {
      return const Center(child: Text('표시할 CS 로그가 없습니다.'));
    }
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: _signals.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final s = _signals[index];
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: SnapFitColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: s.severity.toUpperCase() == 'HIGH'
                  ? const Color(0xFFFFD7D7)
                  : SnapFitColors.overlayLightOf(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[${s.type}] ${s.code}',
                style: context.sfBody(size: 11.sp, weight: FontWeight.w700),
              ),
              SizedBox(height: 4.h),
              Text(s.message, style: context.sfSub(size: 11.sp)),
              SizedBox(height: 6.h),
              Text(
                'orderId: ${s.orderId} · userId: ${s.userId}\n${s.updatedAt}',
                style: context.sfSub(size: 10.sp),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplateTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        TextField(
          controller: _templateIdCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '템플릿 ID (수정 시 입력/불러오기)',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templateTitleCtl,
          decoration: const InputDecoration(
            labelText: '템플릿 제목',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templateCoverCtl,
          decoration: const InputDecoration(
            labelText: '커버 이미지 URL',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templatePageCountCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '페이지 수',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templatePreviewCtl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'previewImagesJson (배열 문자열)',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templateTagsCtl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'tagsJson (배열 문자열)',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _templateJsonCtl,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'templateJson',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 12.h),
        FilledButton(
          onPressed: _upsertTemplate,
          child: const Text('템플릿 등록'),
        ),
        SizedBox(height: 16.h),
        Text('등록된 템플릿', style: context.sfBody(size: 12.sp, weight: FontWeight.w800)),
        SizedBox(height: 8.h),
        ..._templates.map(
          (t) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${t.id} ${t.title}\n${t.category} · ${t.pageCount}p',
                      style: context.sfSub(size: 11.sp),
                    ),
                  ),
                  Switch(
                    value: t.active,
                    onChanged: (_) => _toggleTemplateActive(t),
                  ),
                  TextButton(
                    onPressed: () => _fillTemplateForEdit(t),
                    child: const Text('수정'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
