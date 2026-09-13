# Album artwork export

`AlbumPrintExporter.generate(snapshot:, spec:, sourceUrls:)` accepts an immutable
order snapshot and the exact server-supplied `PrintVendorSpec`. It returns real
`coverPdf`, `interiorPdf`, `interiorPageCount`, and a preflight `report`. Admin
finalization must attach the server's `sourceFingerprint`; it does not come from
the renderer. `sourceUrls` contains temporary signed download URLs keyed by the
unchanged original source reference. Owner previews can omit it.

`verify` performs the same original-file, font, dimension, and effective-resolution
checks without producing PDFs. `PrintAlbumDocument.fromSnapshot` and
`PrintAlbumPageCanvas` are shared with the visible preview. Never substitute the
store thumbnail renderer or a screenshot of the device viewport.

The full document in `album.cover_layers_json.pages` takes precedence over legacy
`album_pages`. Coordinates use the existing 500px editor reference width and
album ratio. The 14px decorative cover spine is excluded from front-cover artwork;
the physical spine is provided explicitly by the vendor specification. Cover
themes, page backgrounds, typography, crop alignment, rotation, scale, opacity,
frames, stickers and image-filled text use the existing `LayerBuilder`.

Every page is fitted whole inside the product trim rectangle. Extra space uses
the page background. The back and physical spine use the front background color.
Only external cut edges extend into bleed; the front/spine join does not. Blank
white interior pages are appended to the paid page count and reported explicitly.

New previews use the saved `cover_layers_json.printProduct` (`id`, `trimWidthMm`,
`trimHeightMm`) and require it to match the server quote/spec and album ratio.
Supported trim sizes are 200×150, 200×200, 250×200, 250×250 and 300×300 mm,
each with a saved `_SOFT` or `_HARD` product ID. Changing cover kind changes the
manufacturing product while retaining the artwork and trim size.
Albums without product metadata resolve only legacy square→200×200 and
4:3→200×150; portrait/custom ratios remain editable but cannot open a new physical
preview. Existing paid `REDP_200_SOFT_REVIEW_V1_*` specs preserve the purchased
200×200 contract, including its whole-design fit. V2/V3 frozen product metadata
cannot change between the album, order snapshot and PDF specification.

Hardcover specs require explicit `cover.construction: casewrap`, `cover.trim`,
`cover.bleedMm`, front/back board artwork rectangles and geometry evidence. Board
size is independent of interior trim. Artwork is contained on the board; exterior
wrap margins extend the artwork edge and the spine retains its background.
Softcover geometry cannot be used by changing its product ID to hardcover.
A missing vendor template keeps the product/price preview available but disables
PDF creation. The supported catalog currently supplies a distinct hardcover review profile from seven measured official guides; unmeasured page counts retain an inference notice. An admin may supply exact cover geometry from the official guide.
The admin form preloads the current server profile; the usual input is the
guide's spine width and supporting evidence. For the official casewrap family,
changing the spine moves the front board and adjusts media/trim width by the
same delta. Full coordinate edits remain in the collapsed advanced section.

Original dimensions determine effective PPI. Below the spec minimum fails; below
300 PPI is reported. Each source is decoded only to the largest 300 DPI placement
needed on that page, with no upsampling. The decoder rejects more than 40 million
decoded pixels per page, a dimension over 16384 pixels, or a source file over
60 MiB. Pages are released sequentially. The final PDF is capped at 90 MiB per file.

Output is PDF 1.4 with 300 DPI JPEG-quality-95 artwork, explicit MediaBox,
TrimBox/BleedBox, and an embedded standard sRGB ICC profile. It is not PDF/X or
CMYK. The vendor reply shared on 2026-09-10 confirms RGB artwork for photographic
paper and gives no recommended ICC profile; sRGB remains our rendering standard.
The vendor offers no advance file review. SnapFit must compare the exact
page-count-specific cover template and check its own physical sample;
`spec.verified == false` remains a review warning. See the
[recorded reply](../../../../docs/print/vendors/redprinting/reply-shared-2026-09-10.md).
Flutter render errors abort instead of printing an ErrorWidget or placeholder.

Verification:

```sh
flutter test --no-pub test/printing/print_album_export_test.dart
flutter test --no-pub test/printing/five_print_sizes_test.dart
flutter test --no-pub test/printing/hardcover_print_spec_test.dart test/printing/hardcover_print_export_test.dart
```

The integration test writes representative PDFs and a machine-readable report to
`output/pdf/print-export-proof/`. Render these with Poppler for visual inspection;
they are synthetic test artwork, not a customer album or an accepted press proof.
The five-size test writes one cover and 20 interior pages per product under
`output/pdf/print-five-sizes/`; `contact-sheet.png` is a small Poppler review of
all five products with their actual physical proportions.
Hardcover pairs and their rendered contact sheet are under
`output/pdf/print-hardcover/`. All five 20-page casewrap dimensions match the
official guides: board = interior trim + 6 mm, exterior wrap 20 mm, spine 9.10 mm.
The page-count review formula is 2.4 + .67 × (interior pages / 2), separately
checked against the 300×300 mm 80-page guide; unsampled page counts still require
review.
