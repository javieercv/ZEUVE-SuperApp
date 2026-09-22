import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "clean_project.py"
spec = importlib.util.spec_from_file_location("clean_project", SCRIPT)
clean_project = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(clean_project)


class CleanProjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zeuve-clean-test-")
        self.root = Path(self.temp.name) / "ZEUVE_Test"
        (self.root / "Sources").mkdir(parents=True)
        (self.root / "Tests").mkdir()
        (self.root / "Scripts").mkdir()
        (self.root / "Package.swift").write_text("// fixture\n")
        engines = self.root / "Resources" / "Engines"
        engines.mkdir(parents=True)
        (engines / "engines.json").write_text('{"engines": []}\n')
        for rel in clean_project.REQUIRED_ENGINES:
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture\n")
            path.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(self.root), "--skip-size", *args],
            check=False,
            text=True,
            capture_output=True,
        )

    def test_dry_run_does_not_delete(self):
        target = self.root / ".build"
        target.mkdir()
        (target / "cache").write_text("x")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(target.exists())
        self.assertIn("SIMULACIÓN", result.stdout)

    def test_apply_removes_known_caches_and_temp_files(self):
        targets = [
            self.root / ".build",
            self.root / ".swiftpm",
            self.root / "ZEUVE.xcodeproj" / "xcuserdata",
            self.root / "Scripts" / "__pycache__",
        ]
        for target in targets:
            target.mkdir(parents=True, exist_ok=True)
            (target / "cache").write_text("x")
        ds_store = self.root / ".DS_Store"
        ds_store.write_text("x")

        result = self.run_script("--apply")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for target in targets:
            self.assertFalse(target.exists())
        self.assertFalse(ds_store.exists())

    def test_logs_are_preserved_unless_explicitly_requested(self):
        log = self.root / "Scripts" / "diagnostic.log"
        log.write_text("diagnostic")
        self.assertEqual(self.run_script("--apply").returncode, 0)
        self.assertTrue(log.exists())
        self.assertEqual(self.run_script("--apply", "--include-logs").returncode, 0)
        self.assertFalse(log.exists())

    def test_engine_bundle_is_never_collected_as_generic_temp_content(self):
        protected = self.root / "Resources" / "Engines" / ".DS_Store"
        protected.write_text("do not touch")
        cache = self.root / "Resources" / "Engines" / "nested" / "__pycache__"
        cache.mkdir(parents=True)
        (cache / "module.pyc").write_text("x")

        candidates = clean_project.collect_candidates(self.root, include_logs=True)

        self.assertNotIn(protected, candidates)
        self.assertNotIn(cache, candidates)
        self.assertEqual(self.run_script("--apply", "--include-logs").returncode, 0)
        self.assertTrue(protected.exists())
        self.assertTrue(cache.exists())
        self.assertEqual(clean_project.verify_project(self.root), [])

    def test_source_docs_and_tests_are_not_candidates(self):
        protected = [
            self.root / "Sources" / "Keep.swift",
            self.root / "Docs" / "Keep.md",
            self.root / "Tests" / "Keep.py",
        ]
        for path in protected:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("keep")
        candidates = clean_project.collect_candidates(self.root, include_logs=False)
        self.assertTrue(all(path not in candidates for path in protected))

    def test_invalid_root_is_rejected(self):
        invalid = Path(self.temp.name) / "not-zeuve"
        invalid.mkdir()
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(invalid), "--skip-size"],
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("raíz ZEUVE válida", result.stderr)


if __name__ == "__main__":
    unittest.main()
