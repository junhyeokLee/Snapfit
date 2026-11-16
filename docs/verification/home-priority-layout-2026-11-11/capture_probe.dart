// Full native HomeScreen layout audit. Only synthetic in-memory data is used.
// This harness intentionally keeps the true initial vertical offset at zero.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../../../test/helpers/memory_moment_draft_store.dart';
import '../../../test/widget/page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

const _owner = 'home-layout-owner';
final _today = DateTime.utc(2026, 11, 18);
const _photos = [
  'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_sunset.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_rocky_coast.jpg',
];
late List<Album> _albums;
final _captureKey = GlobalKey();

class _AuditBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get disableShadows => false;
}
class _Auth extends AuthViewModel {
  @override FutureOr<UserInfo?> build() => const UserInfo(id: _owner, name: '스냅핏', provider: 'email');
}
class _Home extends HomeViewModel {
  @override FutureOr<List<Album>> build() => _albums;
}
class _Albums extends MockAlbumRepository {
  @override Future<List<Album>> fetchMyAlbums() async => _albums;
  @override Future<Album> fetchAlbum(String id) async => _albums.firstWhere((album) => '${album.id}' == id);
}
class _Moments extends Fake implements MomentsRepository {
  _Moments({this.todaySaved=false});
  final bool todaySaved;
  final _changes = StreamController<String?>.broadcast();
  int reads = 0;
  @override String? get currentUserId => _owner;
  @override Stream<String?> get authChanges => _changes.stream;
  @override Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    reads++;
    final records = [
      for(var day=1;day<=(todaySaved?18:17);day++) MomentRecord(
        id:'layout-day-$day',recordDate:DateTime.utc(2026,11,day),
        caption:'${day}일에 남겨둔 바다의 빛',revision:1,
        photos:[MomentPhoto(id:'layout-photo-$day',path:'$_owner/moments/$day/photo.jpg',
          url:'asset:${_photos[day%_photos.length]}',width:1200,height:800)],
      ),
    ];
    return MomentJournal(today:_today,weekStart:momentWeekStart(_today),month:requestedMonth??momentMonth(_today),records:records,weekPhotoCount:todaySaved?3:2,
      monthlyReward:MomentMonthlyReward(points:1000,recordedDays:records.length,daysInMonth:30,awarded:false,canComplete:true));
  }
  Future<void> close() => _changes.close();
}

Future<void> _loadFixture() async {
  final manifest=jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for(final font in manifest) {
    final loader=FontLoader(font['family'] as String);
    for(final asset in font['fonts'] as List) {loader.addFont(rootBundle.load(asset['asset'] as String));}
    await loader.load();
  }
  final choices = [for(final id in [-9501,-9301,-9401])
    ...publishedCreationTemplates.where((template)=>template.id==id)];
  expect(choices.length,greaterThanOrEqualTo(2));
  _albums=[];
  for(final entry in choices.take(3).indexed) {
    final template=entry.$2;
    final data=jsonDecode(template.templateJson!) as Map<String,dynamic>;
    final metadata=data['metadata'] as Map? ?? const {};
    final dw=(data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500).toDouble();
    final dh=(data['designHeight'] as num? ?? metadata['designHeight'] as num? ?? 500).toDouble();
    final canvas=Size(500,500*dh/dw);
    // Retain real authored content, with a partially completed local album.
    final authored=templateDocumentPages(data).take(5).toList();
    final pages=<Map<String,dynamic>>[];
    for(final page in authored.indexed) {
      final layers=DataTemplateEngine.buildLayersFromJson({'strictLayout':true,'designWidth':dw,'designHeight':dh,'layers':page.$2['layers']},canvas);
      final rawBackground=page.$2['backgroundColor'];
      final background=rawBackground is int?rawBackground:rawBackground is String?int.tryParse(rawBackground.replaceFirst('#','').padLeft(8,'f'),radix:16):null;
      pages.add({'index':page.$1,'isCover':page.$1==0,
        if(background!=null)'backgroundColor':background,
        'layers':[for(final layer in layers) LayerExportMapper.toJson(layer,canvasSize:canvas,isCover:page.$1==0)]});
    }
    _albums.add(Album(id:101+entry.$1,userId:_owner,memberRole:'OWNER',title:template.title,ratio:'${canvas.width}:${canvas.height}',
      totalPages:pages.length,targetPages:24,orders:entry.$1,
      coverLayersJson:jsonEncode({'pages':pages}),createdAt:'2026-11-01T00:00:00Z',updatedAt:'2026-11-${18-entry.$1}T00:00:00Z'));
  }
  debugPrint('HOME_FULL_FIXTURE albums=${_albums.map((a)=>'${a.id}:${a.title}').join(', ')}; journal=17/30 at 2026-11-18');
}

