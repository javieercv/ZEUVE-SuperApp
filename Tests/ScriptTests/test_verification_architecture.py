from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY_DIR = ROOT / "Scripts/verify"


def load_xcode_verifier():
    path = VERIFY_DIR / "xcode_integration.py"
    spec = importlib.util.spec_from_file_location("zeuve_xcode_integration", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerificationArchitectureTests(unittest.TestCase):
    def test_verify_project_is_a_small_orchestrator_without_inline_python(self) -> None:
        script = (ROOT / "Scripts/verify_project.sh").read_text()
        self.assertLess(len(script.splitlines()), 80)
        self.assertNotIn("python3 - <<", script)
        self.assertIn("Scripts/verify/app_integration.py", script)
        self.assertIn("Scripts/verify/xcode_integration.py", script)
        self.assertIn("Scripts/verify_app_macos.sh", script)

    def test_domain_verifiers_are_present(self) -> None:
        expected = {
            "app_integration.py",
            "app_sources.py",
            "project_structure.py",
            "engines.py",
            "documentation.py",
            "performance.py",
            "converter.py",
            "downloader.py",
            "chat_analyzer.py",
            "instagram_followers.py",
            "multimedia_inspector.py",
            "cleaner.py",
            "manifests.py",
            "xcode_integration.py",
        }
        self.assertTrue(expected.issubset({path.name for path in VERIFY_DIR.glob("*.py")}))

    def test_swiftpm_generator_and_pbx_are_currently_coherent(self) -> None:
        verifier = load_xcode_verifier()
        products = verifier.verify(ROOT)
        self.assertEqual(len(products), 11)
        self.assertIn("UniversalDownloaderModule", products)
        self.assertIn("InstagramFollowersModule", products)
        self.assertIn("MultimediaInspectorModule", products)
        self.assertIn("CleanerModule", products)

    def test_xcode_verifier_detects_a_missing_product(self) -> None:
        verifier = load_xcode_verifier()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Scripts").mkdir()
            (root / "ZEUVE.xcodeproj").mkdir()
            (root / "Package.swift").write_text(
                '.library(name: "ZEUVECore", targets: ["ZEUVECore"]),\n'
                '.library(name: "NewModule", targets: ["NewModule"]),\n'
            )
            (root / "Scripts/generate_xcode_project.py").write_text('products = ["ZEUVECore"]\n')
            (root / "ZEUVE.xcodeproj/project.pbxproj").write_text('productName = ZEUVECore;\n')
            with self.assertRaisesRegex(ValueError, "faltan en Xcode: NewModule"):
                verifier.verify(root)

    def test_macos_app_verifier_keeps_full_xcode_build_and_engine_check(self) -> None:
        script = (ROOT / "Scripts/verify_app_macos.sh").read_text()
        for required in [
            "Scripts/verify_engines_macos.sh",
            "Scripts/generate_xcode_project.py",
            "Scripts/verify/xcode_integration.py",
            "xcodebuild",
            "-destination 'platform=macOS,arch=arm64'",
        ]:
            self.assertIn(required, script)
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", script)


if __name__ == "__main__":
    unittest.main()
