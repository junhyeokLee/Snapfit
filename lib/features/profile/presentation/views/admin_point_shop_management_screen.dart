import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_known_products.dart';
import '../../../point_shop/domain/point_shop_product.dart';
import '../../../point_shop/domain/premium_volume_registration.dart';
import '../../../point_shop/domain/point_shop_launch_pricing.dart';

/// UI visibility follows the same app-metadata claim as public.is_admin().
/// Product writes still require the server's RLS permission on every request.
final pointShopAdminAccessProvider = Provider<bool>((ref) {
  ref.watch(authViewModelProvider);
  try {
    return ref
            .watch(supabaseClientProvider)
            .auth
            .currentUser
            ?.appMetadata['role'] ==
        'admin';
  } catch (_) {
    return false;
  }
});

const _kindLabels = {
  'template': '템플릿',
  'sticker': '스티커',
  'phrase': '문구',
  'frame': '프레임',
};

class AdminPointShopManagementScreen extends ConsumerStatefulWidget {
  const AdminPointShopManagementScreen({super.key});

  @override
  ConsumerState<AdminPointShopManagementScreen> createState() =>
      _AdminPointShopManagementScreenState();
}

class _AdminPointShopManagementScreenState
    extends ConsumerState<AdminPointShopManagementScreen> {
  String? _kind;
  String _query = '';

  Future<void> _edit(
    PointShopProduct product, {
    required bool configured,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PointPriceEditor(
        product: product,
        configured: configured,
        onSave: (updated) async {
          if (!ref.read(pointShopAdminAccessProvider)) {
            throw StateError('admin_access_required');
          }
          if (isPendingTemplateProduct(updated.productKey) &&
              updated.isActive) {
            throw StateError('premium_volume_release_pending');
          }
          await ref.read(pointShopRepositoryProvider).saveProduct(updated);
          ref.invalidate(pointShopCatalogProvider);
        },
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상품 가격과 판매 상태를 저장했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(pointShopAdminAccessProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('포인트 상품 관리'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: '가격 새로고침',
              onPressed: () => ref.invalidate(pointShopCatalogProvider),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !isAdmin
          ? const Center(child: Text('상품 가격을 변경할 관리자 권한이 필요합니다.'))
          : ref
                .watch(pointShopCatalogProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('상품 설정을 불러오지 못했습니다.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(pointShopCatalogProvider),
                          child: const Text('다시 불러오기'),
                        ),
                      ],
                    ),
                  ),
                  data: _catalog,
                ),
    );
  }

  Widget _catalog(List<PointShopProduct> savedProducts) {
    final configured = {
      for (final item in savedProducts) item.productKey: item,
    };
    final products = pointShopKnownProducts
        .map((item) => configured[item.productKey] ?? item)
        .where((item) => _kind == null || item.kind == _kind)
        .where(
          (item) =>
              _query.isEmpty ||
              item.title.toLowerCase().contains(_query) ||
              item.assetId.toLowerCase().contains(_query),
        )
        .toList(growable: false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('공개 상품과 출시 대기 상품'),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '상품 찾기',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    for (final kind in _kindLabels.entries) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(kind.value),
                        selected: _kind == kind.key,
                        onSelected: (_) => setState(() => _kind = kind.key),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('검색에 맞는 상품이 없습니다.'))
              : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = products[index];
                    final saved = configured.containsKey(item.productKey);
                    final contents = pendingTemplateContentsLabel(
                      item.productKey,
                    );
                    final launch = pointShopLaunchPrices[item.productKey];
                    final price = contents != null
                        ? '${item.pointPrice == null ? '가격 미설정' : '${item.pointPrice}P'} · 출시 대기'
                        : !saved
                        ? '현재 무료 · 가격 미설정'
                        : item.pointPrice == null
                        ? '가격 미설정 · 판매 중지'
                        : '${item.pointPrice}P · ${item.isActive ? '판매 중' : '판매 중지'}';
                    return ListTile(
                      key: ValueKey('point-shop-admin-${item.productKey}'),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_kindLabels[item.kind] ?? item.kind} · $price'
                        '${launch == null ? '' : '\n출시 책정가 ${launch.points}P · 현재 판매가와 별도'}'
                        '${contents == null ? '' : '\n$contents'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(item, configured: saved),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PointPriceEditor extends StatefulWidget {
  const _PointPriceEditor({
    required this.product,
    required this.configured,
    required this.onSave,
  });
  final PointShopProduct product;
  final bool configured;
  final Future<void> Function(PointShopProduct) onSave;

  @override
  State<_PointPriceEditor> createState() => _PointPriceEditorState();
}

class _PointPriceEditorState extends State<_PointPriceEditor> {
  late final TextEditingController _price;
  late bool _active;
  bool _saving = false;
  String? _error;
  bool get _releasePending =>
      isPendingTemplateProduct(widget.product.productKey);

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.product.pointPrice?.toString() ?? '',
    );
    _active = !_releasePending && widget.product.isActive;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _price.text.trim();
    final value = raw.isEmpty ? null : int.tryParse(raw);
    if ((raw.isNotEmpty &&
            (value == null || value < 0 || value > 2147483647)) ||
        (_active && value == null)) {
      setState(() => _error = '판매할 가격을 0 이상의 정수 포인트로 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        PointShopProduct(
          productKey: widget.product.productKey,
          kind: widget.product.kind,
          assetId: widget.product.assetId,
          title: widget.product.title,
          pointPrice: value,
          isActive: !_releasePending && _active,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error = '저장하지 못했습니다. 관리자 권한과 연결 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.product.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_releasePending) ...[
              Text(pendingTemplateContentsLabel(widget.product.productKey)!),
              const SizedBox(height: 12),
              const Text('출시 대기 · 스토어 연결 및 결제 검증 전'),
              const SizedBox(height: 16),
            ] else if (!widget.configured) ...[
              const Text('현재 무료로 제공 중이며 저장된 가격이 없습니다.'),
              const SizedBox(height: 16),
            ],
            if (pointShopLaunchPrices[widget.product.productKey]
                case final launch?) ...[
              Text('출시 책정가 ${launch.points}P'),
              Text(launch.reason, style: Theme.of(context).textTheme.bodySmall),
              TextButton.icon(
                key: const ValueKey('point-shop-use-launch-price'),
                icon: const Icon(Icons.price_check),
                label: const Text('책정가 입력'),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _price.text = launch.points.toString();
                        _error = null;
                      }),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey('point-shop-price'),
              controller: _price,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '가격',
                suffixText: 'P',
                helperText: '0P는 무료입니다. 유료 가격은 직접 입력하세요.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('판매 활성화'),
              subtitle: Text(
                _releasePending
                    ? '현재는 가격만 저장할 수 있습니다.'
                    : '중지해도 기존 구매 내역은 유지됩니다.',
              ),
              value: _active,
              onChanged: _saving || _releasePending
                  ? null
                  : (value) => setState(() => _active = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중…' : '저장'),
        ),
      ],
    ),
  );
}
