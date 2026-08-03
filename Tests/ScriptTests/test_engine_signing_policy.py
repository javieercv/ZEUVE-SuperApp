import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class EngineSigningPolicyTests(unittest.TestCase):
    def test_yt_dlp_keeps_original_signature(self):
        script = (ROOT / "Scripts/sign_embedded_engines.sh").read_text()
        preserved = script.split("PRESERVED_EXECUTABLES=(", 1)[1].split(")", 1)[0]
        resigned = script.split("RESIGNED_EXECUTABLES=(", 1)[1].split(")", 1)[0]

        self.assertIn('"yt-dlp/yt-dlp_macos"', preserved)
        self.assertNotIn("yt-dlp", resigned)
        self.assertIn('for relative in "${RESIGNED_EXECUTABLES[@]}"', script)
        self.assertIn("codesign --force --options runtime", script)
        self.assertIn('verify_packaged_engines_macos.sh" "$APP_PATH"', script)

    def test_packaged_verifier_runs_yt_dlp_version(self):
        script = (ROOT / "Scripts/verify_packaged_engines_macos.sh").read_text()
        self.assertIn('YTDLP="$ENGINE_ROOT/yt-dlp/yt-dlp_macos"', script)
        self.assertIn('"$YTDLP" --version', script)
        self.assertIn("codesign --verify --strict", script)
        self.assertIn("bundleSHA256", script)
        self.assertIn("bundleFileCount", script)
        self.assertIn("exit 1", script)

    def test_terminal_build_rechecks_final_app(self):
        script = (ROOT / "Scripts/build_macos.sh").read_text()
        self.assertIn('APP_PATH="build/DerivedData/Build/Products/$CONFIGURATION/ZEUVE.app"', script)
        self.assertIn('verify_packaged_engines_macos.sh "$APP_PATH"', script)


if __name__ == "__main__":
    unittest.main()
