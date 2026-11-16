import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('build_android', Path(__file__).resolve().parents[2] / 'tool/build_android.py')
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class PackageResetTest(unittest.TestCase):
    def test_only_selected_generated_apk_state_is_removed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            removed = ['build/app/intermediates/incremental/packageDebug/cache', 'build/app/outputs/apk/debug/app-debug.apk', 'build/app/outputs/flutter-apk/app-debug.apk', 'build/app/outputs/flutter-apk/app-debug.apk.sha1']
            preserved = ['assets/original-photo.png', 'albums/saved.json', 'build/review-web/index.html', 'build/app/outputs/apk/release/app-release.apk', 'build/app/intermediates/flutter/debug/kernel_blob.bin']
            for name in removed + preserved:
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(name.encode())
            BUILD.reset_apk_package(root, 'debug')
            for name in removed:
                self.assertFalse((root / name).exists(), name)
            for name in preserved:
                self.assertEqual((root / name).read_bytes(), name.encode())

    def test_linked_package_state_is_refused_before_any_deletion(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sentinel = root / 'precious'; sentinel.mkdir()
            (sentinel / 'photo').write_bytes(b'original')
            linked = root / 'build/app/outputs/apk/debug'
            linked.parent.mkdir(parents=True)
            linked.symlink_to(sentinel, target_is_directory=True)
            with self.assertRaises(RuntimeError):
                BUILD.reset_apk_package(root, 'debug')
            self.assertEqual((sentinel / 'photo').read_bytes(), b'original')

    def test_linked_parent_cannot_redirect_cleanup_outside_build(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sentinel = root / 'photos'; sentinel.mkdir()
            (sentinel / 'debug').mkdir()
            (sentinel / 'debug/original').write_bytes(b'original')
            linked = root / 'build/app/outputs/apk'
            linked.parent.mkdir(parents=True)
            linked.symlink_to(sentinel, target_is_directory=True)
            package = root / 'build/app/intermediates/incremental/packageDebug'
            package.mkdir(parents=True)
            (package / 'cache').write_bytes(b'keep before refused cleanup')
            with self.assertRaises(RuntimeError):
                BUILD.reset_apk_package(root, 'debug')
            self.assertEqual((sentinel / 'debug/original').read_bytes(), b'original')
            self.assertTrue((package / 'cache').is_file())


if __name__ == '__main__':
    unittest.main()
