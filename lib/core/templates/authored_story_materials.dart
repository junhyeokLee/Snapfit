part of 'authored_collections.dart';

// Only detail photographs opt into these mounts. Existing covers, full scenes
// and saved customer layers retain their original geometry and crop.
Rect _storyMountedPhoto(_StoryPage p, int photo, Rect bounds, {int mount = 0}) {
  final e = p.edition;
  if (e.photoFrames.isEmpty) {
    p.image(photo, bounds);
    return bounds;
  }
  final sourceAspect = e.photoAspectRatios[photo % e.photoAssets.length];
  var frame = e.photoFrames[mount];
  var outerAspect = _storyMountAspect(frame, sourceAspect);
  if (outerAspect == null) {
    // Film rails flip at a square outer box; some near-square sources cannot
    // fit either orientation without cropping. Use the book's other mount.
    frame = e.photoFrames[1 - mount];
    outerAspect = _storyMountAspect(frame, sourceAspect);
  }
  if (outerAspect == null) throw StateError('unsupported_story_mount:${e.id}');
  final width = math.min(bounds.width, bounds.height * outerAspect / p.ratio);
  final height = width * p.ratio / outerAspect;
  final rect = Rect.fromCenter(
    center: bounds.center,
    width: width,
    height: height,
  );
  p.image(photo, rect, frame: frame);
  p.layers.last['storyPhotoSourceAspect'] = sourceAspect;
  return rect;
}

double? _storyMountAspect(String frame, double sourceAspect) {
  // Insets are homogeneous in the shorter outer side. Try the landscape
  // branch, then the portrait branch for narrow photographs. The frame's own
  // inset policy remains the single source of truth for preview/editor/print.
  final wideInsets = StudioMaterial.photoInsets(frame, const Size(2, 1));
  final wideAspect =
      sourceAspect * (1 - wideInsets.vertical) + wideInsets.horizontal;
  if (wideAspect >= 1) return wideAspect;
  final tallInsets = StudioMaterial.photoInsets(frame, const Size(1, 2));
  final tallAspect =
      1 / ((1 - tallInsets.horizontal) / sourceAspect + tallInsets.vertical);
  return tallAspect <= 1 ? tallAspect : null;
}

void _storyStationeryPhoto(_StoryPage p, int photo, Rect bounds, String title) {
  final spec = studioDecorationById(p.edition.paperId)!;
  final w = math.min(bounds.width, bounds.height * spec.aspectRatio / p.ratio);
  final h = w * p.ratio / spec.aspectRatio;
  final paper = Rect.fromCenter(center: bounds.center, width: w, height: h);
  p.piece(p.edition.paperId, paper);
  _storyMountedPhoto(
    p,
    photo,
    Rect.fromLTWH(paper.left + w * .08, paper.top + h * .09, w * .84, h * .62),
    mount: 1,
  );
  p.type(
    title,
    // Keep type off the paper's printed rules, tabs and binding marks.
    Rect.fromLTWH(paper.left + w * .04, paper.bottom + .028, w * .92, .075),
    size: .027,
  );
}
