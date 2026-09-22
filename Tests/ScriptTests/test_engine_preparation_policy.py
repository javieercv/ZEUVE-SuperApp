from pathlib import Path
import unittest


class EnginePreparationPolicyTests(unittest.TestCase):
    def test_removed_converters_are_not_prepared(self) -> None:
        script = Path("Scripts/prepare_engines_macos.sh").read_text()
        for forbidden in [
            "CALIBRE_VERSION",
            "calibre-ebook.com",
            "ebook-convert",
            "GHOSTSCRIPT_VERSION",
            "ghostscript/bin/gs",
            "ghostpdl-downloads",
        ]:
            self.assertNotIn(forbidden, script)
        self.assertNotIn('"calibre"', script)
        self.assertNotIn('"ghostscript"', script)

    def test_pandoc_remains_for_text_and_markup(self) -> None:
        script = Path("Scripts/prepare_engines_macos.sh").read_text()
        self.assertIn('PANDOC_VERSION="3.10"', script)
        self.assertIn("'Convertir texto, Markdown y HTML de forma local.'", script)
        self.assertNotIn("Markdown, HTML y EPUB", script)

    def test_x264_uses_supported_static_install_target(self) -> None:
        script = Path("Scripts/prepare_engines_macos.sh").read_text()
        self.assertIn("make install-lib-static", script)
        self.assertNotIn("make install-lib-static install-headers", script)
        self.assertNotIn("make install-headers", script)


if __name__ == "__main__":
    unittest.main()
