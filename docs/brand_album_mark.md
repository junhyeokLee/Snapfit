# SnapFit: Album Mark

## Scope

Static brand exploration requested on 2026-09-07. The latest request explicitly
excludes producing a video. This work does not change Flutter launch routing,
authentication, native launch screens, installed app icons, or existing templates.

## Selected Artwork

- `assets/brand/album-mark/app-icon-cyan.png`: cyan background, white facing
  album leaves; opaque square master, no baked-in OS mask.
- `assets/brand/album-mark/wordmark-cyan.png`: cyan symbol and charcoal lowercase
  snapfit wordmark on an opaque white background.
- `assets/brand/album-mark/splash-portrait.png`: full-bleed travel image and logo.
- `assets/brand/album-mark/splash-landscape.png`: wide companion composition.

These are AI-generated raster concepts, not final vector or trademark-cleared
artwork. The travel scene and couple are synthetic, not licensed footage or a
verified depiction of a particular destination. Splash logos are baked into the
concept images; native integration should eventually use a separate logo layer
for consistent size and safe-area placement. Native icon export and safe-area
launch-screen adaptation are intentionally deferred until the direction is approved.

`app-icon-master.png` and `wordmark-white.png` are the superseded off-brand green
exploration. `wordmark-ink.png` is an unselected transparency experiment. None are
used by the preview. Color edits were made using the built-in image generation
tool and saved as new siblings; original images are preserved. Exact generation
prompts and selected source files are recorded in
`assets/brand/album-mark/provenance.json` (built-in image generation, no fallback API).

## App Colors

Source of truth: actual constants in `lib/core/constants/snapfit_colors.dart`,
used by both light and dark themes in `lib/core/theme/snapfit_theme.dart`:
`accent #08B8D0`, `accentLight #EAFBFD`, `deepCharcoal #121212`, `pureWhite #FFFFFF`.
The older `#00C2E0` and `#E3F9FD` comments are not the current constant values.
The Flutter color definitions are unchanged. Preview CSS and color labels are
verified against the actual constants. Generated raster colors approximate the
target values; exact flat-color/vector production artwork remains a separate
export task. The white photographic splash lockups remain unchanged for contrast.

## Preview

From `tool/brand_studio`, run `npm ci --ignore-scripts` and `npm run build`.
The build is written under `build/template-preview/brand`, preserving the existing
template preview at `/`. The existing server on port 4323 serves it at
`http://127.0.0.1:4323/brand/`. When no server is running, `npm run serve` starts one;
an occupied port is skipped without stopping the existing process.

The preview has splash orientation selection, icon masks and real-pixel size
comparisons, PNG downloads, and free-footage links. It contains no video, player,
animation, or WebGL dependency.

`npm run verify` needs Playwright, Chrome and pngjs. In the Codex environment:

```sh
NODE_PATH=/Users/devsheep/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules npm run verify
```

Screenshots and verification results go to ignored `output/brand-studio/`.
This checks 320x568, 390x844, 844x390 and 1440x900 layouts, both image orientations,
loaded/opaque/nonblank PNGs, source-to-preview color parity, keyboard tabs, downloads, horizontal overflow and
browser errors. Flutter runtime behavior is unchanged and is not tested here.

## Free Footage

Official terms checked 2026-09-07:

- Pexels: https://www.pexels.com/license/ permits free commercial/app use without
  required attribution, subject to restrictions including implied endorsement.
  Search: https://www.pexels.com/search/videos/couple%20travel/
- Pixabay: https://pixabay.com/service/license-summary/ allows free use and
  adaptation without mandatory attribution, subject to prohibited uses and any
  additional third-party rights. Search: https://pixabay.com/videos/search/landscape/
- Mixkit: https://mixkit.co/license/ distinguishes Video Free License from
  Restricted License. Use only the former for this commercial-app use case.
  Browse: https://mixkit.co/free-stock-video/

Choose a quiet 9:16 shot at 1080p or higher, with clear space for the logo. Keep
the original clip URL and download-time license. Do not imply that pictured
people endorse SnapFit. No third-party videos have been downloaded or bundled.
