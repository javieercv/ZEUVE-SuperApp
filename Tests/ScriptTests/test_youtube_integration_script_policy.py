import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class YouTubeIntegrationScriptPolicyTests(unittest.TestCase):
    def test_cache_uses_owned_temporary_workspace(self):
        script = (ROOT / "Scripts/run_youtube_integration_tests_macos.sh").read_text()
        self.assertIn('TEMP="$(mktemp -d -t zeuve-youtube-integration)"', script)
        self.assertIn('--cache-dir "$TEMP/cache"', script)
        self.assertNotIn('$WORK/cache', script)

    def test_script_remains_explicitly_opt_in_and_macos_arm64_only(self):
        script = (ROOT / "Scripts/run_youtube_integration_tests_macos.sh").read_text()
        self.assertIn('ZEUVE_ENABLE_YOUTUBE_INTEGRATION_TESTS', script)
        self.assertIn('ZEUVE_YOUTUBE_TEST_URL', script)
        self.assertIn('uname -s', script)
        self.assertIn('uname -m', script)
        self.assertIn('Darwin', script)
        self.assertIn('arm64', script)


if __name__ == "__main__":
    unittest.main()
