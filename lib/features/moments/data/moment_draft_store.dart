import 'moment_draft_store_base.dart';
import 'moment_draft_store_io.dart'
    if (dart.library.js_interop) 'moment_draft_store_web.dart'
    as platform;

export 'moment_draft_store_base.dart';
export 'moment_draft_store_io.dart'
    if (dart.library.js_interop) 'moment_draft_store_web.dart';

MomentDraftStore createMomentDraftStore() =>
    platform.createPlatformMomentDraftStore();
