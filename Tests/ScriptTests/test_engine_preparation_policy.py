from pathlib import Path
import unittest


class EnginePreparationPolicyTests(unittest.TestCase):
    def test_calibre_license_uses_existing_license_file(self) -> None:
        script = Path("Scripts/prepare_engines_macos.sh").read_text()
        self.assertIn(
            "https://raw.githubusercontent.com/kovidgoyal/calibre/v${CALIBRE_VERSION}/LICENSE",
            script,
        )
        self.assertNotIn(
            "https://raw.githubusercontent.com/kovidgoyal/calibre/v${CALIBRE_VERSION}/COPYING",
            script,
        )
        self.assertIn('$DOWNLOADS/licenses/calibre/LICENSE', script)
        self.assertIn('$STAGING/licenses/calibre/LICENSE', script)
        self.assertIn('CALIBRE_LICENSE_REL="licenses/calibre/LICENSE"', script)

    def test_x264_uses_supported_static_install_target(self) -> None:
        script = Path("Scripts/prepare_engines_macos.sh").read_text()
        self.assertIn("make install-lib-static", script)
        self.assertNotIn("make install-lib-static install-headers", script)
        self.assertNotIn("make install-headers", script)


if __name__ == "__main__":
    unittest.main()