Future<void> _ready(WidgetTester tester) async {
  var stable=0;
  for(var frame=0;frame<220;frame++) {
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:20)));
    await tester.pump(const Duration(milliseconds:32));
    final ready=find.byType(HomeAlbumSlider).evaluate().isNotEmpty &&
      find.byKey(const ValueKey('moments-photo-calendar')).evaluate().isNotEmpty &&
      find.byType(CircularProgressIndicator).evaluate().isEmpty &&
      find.byType(CatalogCoverSkeleton).evaluate().isEmpty &&
      PaintingBinding.instance.imageCache.pendingImageCount==0 && !tester.binding.hasScheduledFrame;
    stable=ready&&frame>=24?stable+1:0;
    if(stable==5){expect(tester.takeException(),isNull);return;}
  }
  expect(tester.takeException(),isNull);
  expect(find.byType(HomeAlbumSlider),findsOneWidget);
  expect(find.byType(CircularProgressIndicator),findsNothing);
  expect(find.byType(CatalogCoverSkeleton),findsNothing);
  expect(PaintingBinding.instance.imageCache.pendingImageCount,0);
  debugPrint('HOME_FULL_READY bounded wait ended; scheduled=${tester.binding.hasScheduledFrame}');
}
void _markPaint(RenderObject object) {object.visitChildren(_markPaint);if(object.attached)object.markNeedsPaint();}
Future<void> _capture(WidgetTester tester,String name) async {
  await _ready(tester);
  for(final view in tester.binding.renderViews){_markPaint(view);}
  await tester.pump(const Duration(milliseconds:32));
  await tester.pump(const Duration(milliseconds:32));
  await tester.runAsync(() async {
    final boundary=_captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image=await boundary.toImage(pixelRatio:2);
    try {
      final png=await image.toByteData(format:ui.ImageByteFormat.png);
      final directory=Platform.environment['HOME_LAYOUT_DIR'];
      if(directory==null||directory.isEmpty)throw StateError('HOME_LAYOUT_DIR required');
      final file=File('$directory/$name.png');await file.parent.create(recursive:true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      debugPrint('HOME_FULL_CAPTURE ${file.path} ${image.width}x${image.height}');
    }finally{image.dispose();}
  });
}

ScrollableState _vertical(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(of:find.byKey(const PageStorageKey('home-album-cover-scroll')),matching:find.byType(Scrollable)).first);
Rect _rect(WidgetTester tester,Finder finder) => tester.getRect(finder.first);
final _sections=<String,Finder Function()>{
  'header':()=>find.byType(HomeAlbumHeader),
  'calendar':()=>find.byKey(const ValueKey('moments-photo-calendar')),
  'todayAction':()=>find.byKey(const ValueKey('home-monthly-feed-record')),
  'compactTodayAction':()=>find.byKey(const ValueKey('home-monthly-feed-compact-record')),
  'archive':()=>find.byKey(const ValueKey('home-moment-archive-section')),
  'monthlyAlbumEntry':()=>find.byKey(const ValueKey('home-monthly-album-entry')),
  'nextStory':()=>find.byKey(const ValueKey('first-book-next-step')),
  'albumSection':()=>find.byKey(const ValueKey('home-album-section-title')),
  'book':()=>find.byKey(const ValueKey('home-bookshelf-stage')),
  'focusedTitle':()=>find.byKey(const ValueKey('home-focused-album-title')),
  'albumSelector':()=>find.byKey(const ValueKey('home-bookshelf-strip')),
  'bottomNavigation':()=>find.byType(HomeBottomNavigationBar),
  'bottomNavigationSurface':()=>find.byKey(const ValueKey('home-navigation-surface')),
  'albumViewShortcut':()=>find.byKey(const ValueKey('home-album-view-toggle')),
  'nextStoryFallback':()=>find.byKey(const ValueKey('home-next-story-entry')),
};
Map<String,dynamic> _metrics(WidgetTester tester,String step) {
  final vertical=_vertical(tester).position;
  final viewport=_rect(tester,find.byKey(const PageStorageKey('home-album-cover-scroll')));
  final nav=_rect(tester,find.byType(HomeBottomNavigationBar));
  final visible=Rect.fromLTRB(viewport.left,viewport.top,viewport.right,viewport.bottom<nav.top?viewport.bottom:nav.top);
  final rects=<String,dynamic>{};
  for(final entry in _sections.entries) {
    final finder=entry.value();
    if(finder.evaluate().isEmpty){rects[entry.key]={'mounted':false};continue;}
    final rect=_rect(tester,finder);
    final intersection=rect.intersect(visible);
    rects[entry.key]={'mounted':true,'screenTop':rect.top,'screenBottom':rect.bottom,'width':rect.width,'height':rect.height,
      'contentY':rect.top-viewport.top+vertical.pixels,
      'visibleHeight':intersection.isEmpty?0:intersection.height};
  }
  return {'step':step,'scrollOffset':vertical.pixels,'maxScrollExtent':vertical.maxScrollExtent,'viewportDimension':vertical.viewportDimension,
    'viewportScreenTop':viewport.top,'visibleScreenBottom':visible.bottom,'sections':rects};
}
Future<void> _jumpNear(WidgetTester tester,Finder target,{double margin=16}) async {
  final vertical=_vertical(tester).position;
  final viewport=_rect(tester,find.byKey(const PageStorageKey('home-album-cover-scroll')));
  final rect=_rect(tester,target);
  vertical.jumpTo((vertical.pixels+rect.top-viewport.top-margin).clamp(0,vertical.maxScrollExtent).toDouble());
  await _ready(tester);
}


void main(){
 _AuditBinding();setUpAll(_loadFixture);
 for(final sample in [(size:const Size(390,844),todaySaved:false),(size:const Size(320,568),todaySaved:false),(size:const Size(390,844),todaySaved:true)]) {
  for(final targetStep in sample.todaySaved ? [1] : [1,2,3,4]) {
   final size=sample.size;
   testWidgets('full HomeScreen layout ${size.width.toInt()}x${size.height.toInt()} todaySaved=${sample.todaySaved} step=$targetStep',(tester)async{
    tester.view.physicalSize=Size(size.width*2,size.height*2);tester.view.devicePixelRatio=2;
    tester.view.padding=const FakeViewPadding(top:48,bottom:68);tester.view.viewPadding=tester.view.padding;
    SharedPreferences.setMockInitialValues({PreferencesFirstVisitStore.key:3});FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance=CatalogFavorites();await CatalogFavorites.instance.load();
    final moments=_Moments(todaySaved:sample.todaySaved);
    final container=ProviderContainer(retry:(_,__)=>null,overrides:[
      authViewModelProvider.overrideWith(_Auth.new),homeViewModelProvider.overrideWith(_Home.new),
      homeUiStateProvider.overrideWith(()=>HomeUiStateNotifier(initialIndex:0)),
      momentsRepositoryProvider.overrideWithValue(moments),momentEntryClockProvider.overrideWithValue(()=>_today),
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),albumCreationDraftProvider.overrideWith((_)async=>null),
      albumRepositoryProvider.overrideWithValue(_Albums()),storageServiceProvider.overrideWithValue(FakeStorageService()),
      albumPersistenceServiceProvider.overrideWithValue(FakeAlbumPersistenceService()),albumEditorOwnerReaderProvider.overrideWithValue(()=>_owner),
      visibleOrderOwnerProvider.overrideWithValue(_owner),notificationUnreadCountProvider.overrideWith((_)async=>0),
      homeNewsCurrentOwnerProvider.overrideWithValue(null),mockTemplateList(()async=>const []),
    ]);
    try {
     await tester.pumpWidget(UncontrolledProviderScope(container:container,child:ScreenUtilInit(designSize:const Size(390,844),builder:(_,__)=>MaterialApp(
      debugShowCheckedModeBanner:false,theme:SnapFitTheme.light(),builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:true),child:RepaintBoundary(key:_captureKey,child:child!)),home:const HomeScreen()))));
     await tester.runAsync(()async{for(final asset in _photos){for(final width in [112,384]){await precacheImage(ResizeImage(AssetImage(asset),width:width),tester.element(find.byType(HomeScreen)));}}});
     await _ready(tester);
     final positions=<Map<String,dynamic>>[];
     final prefix='${size.width.toInt()}x${size.height.toInt()}${sample.todaySaved?'-today-saved':''}';
     expect(_vertical(tester).position.pixels,0,reason:'Start every observation from the real initial home.');
     positions.add(_metrics(tester,'01-initial'));
     final initial=positions.single['sections'] as Map<String,dynamic>;
     // Daily progress leads; the owned full-size album precedes supporting paths.
     expect(initial['calendar']['contentY'],lessThan(initial['book']['contentY']));
     expect(initial['archive']['contentY'],greaterThan(initial['albumSelector']['contentY']+initial['albumSelector']['height']));
     expect(initial['monthlyAlbumEntry']['contentY'],greaterThan(initial['albumSelector']['contentY']));
     expect(initial['nextStory']['contentY'],greaterThan(initial['albumSelector']['contentY']));
     expect(initial['calendar']['height'],308);
     expect(initial['book']['height'],closeTo(size.width*.94,.01));
     if(size.height<700){
      final action=initial['compactTodayAction'];
      expect(action['mounted'],isTrue);
      expect(action['screenTop'],greaterThanOrEqualTo(104));
      expect(action['screenBottom'],lessThanOrEqualTo(positions.single['visibleScreenBottom']));
     }else{
      expect(initial['compactTodayAction']['mounted'],isFalse);
     }

     if(targetStep>=2){await _jumpNear(tester,find.byKey(const ValueKey('home-monthly-feed-record')),margin:120);positions.add(_metrics(tester,'02-today-and-archive'));}
     if(targetStep>=3){await _jumpNear(tester,find.byKey(const ValueKey('home-album-section-title')));positions.add(_metrics(tester,'03-album-focus'));}
     if(targetStep>=4){final vertical=_vertical(tester).position;final selector=_rect(tester,find.byKey(const ValueKey('home-bookshelf-strip')));final nav=_rect(tester,find.byType(HomeBottomNavigationBar));vertical.jumpTo((vertical.pixels+selector.bottom-nav.top+12).clamp(0,vertical.maxScrollExtent).toDouble());await _ready(tester);positions.add(_metrics(tester,'04-album-selector'));}
     final stepName=['01-initial','02-today-and-archive','03-album-focus','04-album-selector'][targetStep-1];
     // One root screenshot per fresh scene avoids retained chrome disappearing
     // from a later software-rendered offscreen screenshot.
     await _capture(tester,'$prefix-$stepName');
     final directory=Platform.environment['HOME_LAYOUT_DIR']!;final file=File('$directory/$prefix-step$targetStep-layout-metrics.json');
     await tester.runAsync(()async{await file.parent.create(recursive:true);await file.writeAsString(const JsonEncoder.withIndent('  ').convert({'source':'real native HomeScreen, fresh scene per screenshot, synthetic local data and actual template layers','logicalSize':{'width':size.width,'height':size.height},'devicePixelRatio':2,'albumCount':_albums.length,'todaySaved':sample.todaySaved,'momentsReads':moments.reads,'steps':positions}));});
     debugPrint('HOME_FULL_METRICS ${file.path}');expect(tester.takeException(),isNull);
    } finally {
     await tester.pumpWidget(const SizedBox.shrink());await tester.pump();container.dispose();await moments.close();CatalogFavorites.instance.dispose();PaintingBinding.instance.imageCache.clear();PaintingBinding.instance.imageCache.clearLiveImages();tester.view.reset();
    }
   });
  }
 }
}
