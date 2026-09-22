from __future__ import annotations

import importlib.util
import io
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "Scripts/engine_helpers/instagram_catalog.py"
SPEC = importlib.util.spec_from_file_location("zeuve_instagram_catalog", HELPER)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ProfileNotExistsException(Exception):
    pass


class LoginRequiredException(Exception):
    pass


class InstagramCatalogHelperTests(unittest.TestCase):
    def test_instaloader_not_found_response_is_inconclusive_without_session(self) -> None:
        result = MODULE.classify_profile_lookup_error(
            ProfileNotExistsException("Profile mar.rullan does not exist."),
            session_supplied=False,
            session_validated=None,
        )
        self.assertEqual(result["code"], "profile_lookup_ambiguous")
        self.assertFalse(result["requires_authentication"])
        self.assertFalse(result["session_supplied"])
        self.assertNotIn("no existe", result["message"].lower())

    def test_rejected_session_is_reported_before_profile_absence(self) -> None:
        result = MODULE.classify_profile_lookup_error(
            ProfileNotExistsException("Profile mar.rullan does not exist."),
            session_supplied=True,
            session_validated=False,
        )
        self.assertEqual(result["code"], "session_not_validated")
        self.assertFalse(result["requires_authentication"])
        self.assertTrue(result["session_supplied"])
        self.assertFalse(result["session_validated"])

    def test_login_required_is_explicit(self) -> None:
        result = MODULE.classify_profile_lookup_error(
            LoginRequiredException("Login required"),
            session_supplied=False,
            session_validated=None,
        )
        self.assertEqual(result["code"], "public_lookup_blocked")
        self.assertFalse(result["requires_authentication"])
        self.assertIn("consulta pública", result["message"])


    def test_public_profile_skips_stories_and_highlights_without_session(self) -> None:
        class FakeContext:
            username = None

        class FakeLoader:
            def __init__(self, **_kwargs):
                self.context = FakeContext()

            def test_login(self):
                return None

            def get_stories(self, **_kwargs):
                raise AssertionError("Stories must not be queried without a validated session")

            def get_highlights(self, _profile):
                raise AssertionError("Highlights must not be queried without a validated session")

        class FakeProfile:
            username = "zeuve"
            full_name = "ZEUVE"
            biography = ""
            is_private = False
            followed_by_viewer = False
            profile_pic_url = "https://cdn.example/avatar.jpg"
            profile_pic_url_no_iphone = "https://cdn.example/avatar.jpg"
            mediacount = 0
            userid = 123

            @staticmethod
            def from_username(_context, _username):
                return FakeProfile()

            def get_posts(self):
                return []

            def get_reels(self):
                return []

        fake_instaloader = SimpleNamespace(Instaloader=FakeLoader, Profile=FakeProfile)
        args = SimpleNamespace(
            username="zeuve", limit=24, offset=0, cursor=None,
            stories=True, highlights=True, reels=True, profile_picture=True,
            cookies=None, cookie_header_file=None, browser=None, browser_cookie_file=None,
        )
        output = io.StringIO()
        with patch.dict(sys.modules, {"instaloader": fake_instaloader}), patch("sys.stdout", output):
            result = MODULE.catalog(args)
        self.assertEqual(result, 0)
        records = [MODULE.json.loads(line) for line in output.getvalue().splitlines()]
        restricted = {(item.get("section"), item.get("code")) for item in records if item.get("record") == "warning"}
        self.assertIn(("stories", "section_requires_authentication"), restricted)
        self.assertIn(("highlights", "section_requires_authentication"), restricted)
        profile = next(item for item in records if item.get("record") == "profile")
        self.assertFalse(profile["requires_authentication"])

    def test_unknown_failure_remains_non_conclusive(self) -> None:
        result = MODULE.classify_profile_lookup_error(
            RuntimeError("unexpected response"),
            session_supplied=False,
            session_validated=None,
        )
        self.assertEqual(result["code"], "profile_lookup_failed")
        self.assertFalse(result["requires_authentication"])

    def test_direct_mixed_carousel_emits_every_original_node(self) -> None:
        class FakeContext:
            pass

        class FakeLoader:
            def __init__(self, **_kwargs):
                self.context = FakeContext()

        class FakeNode:
            def __init__(self, index: int, is_video: bool):
                self.is_video = is_video
                self.display_url = f"https://cdn.example/{index}.jpg"
                self.video_url = f"https://cdn.example/{index}.mp4"

        class FakePostValue:
            owner_username = "zeuve"
            mediaid = 900
            shortcode = "MixedCarousel"
            date_utc = None
            caption = ""
            accessibility_caption = ""
            typename = "GraphSidecar"
            is_video = False

            def get_sidecar_nodes(self):
                return [FakeNode(1, False), FakeNode(2, True), FakeNode(3, False)]

        class FakePost:
            @staticmethod
            def from_shortcode(_context, shortcode):
                self.assertEqual(shortcode, "MixedCarousel")
                return FakePostValue()

        fake_instaloader = SimpleNamespace(Instaloader=FakeLoader, Post=FakePost)
        args = SimpleNamespace(
            shortcode="MixedCarousel",
            source_url="https://www.instagram.com/p/MixedCarousel/",
            content_kind="post",
            cookies=None,
            cookie_header_file=None,
        )
        output = io.StringIO()
        with patch.dict(sys.modules, {"instaloader": fake_instaloader}), patch("sys.stdout", output):
            result = MODULE.direct(args)
        self.assertEqual(result, 0)
        records = [MODULE.json.loads(line) for line in output.getvalue().splitlines()]
        media = [item for item in records if item.get("record") == "media"]
        self.assertEqual(len(media), 3)
        self.assertEqual([item["kind"] for item in media], ["photo", "video", "photo"])
        self.assertEqual([item["extension"] for item in media], ["jpg", "mp4", "jpg"])
        self.assertEqual([item["index"] for item in media], [1, 2, 3])

    def test_media_extension_preserves_format_exposed_by_cdn(self) -> None:
        self.assertEqual(MODULE.media_extension("https://cdn.example/photo.webp?token=secret", "jpg"), "webp")
        self.assertEqual(MODULE.media_extension("https://cdn.example/video.mp4?token=secret", "mp4"), "mp4")
        self.assertEqual(MODULE.media_extension("https://cdn.example/media?token=secret", "jpg"), "jpg")

    def test_direct_ambiguous_login_does_not_force_session(self) -> None:
        result = MODULE.classify_direct_lookup_error(LoginRequiredException("Login required"))
        self.assertEqual(result["code"], "public_direct_lookup_blocked")
        self.assertFalse(result["requires_authentication"])


if __name__ == "__main__":
    unittest.main()
