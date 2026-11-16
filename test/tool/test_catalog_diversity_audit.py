import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tool'))
from catalog_diversity_audit import audit_catalog


class CatalogDiversityAuditTest(unittest.TestCase):
    def make_root(self, directory: str) -> Path:
        root = Path(directory)
        (root / 'assets/templates/detail_documents').mkdir(parents=True)
        (root / 'lib/core/templates').mkdir(parents=True)
        (root / 'lib/core/templates/studio_decoration_catalog.dart').write_text('''
const specs = [
  StudioDecorationSpec('new-paper', 'Paper', paper, 1.2, .7),
  StudioDecorationSpec('new-motif', 'Motif', sticker, 1, .3,
    assetPath: 'assets/sticker/new-motif.webp'),
];
''')
        self.asset(root, 'assets/sticker/new-motif.webp', b'material-raster')
        return root

    def asset(self, root: Path, path: str, data: bytes) -> None:
        file = root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(data)

    def manifest(self, root: Path, documents: dict[str, dict]) -> None:
        hashes = {}
        for identity, document in documents.items():
            raw = json.dumps(document).encode()
            hashes[identity] = hashlib.sha256(raw).hexdigest()
            target = root / f'assets/templates/detail_documents/{identity}.test-layout.json.gz'
            target.write_bytes(gzip.compress(raw))
        (root / 'assets/templates/detail_documents/manifest.json').write_text(json.dumps({
            'layoutRevision': 'test-layout', 'documents': hashes,
        }))

    def book(self, photo: str, frame: str = 'newFrame') -> dict:
        return {
            'title': 'New book', 'category': '취미·기록',
            'includedMaterialKeys': ['sticker:new-paper', 'sticker:new-motif',
                                     'phrase:collage-new-title', f'frame:{frame}'],
            'pages': [{'layers': [
                {'type': 'image', 'imageUrl': photo, 'frame': frame},
                {'type': 'decoration', 'style': 'new-paper'},
                {'type': 'sticker', 'imageUrl': 'asset:assets/sticker/new-motif.webp'},
                {'type': 'text', 'payload': {'wordArtId': 'new-title'}},
            ]}],
        }

    def test_only_current_primary_books_count_and_material_bitmaps_are_not_photos(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            self.asset(root, 'assets/photos/old.jpg', b'old-photo')
            self.asset(root, 'assets/photos/new.jpg', b'new-photo')
            new = self.book('asset:assets/photos/new.jpg')
            new.pop('category')
            new['variants'] = {'square': {
                'category': '취미·기록',
                'layers': [{'type': 'image', 'payload': {
                    'imageUrl': 'assets/photos/new.jpg', 'imageBackground': 'newFrame',
                }, 'aspectOverrides': {'square': {'imageUrl': 'asset:assets/photos/new.jpg'}}}],
            }}
            self.manifest(root, {
                '-9301': {'title': 'Legacy wedding', 'pages': [{'layers': [
                    {'type': 'image', 'imageUrl': 'assets/photos/old.jpg'},
                ]}]},
                '-9772': new,
                '-9301-24': {'category': '잘못 세면 안 되는 분량 변형', 'layers': [
                    {'type': 'image', 'imageUrl': 'assets/photos/unavailable-variant.jpg'},
                ]},
            })
            # An unreferenced archive must not enter either the counts or hashes.
            (root / 'assets/templates/detail_documents/-9999.test-layout.json.gz').write_bytes(
                gzip.compress(json.dumps({'category': '보관된 과거 문서'}).encode()))
            report = audit_catalog(root, {'-9772'}, 1, ['웨딩', '취미·기록'])
            self.assertTrue(report['passed'], report['issues'])
            self.assertEqual(report['currentPrimaryBookCount'], 2)
            self.assertEqual(report['excludedPageCountVariants'], 1)
            self.assertEqual(report['categoryCounts'], {'웨딩': 1, '취미·기록': 1})
            self.assertEqual(report['newBooks'][0]['samplePhotoCount'], 1)
            self.assertEqual(set(report['sampleAssetSHA256']),
                             {'assets/photos/old.jpg', 'assets/photos/new.jpg'})
            self.assertTrue(report['newBooks'][0]['inventoryMatches'])

    def test_reuse_renamed_bytes_shared_kits_and_unused_declared_materials_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            self.asset(root, 'assets/photos/shared.jpg', b'identical-photo-bytes')
            self.asset(root, 'assets/photos/renamed.jpg', b'identical-photo-bytes')
            old = {'title': 'Existing book', 'category': '일상', 'layers': [
                {'type': 'image', 'imageUrl': 'assets/photos/shared.jpg', 'frame': 'sharedFrame'},
            ]}
            new = self.book('asset:assets/photos/shared.jpg', 'sharedFrame')
            new['includedMaterialKeys'][1] = 'sticker:unused-material'
            new['variants'] = {'wide': {'layers': [
                {'type': 'image', 'imageUrl': 'assets/photos/renamed.jpg', 'frame': 'sharedFrame'},
            ]}}
            self.manifest(root, {'-1': old, '-9772': new})
            report = audit_catalog(root, {'-9772'}, 2, ['일상', '취미·기록'])
            self.assertFalse(report['passed'])
            codes = {issue['code'] for issue in report['issues']}
            self.assertTrue({'new_photo_path_reused', 'new_photo_content_reused',
                             'new_kit_reused', 'new_inventory_mismatch',
                             'category_below_minimum'}.issubset(codes), report['issues'])
            mismatch = next(issue for issue in report['issues']
                            if issue['code'] == 'new_inventory_mismatch')
            self.assertEqual(mismatch['declaredButUnused'], ['sticker:unused-material'])
            self.assertEqual(mismatch['usedButUndeclared'], ['sticker:new-motif'])


if __name__ == '__main__':
    unittest.main()
