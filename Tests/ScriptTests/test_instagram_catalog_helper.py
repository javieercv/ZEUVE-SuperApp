from __future__ import annotations

import importlib.util
import io
import http.cookiejar
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
import tempfile
import urllib.request
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
    def test_rate_limited_validation_stops_without_profile_or_anonymous_retry(self) -> None:
        class Loader:
            def __init__(self, **kwargs):
                self.context = SimpleNamespace(error_log=[])
                self.assert_fatal = kwargs["fatal_status_codes"]
            def test_login(self):
                self.context.error_log.append("HTTP 429 token=SYNTHETIC_CANARY")
                return None
        class Profile:
            @staticmethod
            def from_username(*args):
                raise AssertionError("No profile query after 429")
        args = SimpleNamespace(cookies=None, cookie_header_file="synthetic", browser=None, browser_cookie_file=None)
        out = io.StringIO()
        with patch.dict(sys.modules, {"instaloader": SimpleNamespace(Instaloader=Loader, Profile=Profile)}), patch.object(MODULE, "load_cookie_header", lambda *args: None), patch("sys.stdout", out):
            self.assertEqual(MODULE.catalog(args), 21)
        record = MODULE.json.loads(out.getvalue())
        self.assertEqual(record["code"], "session_request_blocked")
        self.assertIsNone(record["session_validated"])
        self.assertNotIn("SYNTHETIC_CANARY", out.getvalue())

    def test_authenticated_resolution_requires_exact_user_and_metadata_identity(self) -> None:
        class Profile:
            def __init__(self, context, node):
                self.username = node["username"]
                self.userid = int(node["id"])
            def _obtain_metadata(self):
                pass
            @staticmethod
            def from_username(*args):
                raise AssertionError("Validated session must use GraphQL metadata")
        context = SimpleNamespace(username="viewer", get_json=lambda *args: {"users": [
            {"user": {"username": "zeuve_other", "pk": "9"}},
            {"user": {"username": "ZEUVE", "pk": "123"}},
        ]})
        with patch.dict(sys.modules, {"instaloader": SimpleNamespace(Profile=Profile)}):
            result = MODULE.resolve_profile(SimpleNamespace(context=context), "zeuve")
            self.assertEqual(result.userid, 123)
            context.get_json = lambda *args: {"users": [{"user": {"username": "zeuve_other", "pk": "9"}}]}
            with self.assertRaises(RuntimeError):
                MODULE.resolve_profile(SimpleNamespace(context=context), "zeuve")
            context.get_json = lambda *args: {"users": [{"user": {"username": "zeuve", "pk": "123"}}]}
            def wrong_metadata(profile):
                profile.username = "different"
            with patch.object(Profile, "_obtain_metadata", wrong_metadata), self.assertRaises(RuntimeError):
                MODULE.resolve_profile(SimpleNamespace(context=context), "zeuve")

    def test_public_header_requires_profile_canonical_identity_and_never_uses_session(self) -> None:
        html = '<meta property="og:type" content="profile"><meta property="og:url" content="https://www.instagram.com/zeuve/"><meta property="og:image" content="https://cdn.example/avatar.jpg?a=1&amp;b=2">'
        response = SimpleNamespace(status_code=200, content=html.encode(), text=html)
        calls = []
        def get(*args, **kwargs):
            calls.append((args, kwargs))
            return response
        loader = SimpleNamespace(context=SimpleNamespace(username=None, _session=SimpleNamespace(get=get)))
        result = MODULE.public_profile_header(loader, "zeuve", 7)
        self.assertEqual(result["og:image"], "https://cdn.example/avatar.jpg?a=1&b=2")
        self.assertEqual(calls[0][1]["timeout"], 7)
        self.assertIsNone(MODULE.public_profile_header(loader, "different", 7))
        loader.context.username = "viewer"
        count = len(calls)
        self.assertIsNone(MODULE.public_profile_header(loader, "zeuve", 7))
        self.assertEqual(len(calls), count)
        loader.context.username = None
        response.status_code = 429
        self.assertIsNone(MODULE.public_profile_header(loader, "zeuve", 7))

    def test_highlight_mobile_metadata_absence_keeps_authorized_graphql_items(self) -> None:
        context = SimpleNamespace(iphone_support=True)
        class Highlight:
            unique_id = 9
            owner_profile = SimpleNamespace(userid=123)
            _items = [{"id": "1", "owner": {"id": "123"}}, {"id": "2"}]
            def get_items(self):
                raise KeyError("highlight:9")
        def story_item(ctx, node, owner):
            self.assertFalse(ctx.iphone_support)
            return node["id"]
        with patch.dict(sys.modules, {"instaloader": SimpleNamespace(StoryItem=story_item)}):
            self.assertEqual(list(MODULE.highlight_items(Highlight(), context)), ["1", "2"])
            self.assertTrue(context.iphone_support)
            iterator = iter(MODULE.highlight_items(Highlight(), context))
            next(iterator)
            iterator.close()
            self.assertTrue(context.iphone_support)
            with patch.object(Highlight, "_items", [{"id": "3", "owner": {"id": "999"}}]), self.assertRaises(RuntimeError):
                list(MODULE.highlight_items(Highlight(), context))
            self.assertTrue(context.iphone_support)
            with patch.object(Highlight, "get_items", side_effect=RuntimeError("HTTP 429")), self.assertRaises(RuntimeError):
                list(MODULE.highlight_items(Highlight(), context))

    def test_imported_session_replaces_anonymous_cookie_without_foreign_domains(self) -> None:
        class Jar(http.cookiejar.CookieJar):
            def set(self, name, value, domain="", path="/"):
                self.set_cookie(http.cookiejar.Cookie(0, name, value, None, False, domain,
                    bool(domain), domain.startswith("."), path, True, False, None, True, None, None, {}, False))

        for mode in ("header", "netscape"):
            jar = Jar()
            jar.set("sessionid", "")
            jar.set("csrftoken", "")
            context = SimpleNamespace(_session=SimpleNamespace(cookies=jar, headers={}))
            with tempfile.TemporaryDirectory() as temp:
                file = Path(temp) / "session.txt"
                if mode == "header":
                    file.write_text("Cookie: sessionid=SYNTHETIC_SESSION; csrftoken=SYNTHETIC_CSRF")
                    MODULE.load_cookie_header(context, str(file))
                else:
                    file.write_text("# Netscape HTTP Cookie File\n.instagram.com\tTRUE\t/\tFALSE\t0\tsessionid\tSYNTHETIC_SESSION\n.instagram.com\tTRUE\t/\tFALSE\t0\tcsrftoken\tSYNTHETIC_CSRF\n.instagram.com.evil.example\tTRUE\t/\tFALSE\t0\tforeign\tFORBIDDEN\n")
                    MODULE.load_netscape_cookies(context, str(file))
            request = urllib.request.Request("https://www.instagram.com/")
            jar.add_cookie_header(request)
            header = request.get_header("Cookie")
            self.assertEqual(header.count("sessionid="), 1)
            self.assertIn("sessionid=SYNTHETIC_SESSION", header)
            self.assertNotIn("foreign", str([(c.name, c.domain) for c in jar]))
            self.assertEqual(context._session.headers["X-CSRFToken"], "SYNTHETIC_CSRF")

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

    def test_full_anonymous_page_keeps_auth_restrictions_without_querying_them(self) -> None:
        class Loader:
            def __init__(self, **kwargs):
                self.context = SimpleNamespace(username=None)
            def get_stories(self, **kwargs):
                raise AssertionError("No anonymous Stories query")
            def get_highlights(self, profile):
                raise AssertionError("No anonymous highlights query")
        profile = SimpleNamespace(username="zeuve", full_name="ZEUVE", biography="", is_private=False,
            followed_by_viewer=False, profile_pic_url="https://cdn.example/avatar.jpg",
            profile_pic_url_no_iphone="https://cdn.example/avatar.jpg", mediacount=1, userid=123,
            get_posts=lambda: [object()], get_reels=lambda: [])
        args = SimpleNamespace(username="zeuve", limit=1, offset=0, cursor=None,
            stories=True, highlights=True, reels=True, profile_picture=True,
            cookies=None, cookie_header_file=None, browser=None, browser_cookie_file=None)
        output = io.StringIO()
        fake = SimpleNamespace(Instaloader=Loader, Profile=SimpleNamespace(from_username=lambda *args: profile))
        post = {"record": "media", "section": "posts", "id": "1", "kind": "photo", "media_url": "https://cdn.example/photo.jpg"}
        with patch.dict(sys.modules, {"instaloader": fake}), patch.object(MODULE, "post_records", return_value=[post]), patch("sys.stdout", output):
            self.assertEqual(MODULE.catalog(args), 0)
        records = [MODULE.json.loads(line) for line in output.getvalue().splitlines()]
        restricted = {r.get("section") for r in records if r.get("code") == "section_requires_authentication"}
        self.assertEqual(restricted, {"stories", "highlights"})
        page = next(r for r in records if r.get("record") == "page")
        self.assertTrue(page["has_more"])
        self.assertEqual(page["next_cursor"], "1")
        self.assertEqual(page["returned"], 1)

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

    def test_section_errors_are_safe_and_network_is_not_authentication(self) -> None:
        for section in ("posts", "stories", "highlights"):
            value = MODULE.section_failure(RuntimeError("HTTP 429 https://example.com/private?token=SYNTHETIC_CANARY"), section)
            self.assertEqual(value["code"], "section_request_blocked")
            self.assertNotIn("SYNTHETIC_CANARY", MODULE.json.dumps(value))
        value = MODULE.section_failure(LoginRequiredException("Login required"), "stories")
        self.assertEqual(value["code"], "section_requires_authentication")

    def test_anonymous_fallback_clears_validated_session_and_preserves_partial_media(self) -> None:
        loaders = []
        story_calls = []

        class FakeLoader:
            def __init__(self, **kwargs):
                self.context = SimpleNamespace(username=None, index=len(loaders))
                loaders.append((self.context, kwargs))

            def test_login(self):
                return "synthetic_user"

            def get_stories(self, **kwargs):
                story_calls.append(self.context.index)
                raise AssertionError("Anonymous loader must not query Stories")

            def get_highlights(self, profile):
                raise AssertionError("Anonymous loader must not query Highlights")

        class FakeProfile:
            username = "zeuve"
            full_name = "ZEUVE"
            biography = ""
            is_private = False
            followed_by_viewer = False
            profile_pic_url = "https://cdn.example/avatar.jpg"
            profile_pic_url_no_iphone = profile_pic_url
            mediacount = 1
            userid = 123
            has_public_story = True

            @staticmethod
            def from_username(context, username):
                if context.index == 0:
                    raise RuntimeError("synthetic authenticated endpoint blocked")
                return FakeProfile()

            def get_posts(self):
                # An eager failure previously escaped add_posts before its try.
                raise RuntimeError("HTTP 429 token=SYNTHETIC_CANARY")

            def get_reels(self):
                return []

        args = SimpleNamespace(username="zeuve", limit=24, offset=0, cursor=None,
            stories=True, highlights=True, reels=True, profile_picture=True,
            cookies=None, cookie_header_file="synthetic", browser=None, browser_cookie_file=None, request_timeout=7)
        output = io.StringIO()
        fake = SimpleNamespace(Instaloader=FakeLoader, Profile=FakeProfile)
        with patch.dict(sys.modules, {"instaloader": fake}), patch.object(MODULE, "load_cookie_header", lambda *args: None), patch("sys.stdout", output):
            self.assertEqual(MODULE.catalog(args), 0)
        records = [MODULE.json.loads(line) for line in output.getvalue().splitlines()]
        profile = next(r for r in records if r.get("record") == "profile")
        self.assertFalse(profile["session_validated"])
        self.assertEqual(story_calls, [])
        self.assertTrue(all(kwargs["request_timeout"] == 7 for _, kwargs in loaders))
        self.assertNotIn("SYNTHETIC_CANARY", output.getvalue())
        media_index = next(i for i, r in enumerate(records) if r.get("record") == "media")
        warning_index = next(i for i, r in enumerate(records) if r.get("section") == "posts")
        self.assertLess(media_index, warning_index)
        self.assertEqual(records[media_index]["kind"], "profilePicture")

    def test_netscape_export_uses_empty_session_expiry(self) -> None:
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.txt"
            jar = MODULE.http.cookiejar.MozillaCookieJar(str(path))
            jar.set_cookie(MODULE.http.cookiejar.Cookie(0, "sessionid", "SYNTHETIC", None, False,
                ".instagram.com", True, True, "/", True, True, None, True, None, None, {}, False))
            jar.save(ignore_discard=True, ignore_expires=True)
            row = next(line for line in path.read_text().splitlines() if line and not line.startswith("#"))
            self.assertEqual(row.split("\t")[4], "")


if __name__ == "__main__":
    unittest.main()
