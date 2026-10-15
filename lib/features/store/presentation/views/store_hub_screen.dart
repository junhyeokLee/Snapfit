import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';

import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import 'material_catalog_screen.dart';
import 'store_screen.dart';

/// One shopping destination; each catalog keeps its own filters and position.
class StoreHubScreen extends StatefulWidget {
  const StoreHubScreen({super.key, this.initialMaterials = false});
  final bool initialMaterials;

  @override
  State<StoreHubScreen> createState() => _StoreHubScreenState();
}

class _StoreHubScreenState extends State<StoreHubScreen> {
  late int _index = widget.initialMaterials ? 1 : 0;
  late final Set<int> _visited = {_index};

  void _openLibrary() {
    final scope = ExperienceNavigationScope.maybeOf(context);
    if (scope != null) {
      scope.onNavigate(6);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: kIsWeb ? const WebAppRouteSettings(WebAppLocation.library) : null,
          builder: (_) => const MaterialCatalogScreen(library: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialMaterials ? 1 : 0,
    child: _frame(
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ExperienceFormStyle.line(context)))),
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 0 : 20),
            child: TabBar(
              key: const ValueKey('store-catalog-tabs'),
              onTap: (index) => setState(() {
                FocusManager.instance.primaryFocus?.unfocus();
                _index = index;
                _visited.add(index);
              }),
              isScrollable: kIsWeb,
              tabAlignment: kIsWeb ? TabAlignment.start : null,
              labelColor: kIsWeb ? WebPalette.of(context).brandInk : ExperienceFormStyle.ink(context),
              unselectedLabelColor: ExperienceFormStyle.muted(context),
              labelStyle: ExperienceStyle.text(16, weight: FontWeight.w700),
              unselectedLabelStyle: ExperienceStyle.text(16, weight: FontWeight.w500),
              indicatorColor: kIsWeb ? WebPalette.of(context).brand : ExperienceStyle.accent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(height: 46, text: '템플릿'), Tab(height: 46, text: '꾸밈소재')],
            ),
          ),
          if (kIsWeb) const SizedBox(height: 24),
          Expanded(child: IndexedStack(index: _index, children: [
            TickerMode(enabled: _index == 0, child: _visited.contains(0) ? const StoreScreen(embedded: true) : const SizedBox.shrink()),
            TickerMode(enabled: _index == 1, child: _visited.contains(1) ? const MaterialCatalogScreen(embedded: true) : const SizedBox.shrink()),
          ])),
        ],
      ),
    ),
  );

  Widget _frame({required Widget body}) {
    if (kIsWeb) return SnapFitWebShell(
      section: WebSection.designs,
      actions: [OutlinedButton.icon(onPressed: _openLibrary, icon: const Icon(Icons.bookmark_outline, size: 18), label: const Text('내 디자인 보관함'))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WebPageHeading(eyebrow: 'DESIGN STUDIO', title: '나의 앨범에 어울리는 디자인', description: '템플릿에서 시작하거나, 사진 곁에 놓을 꾸밈 소재를 골라보세요.'),
        const SizedBox(height: 28),
        Expanded(child: body),
      ]),
    );
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '스토어',
        back: false,
        actions: [
          IconButton(
            tooltip: '내 보관함',
            onPressed: _openLibrary,
            icon: const ExperienceIcon('Bookmark'),
          ),
        ],
      ),
      body: body,
    );
  }
}
