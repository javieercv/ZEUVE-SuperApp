import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class EngineSigningPolicyTests(unittest.TestCase):
    def test_yt_dlp_keeps_original_signature(self):
        script = (ROOT / "Scripts/sign_embedded_engines.sh").read_text()
        preserved = script.split("PRESERVED_EXECUTABLES=(", 1)[1].split(")", 1)[0]
        resigned = script.split("RESIGNED_EXECUTABLES=(", 1)[1].split(")", 1)[0]

        self.assertIn('"yt-dlp/yt-dlp_macos"', preserved)
        self.assertIn('"deno/deno"', preserved)
        self.assertNotIn("yt-dlp", resigned)
        self.assertNotIn("deno/deno", resigned)
        self.assertIn('"gallery-dl/gallery-dl"', resigned)
        self.assertIn('"instaloader/instaloader-zeuve"', resigned)
        self.assertIn('social_engine.entitlements', script)
        self.assertIn('/bin/cp -p "$source_executable" "$executable"', script)
        self.assertIn('for relative in "${RESIGNED_EXECUTABLES[@]}"', script)
        self.assertIn("codesign --force --options runtime", script)
        self.assertIn('verify_packaged_engines_macos.sh" "$APP_PATH"', script)

    def test_packaged_verifier_runs_yt_dlp_version(self):
        script = (ROOT / "Scripts/verify_packaged_engines_macos.sh").read_text()
        self.assertIn('YTDLP="$ENGINE_ROOT/yt-dlp/yt-dlp_macos"', script)
        self.assertIn('"$YTDLP" --version', script)
        self.assertIn('"$DENO" eval', script)
        self.assertIn("ZEUVE_DENO_JIT_OK", script)
        self.assertIn("codesign --verify --strict", script)
        self.assertIn("bundleSHA256", script)
        self.assertIn("bundleFileCount", script)
        self.assertIn("exit 1", script)

    def test_terminal_build_rechecks_final_app(self):
        script = (ROOT / "Scripts/build_macos.sh").read_text()
        self.assertIn('APP_PATH="build/DerivedData/Build/Products/$CONFIGURATION/ZEUVE.app"', script)
        self.assertIn("clean build", script)
        self.assertIn('verify_packaged_engines_macos.sh "$APP_PATH"', script)
        self.assertIn('codesign --verify --deep --strict --verbose=2 "$APP_PATH"', script)


if __name__ == "__main__":
    unittest.main()
