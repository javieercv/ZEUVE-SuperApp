from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class VersioningPolicyTests(unittest.TestCase):
    def test_zeuve_uses_four_component_release_version(self):
        version = (ROOT / "VERSION").read_text().strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+\.\d+$")
        rules = (ROOT / "SUPERAPP_PROJECT_RULES.md").read_text()
        self.assertIn("MAJOR.MINOR.PATCH.REVISION", rules)
        self.assertIn("CFBundleShortVersionString`/`MARKETING_VERSION`", rules)

    def test_xcode_keeps_apple_three_component_marketing_version(self):
        version = (ROOT / "VERSION").read_text().strip().split(".")
        marketing = ".".join(version[:3])
        revision = version[3]
        generator = (ROOT / "Scripts/generate_xcode_project.py").read_text()
        project = (ROOT / "ZEUVE.xcodeproj/project.pbxproj").read_text()
        for text in (generator, project):
            self.assertIn(f"MARKETING_VERSION = {marketing};", text)
            self.assertIn(f"INFOPLIST_KEY_ZEUVEReleaseRevision = {revision};", text)
        product_info = (ROOT / "Sources/ZEUVECore/ZEUVEProductInfo.swift").read_text()
        self.assertIn('"ZEUVEReleaseRevision"', product_info)
        self.assertIn("releaseVersion", product_info)

    def test_module_manifests_keep_three_component_semver(self):
        manifest_contract = (ROOT / "Sources/ZEUVECore/ModuleManifest.swift").read_text()
        self.assertIn("MAJOR.MINOR.PATCH", manifest_contract)
        self.assertNotIn("MAJOR.MINOR.PATCH.REVISION", manifest_contract)
        for manifest in (ROOT / "Sources").glob("*Module/Resources/manifest.json"):
            match = re.search(r'"version"\s*:\s*"([^"]+)"', manifest.read_text())
            self.assertIsNotNone(match, manifest)
            self.assertRegex(match.group(1), r"^\d+\.\d+\.\d+$", manifest)


if __name__ == "__main__":
    unittest.main()
