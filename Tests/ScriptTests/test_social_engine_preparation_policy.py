from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
import unittest


class SocialEnginePreparationPolicyTests(unittest.TestCase):
    def test_normal_build_requires_but_does_not_prepare_missing_social_engines(self) -> None:
        build = Path("Scripts/build_macos.sh").read_text()
        self.assertIn("Scripts/check_social_engines.py Resources/Engines", build)
        self.assertNotIn("\nScripts/prepare_social_engines_macos.sh Resources/Engines", build)
        self.assertIn("Scripts/verify_engines_macos.sh", build)


    def test_xcode_build_requires_but_does_not_prepare_missing_social_engines(self) -> None:
        generator = Path("Scripts/generate_xcode_project.py").read_text()
        project = Path("ZEUVE.xcodeproj/project.pbxproj").read_text()
        for text in (generator, project):
            self.assertIn("Verificar motores sociales", text)
            self.assertIn("check_social_engines.py", text)
            self.assertNotIn('"${SRCROOT}/Scripts/prepare_social_engines_macos.sh"', text)
        self.assertLess(
            project.index("Verificar motores sociales */,"),
            project.index("Sources */,"),
        )


    def test_checker_rejects_stale_instaloader_revision(self) -> None:
        with tempfile.TemporaryDirectory(prefix="zeuve-social-check-") as temporary:
            root = Path(temporary)
            (root / "gallery-dl").mkdir()
            (root / "instaloader").mkdir()
            (root / "licenses/gallery-dl").mkdir(parents=True)
            (root / "licenses/instaloader").mkdir(parents=True)
            gallery = root / "gallery-dl/gallery-dl"
            instagram = root / "instaloader/instaloader-zeuve"
            gallery.write_bytes(b"gallery")
            instagram.write_bytes(b"instagram-old")
            (root / "licenses/gallery-dl/LICENSE").write_text("license")
            (root / "licenses/instaloader/LICENSE").write_text("license")
            manifest = {
                "schemaVersion": 1,
                "engines": [
                    {
                        "name": "gallery-dl",
                        "relativePath": "gallery-dl/gallery-dl",
                        "licenseFile": "licenses/gallery-dl/LICENSE",
                        "version": "1.32.9",
                        "sha256": hashlib.sha256(b"gallery").hexdigest(),
                        "size": len(b"gallery"),
                    },
                    {
                        "name": "instaloader-zeuve",
                        "relativePath": "instaloader/instaloader-zeuve",
                        "licenseFile": "licenses/instaloader/LICENSE",
                        "version": "4.15.2-zeuve.3",
                        "sha256": hashlib.sha256(b"instagram-old").hexdigest(),
                        "size": len(b"instagram-old"),
                    },
                ],
            }
            (root / "engines.json").write_text(json.dumps(manifest))

            completed = subprocess.run(
                ["python3", "Scripts/check_social_engines.py", str(root), "--print-missing"],
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("instaloader-zeuve", completed.stdout)

    def test_social_preparation_refreshes_manifest_after_validation(self) -> None:
        prepare = Path("Scripts/prepare_social_engines_macos.sh").read_text()
        self.assertIn("refresh_social_engine_manifest.py", prepare)
        self.assertIn('if [[ -f "$STAGING/engines.json" ]]', prepare)
        self.assertIn('rm -rf "$VENV" "$DIST" "$WORK" "$SPEC" "$STAGING/gallery-dl" "$STAGING/instaloader"', prepare)
        self.assertLess(
            prepare.index('"$STAGING/instaloader/instaloader-zeuve" --version'),
            prepare.index("refresh_social_engine_manifest.py"),
        )

    def test_complete_preparation_can_generate_manifest_after_social_engines(self) -> None:
        complete = Path("Scripts/prepare_engines_macos.sh").read_text()
        social = Path("Scripts/prepare_social_engines_macos.sh").read_text()
        self.assertLess(
            complete.index('"$ROOT/Scripts/prepare_social_engines_macos.sh" "$STAGING"'),
            complete.index("(engines / 'engines.json').write_text"),
        )
        self.assertIn('if [[ -f "$STAGING/engines.json" ]]', social)

    def test_manifest_refresher_replaces_only_social_placeholders(self) -> None:
        with tempfile.TemporaryDirectory(prefix="zeuve-social-manifest-") as temporary:
            root = Path(temporary)
            (root / "gallery-dl").mkdir()
            (root / "instaloader").mkdir()
            (root / "licenses/gallery-dl").mkdir(parents=True)
            (root / "licenses/instaloader").mkdir(parents=True)
            gallery = root / "gallery-dl/gallery-dl"
            instagram = root / "instaloader/instaloader-zeuve"
            gallery.write_bytes(b"gallery")
            instagram.write_bytes(b"instagram")
            (root / "licenses/gallery-dl/LICENSE").write_text("license")
            (root / "licenses/instaloader/LICENSE").write_text("license")
            untouched = {
                "name": "yt-dlp",
                "relativePath": "yt-dlp/yt-dlp_macos",
                "sha256": "1" * 64,
                "size": 123,
            }
            placeholder = lambda name, path, license_path: {
                "name": name,
                "relativePath": path,
                "licenseFile": license_path,
                "version": "placeholder",
                "sha256": "0" * 64,
                "size": 0,
                "architecture": "arm64",
                "requirement": "optional",
            }
            manifest = {
                "schemaVersion": 1,
                "engines": [
                    untouched.copy(),
                    placeholder("gallery-dl", "gallery-dl/gallery-dl", "licenses/gallery-dl/NOT_PROVIDED.txt"),
                    placeholder("instaloader-zeuve", "instaloader/instaloader-zeuve", "licenses/instaloader/NOT_PROVIDED.txt"),
                ],
            }
            (root / "engines.json").write_text(json.dumps(manifest))

            subprocess.run(
                ["python3", "Scripts/refresh_social_engine_manifest.py", str(root)],
                check=True,
            )
            refreshed = json.loads((root / "engines.json").read_text())
            entries = {item["name"]: item for item in refreshed["engines"]}
            self.assertEqual(entries["yt-dlp"], untouched)
            self.assertEqual(entries["gallery-dl"]["sha256"], hashlib.sha256(b"gallery").hexdigest())
            self.assertEqual(entries["gallery-dl"]["size"], len(b"gallery"))
            self.assertEqual(entries["gallery-dl"]["licenseFile"], "licenses/gallery-dl/LICENSE")
            self.assertEqual(entries["gallery-dl"]["requirement"], "required")
            self.assertEqual(entries["instaloader-zeuve"]["sha256"], hashlib.sha256(b"instagram").hexdigest())
            self.assertEqual(entries["instaloader-zeuve"]["version"], "4.15.3-zeuve.2")
            self.assertEqual(entries["instaloader-zeuve"]["requirement"], "required")


    def test_preparation_pins_instaloader_profile_resolution_fix(self) -> None:
        social = Path("Scripts/prepare_social_engines_macos.sh").read_text()
        complete = Path("Scripts/prepare_engines_macos.sh").read_text()
        helper = Path("Scripts/engine_helpers/instagram_catalog.py").read_text()
        checker = Path("Scripts/check_social_engines.py").read_text()
        refresher = Path("Scripts/refresh_social_engine_manifest.py").read_text()
        self.assertIn('INSTALOADER_VERSION="4.15.3"', social)
        self.assertIn('INSTALOADER_VERSION="4.15.3"', complete)
        for current in (social, helper, checker, refresher):
            self.assertIn("4.15.3-zeuve.2", current)

    def test_manifest_never_treats_stale_instaloader_as_current(self) -> None:
        root = Path("Resources/Engines")
        manifest = json.loads((root / "engines.json").read_text())
        matches = [item for item in manifest["engines"] if item["name"] == "instaloader-zeuve"]
        if not matches:
            return
        entry = matches[0]
        self.assertEqual(entry["version"], "4.15.3-zeuve.2")
        self.assertEqual(entry["source"], "https://pypi.org/project/instaloader/4.15.3/")
        executable = root / entry["relativePath"]
        if executable.is_file():
            self.assertGreater(entry["size"], 0)
            self.assertNotEqual(entry["sha256"], "0" * 64)
        else:
            self.assertEqual(entry["size"], 0)
            self.assertEqual(entry["sha256"], "0" * 64)
            self.assertEqual(entry["licenseFile"], "licenses/instaloader/NOT_PROVIDED.txt")



if __name__ == "__main__":
    unittest.main()
