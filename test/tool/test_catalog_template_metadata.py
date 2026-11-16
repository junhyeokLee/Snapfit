"""Regression for reading the shipped detail URL rather than its old decoy."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'catalog_template_metadata_generator', ROOT / 'tool/generate_catalog_template_metadata.py'
)
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


class CatalogTemplateMetadataTest(unittest.TestCase):
    def test_versioned_detail_wins_over_preserved_legacy_document(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / 'lib/core/data'
            directory = root / 'assets/templates/detail_documents'
            data.mkdir(parents=True)
            directory.mkdir(parents=True)
            preview = {'profile': {'photoSlotCount': 33}}
            (data / 'catalog_preview_documents.g.dart').write_text(
                'const catalogPreviewDocuments = <int, String>{\n  -9443:\n      '
                + json.dumps(json.dumps(preview)) + ',\n};\n'
            )
            # Both URLs remain available; only the content-versioned one is live.
            raw = json.dumps({'designWidth': 500, 'designHeight': 400}).encode()
            digest = hashlib.sha256(raw).hexdigest()
            revision = digest[:16]
            (directory / f'-9443.redp-five-sizes-v1.{revision}.json.gz').write_bytes(gzip.compress(raw))
            (directory / '-9443.redp-five-sizes-v1.json.gz').write_bytes(gzip.compress(
                json.dumps({'designWidth': 500, 'designHeight': 500}).encode()
            ))
            (directory / 'manifest.json').write_text(json.dumps({
                'layoutRevision': 'redp-five-sizes-v1',
                'artworkRevisions': {'-9443': revision},
                'documents': {'-9443': digest},
            }))
            with patch.object(generator, 'ROOT', root):
                output = generator.generate()
            facts = json.loads(output.split("r'''\n", 1)[1].rsplit("\n''';", 1)[0])
            self.assertEqual(facts['-9443']['ratios'], [1.25])
            self.assertEqual(facts['-9443']['profile']['photoSlotCount'], 33)


if __name__ == '__main__':
    unittest.main()
