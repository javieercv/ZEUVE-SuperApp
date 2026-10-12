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
    @staticmethod
    def embed_context(count=3):
        owner = {"id": "123", "username": "zeuve", "is_private": False}
        nodes = [{"id": str(1000+i), "__typename": "GraphImage", "is_video": False,
                  "display_url": f"https://cdn.example/{i}.jpg", "display_resources": [
                      {"src": f"https://cdn.example/small-{i}.jpg", "config_width": 150, "config_height": 150},
                      {"src": f"https://cdn.example/large-{i}.jpg", "config_width": 1080, "config_height": 1440}]} for i in range(count)]
        post = {"id": "900", "shortcode": "ABC123", "owner": owner, "__typename": "GraphSidecar",
                "taken_at_timestamp": 1700000000,
                "edge_sidecar_to_children": {"edges": [{"node": n} for n in nodes]}}
        return {"type": "Profile", "username": "zeuve", "owner_id": "123",
                "profile_link": "https://www.instagram.com/zeuve/", "posts_count": 999,
                "graphql_media": [{"shortcode_media": post}]}

    @staticmethod
    def embed_html(context):
        return '<script>doNotExecute();var data={"contextJSON":' + MODULE.json.dumps(MODULE.json.dumps({"context": context})) + '};</script>'

    def test_public_embed_checks_user_owner_canonical_and_privacy(self):
        import copy
        context = self.embed_context()
        self.assertEqual(MODULE.parse_public_profile_embed(self.embed_html(context), "ZEUVE", "123"), context)
        self.assertIsNone(MODULE.parse_public_profile_embed(self.embed_html(context), "other"))
        self.assertIsNone(MODULE.parse_public_profile_embed(self.embed_html(context), "zeuve", "999"))
        mutations = [lambda c: c.update(profile_link="https://instagram.com.evil.example/zeuve/"),
                     lambda c: c.update(profile_link="https://user@www.instagram.com/zeuve/"),
                     lambda c: c.update(profile_link="https://www.instagram.com/other/"),
                     lambda c: c.update(profile_link="https://[invalid"),
                     lambda c: c.update(is_private=True),
                     lambda c: c["graphql_media"][0]["shortcode_media"]["owner"].update(id="999"),
                     lambda c: c["graphql_media"][0]["shortcode_media"]["owner"].update(username="recommendation"),
                     lambda c: c["graphql_media"][0]["shortcode_media"]["owner"].update(is_private=True)]
        for mutation in mutations:
            invalid = copy.deepcopy(context); mutation(invalid)
            self.assertIsNone(MODULE.parse_public_profile_embed(self.embed_html(invalid), "zeuve"))
        self.assertIsNone(MODULE.parse_public_profile_embed('{"contextJSON":"invalid"}', "zeuve"))
        self.assertIsNone(MODULE.parse_public_profile_embed('<script>contextJSON=fetch("private")</script>', "zeuve"))

    def test_public_embed_keeps_original_carousel_indices_and_real_image_format(self):
        context = self.embed_context()
        edges = context["graphql_media"][0]["shortcode_media"]["edge_sidecar_to_children"]["edges"]
        edges.insert(1, {"node": {"id": "video", "__typename": "GraphVideo", "is_video": True,
                                 "display_url": "https://cdn.example/video-poster.jpg"}})
        records, videos = MODULE.public_embed_media(context, "zeuve")
        self.assertEqual(videos, 1)
        self.assertEqual([r["index"] for r in records], [1, 3, 4])
        self.assertEqual([r["id"] for r in records], ["1000", "1001", "1002"])
        self.assertTrue(all("large-" in r["media_url"] and r["extension"] == "jpg" for r in records))
        edges.extend([edges[0], {"node": None}, {"node": {"__typename": "GraphImage", "is_video": False,
            "id": "2000", "display_resources": None, "display_url": "http://cdn.example/unsafe.jpg"}}])
        edges[0]["node"]["display_resources"][1]["config_width"] = "malformed"
        records, _ = MODULE.public_embed_media(context, "zeuve")
        self.assertEqual(len(records), 3)
        self.assertIn("small-", records[0]["media_url"])
        edges.insert(1, None)
        records, _ = MODULE.public_embed_media(context, "zeuve")
        self.assertEqual([r["index"] for r in records], [1, 4, 5])

    def test_public_embed_network_refuses_sessions_and_redirected_identity(self):
        context = self.embed_context()
        html = self.embed_html(context)
        response = SimpleNamespace(status_code=200, url="https://www.instagram.com/zeuve/embed/", content=html.encode(), text=html)
        from unittest.mock import Mock
        get = Mock(return_value=response)
        loader = SimpleNamespace(context=SimpleNamespace(username=None, _session=SimpleNamespace(cookies=[], get=get)))
        self.assertEqual(MODULE.public_profile_embed(loader, "zeuve", 7, "123"), context)
        self.assertEqual(get.call_args.kwargs["timeout"], 7)
        loader.context._session.cookies = [SimpleNamespace(name="sessionid", value="SYNTHETIC_SESSION")]
        self.assertIsNone(MODULE.public_profile_embed(loader, "zeuve", 7)); self.assertEqual(get.call_count, 1)
        loader.context._session.cookies = []; loader.context.username = "viewer"
        self.assertIsNone(MODULE.public_profile_embed(loader, "zeuve", 7)); self.assertEqual(get.call_count, 1)
        loader.context.username = None; response.url = "https://www.instagram.com/other/embed/"
        self.assertIsNone(MODULE.public_profile_embed(loader, "zeuve", 7))
        response.url = "https://www.instagram.com/zeuve/embed/"; response.status_code = 429
        self.assertIsNone(MODULE.public_profile_embed(loader, "zeuve", 7))

    def test_public_header_embed_pagination_is_only_the_finite_sample(self):
        context = self.embed_context(34)
        pages = []
        args = SimpleNamespace(username="zeuve", offset=0, limit=24)
        for offset in [0, 24]:
            args.offset = offset; out = io.StringIO()
            with patch.object(MODULE, "public_profile_header", return_value={"og:image": "https://cdn.example/avatar.jpg", "description": "Biography"}), patch.object(MODULE, "public_profile_embed", return_value=context), patch("sys.stdout", out):
                self.assertTrue(MODULE.emit_public_header(None, args))
            pages.append([MODULE.json.loads(line) for line in out.getvalue().splitlines()])
        media = [[r for r in page if r["record"] == "media"] for page in pages]
        self.assertEqual([len(v) for v in media], [24, 11])
        self.assertEqual(len({r["id"] for v in media for r in v}), 35)
        for page in pages:
            self.assertEqual(page[-1]["known_total"], 35)
            self.assertFalse(next(r for r in page if r["record"] == "profile")["requires_authentication"])
        self.assertEqual(pages[0][-1]["next_cursor"], "24")
        self.assertIsNone(pages[1][-1]["next_cursor"])
        self.assertFalse(pages[1][-1]["has_more"])

    def test_anonymous_failed_feed_recovers_embed_without_another_feed_query(self):
        from unittest.mock import Mock
        profile = SimpleNamespace(username="zeuve", full_name="ZEUVE", biography="Biography", is_private=False,
            followed_by_viewer=False, profile_pic_url="https://cdn.example/avatar.jpg",
            profile_pic_url_no_iphone="https://cdn.example/avatar.jpg", mediacount=999, userid=123,
            get_posts=Mock(side_effect=LoginRequiredException("requires_login")), get_reels=Mock(return_value=[]))
        fake = SimpleNamespace(Instaloader=lambda **kwargs: SimpleNamespace(context=SimpleNamespace(username=None)),
            Profile=SimpleNamespace(from_username=lambda *args: profile))
        args = SimpleNamespace(username="zeuve", offset=0, limit=24, reels=True, stories=True, highlights=True,
            cookies=None, cookie_header_file=None, browser=None, browser_cookie_file=None)
        out = io.StringIO()
        with patch.dict(sys.modules, {"instaloader": fake}), patch.object(MODULE, "public_profile_embed", return_value=self.embed_context()) as embed, patch("sys.stdout", out):
            self.assertEqual(MODULE.catalog(args), 0)
            self.assertEqual(embed.call_args.args[-1], "123")
        profile.get_reels.assert_not_called()
        records = [MODULE.json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(len([r for r in records if r["record"] == "media"]), 4)
        self.assertEqual([r for r in records if r["record"] == "profile"][-1]["catalog_source"], "public_embed")
        self.assertFalse(any(r.get("code") == "section_requires_authentication" and r.get("section") == "posts" for r in records))
        profile.mediacount = 0; profile.get_posts.reset_mock(); out = io.StringIO()
        with patch.dict(sys.modules, {"instaloader": fake}), patch.object(MODULE, "public_profile_embed") as embed, patch("sys.stdout", out):
            self.assertEqual(MODULE.catalog(args), 0); embed.assert_not_called()
        profile.get_posts.assert_not_called()
        profile.mediacount = 999
        with patch.dict(sys.modules, {"instaloader": fake}), patch.object(MODULE, "public_profile_embed", return_value=None) as embed, patch("sys.stdout", io.StringIO()):
            self.assertEqual(MODULE.catalog(args), 0)
            self.assertEqual(embed.call_count, 1)

    def test_embed_resolves_reels_with_existing_anonymous_query_and_exact_identity(self):
        from unittest.mock import Mock
        import copy
        context = self.embed_context(1)
        post = {"id": "901", "shortcode": "REEL123", "__typename": "GraphVideo", "is_video": True,
                "owner": {"id": "123", "username": "zeuve", "is_private": False},
                "display_url": "https://cdn.example/poster.jpg", "taken_at_timestamp": 1700000000}
        context["graphql_media"].insert(0, {"shortcode_media": post})
        item = {"code": "REEL123", "pk": "901", "media_type": 2, "product_type": "clips",
                "user": {"pk": "123", "username": "zeuve", "is_private": False},
                "video_versions": [{"url": "https://cdn.example/small.mp4", "width": 360, "height": 640},
                                   {"url": "https://cdn.example/large.mp4", "width": 1080, "height": 1920}],
                "video_duration": 12.5}
        query = Mock(return_value={"data": {"xdt_api__v1__media__shortcode__web_info": {"items": [item]}}})
        ctx = SimpleNamespace(username=None, _session=SimpleNamespace(cookies=[]), request_timeout=20,
                              max_connection_attempts=2, doc_id_graphql_query=query)
        loader = SimpleNamespace(context=ctx)
        records, missing = MODULE.public_embed_media(context, "zeuve", loader)
        self.assertEqual(missing, 0); self.assertEqual([r["kind"] for r in records], ["reel", "photo"])
        self.assertEqual(records[0]["media_url"], "https://cdn.example/large.mp4")
        self.assertEqual(records[0]["duration"], 12.5); self.assertEqual(records[0]["id"], "901")
        self.assertFalse(records[0]["requires_authentication"])
        self.assertEqual(query.call_args.args[0], "27128499623469141")
        self.assertEqual(query.call_args.args[1]["shortcode"], "REEL123")
        self.assertEqual(ctx.request_timeout, 20); self.assertEqual(ctx.max_connection_attempts, 2)
        mutations = [lambda v: v.update(code="OTHER123"), lambda v: v.update(pk="902"),
                     lambda v: v["user"].update(pk="999"), lambda v: v["user"].update(username="other"),
                     lambda v: v["user"].update(is_private=True), lambda v: v.update(video_versions=[{"url": "http://cdn.example/unsafe.mp4"}])]
        for mutation in mutations:
            invalid = copy.deepcopy(item); mutation(invalid)
            query.return_value = {"data": {"xdt_api__v1__media__shortcode__web_info": {"items": [invalid]}}}
            records, missing = MODULE.public_embed_media(context, "zeuve", loader)
            self.assertEqual([r["kind"] for r in records], ["photo"]); self.assertEqual(missing, 1)
        query.reset_mock(); ctx._session.cookies = [SimpleNamespace(name="sessionid", value="SYNTHETIC_SESSION")]
        MODULE.public_embed_media(context, "zeuve", loader); query.assert_not_called()

    def test_embed_mixed_carousel_requires_child_identity_and_preserves_positions(self):
        from unittest.mock import Mock
        context = self.embed_context(3)
        post = context["graphql_media"][0]["shortcode_media"]
        post["edge_sidecar_to_children"]["edges"][1]["node"] = {
            "id": "1001", "__typename": "GraphVideo", "is_video": True, "display_url": "https://cdn.example/poster.jpg"}
        item = {"code": "ABC123", "pk": "900", "media_type": 8, "user": {"pk": "123", "username": "zeuve"},
                "carousel_media": [{"pk": "1000", "media_type": 1},
                    {"pk": "1001", "media_type": 2, "video_versions": [{"url": "https://cdn.example/child.mp4"}]},
                    {"pk": "1002", "media_type": 1}]}
        query = Mock(return_value={"data": {"xdt_api__v1__media__shortcode__web_info": {"items": [item]}}})
        loader = SimpleNamespace(context=SimpleNamespace(username=None, _session=SimpleNamespace(cookies=[]),
            request_timeout=20, max_connection_attempts=2, doc_id_graphql_query=query))
        records, missing = MODULE.public_embed_media(context, "zeuve", loader)
        self.assertEqual(missing, 0); self.assertEqual([r["kind"] for r in records], ["photo", "video", "photo"])
        self.assertEqual([r["index"] for r in records], [1, 2, 3]); self.assertEqual([r["id"] for r in records], ["1000", "1001", "1002"])
        item["carousel_media"][1]["pk"] = "unrelated"
        records, missing = MODULE.public_embed_media(context, "zeuve", loader)
        self.assertEqual(missing, 1); self.assertEqual([r["index"] for r in records], [1, 3])

    def test_embed_video_enrichment_stops_after_access_block_or_budget(self):
        from unittest.mock import Mock
        import copy
        context = self.embed_context(1)
        post = {"id": "901", "shortcode": "REEL123", "__typename": "GraphVideo", "is_video": True,
                "owner": {"id": "123", "username": "zeuve", "is_private": False}}
        context["graphql_media"].insert(0, {"shortcode_media": post})
        second = copy.deepcopy(post); second.update(id="902", shortcode="REEL456")
        context["graphql_media"].insert(1, {"shortcode_media": second})
        query = Mock(side_effect=RuntimeError("HTTP 429 SYNTHETIC_SECRET"))
        loader = SimpleNamespace(context=SimpleNamespace(username=None, _session=SimpleNamespace(cookies=[]),
            request_timeout=20, max_connection_attempts=2, doc_id_graphql_query=query))
        records, missing = MODULE.public_embed_media(context, "zeuve", loader)
        self.assertEqual(query.call_count, 1); self.assertEqual(missing, 2)
        self.assertEqual([r["kind"] for r in records], ["photo"])
        self.assertNotIn("SYNTHETIC_SECRET", str(records))
        query.reset_mock()
        with patch.object(MODULE.time, "monotonic", side_effect=[0, 51, 52, 53]):
            records, missing = MODULE.public_embed_media(context, "zeuve", loader)
        query.assert_not_called(); self.assertEqual(missing, 2)

    def test_embed_pagination_does_not_skip_photos_when_video_resolution_fails(self):
        from unittest.mock import Mock
        context = self.embed_context(5)
        post = {"id": "901", "shortcode": "REEL123", "__typename": "GraphVideo", "is_video": True,
                "owner": {"id": "123", "username": "zeuve", "is_private": False}}
        context["graphql_media"].insert(0, {"shortcode_media": post})
        query = Mock(side_effect=RuntimeError("HTTP 401"))
        loader = SimpleNamespace(context=SimpleNamespace(username=None, _session=SimpleNamespace(cookies=[]),
            request_timeout=20, max_connection_attempts=2, doc_id_graphql_query=query))
        pages = []
        for offset in [0, 3, 6]:
            out = io.StringIO(); args = SimpleNamespace(username="zeuve", offset=offset, limit=3, reels=True)
            with patch.object(MODULE, "public_profile_header", return_value={"og:image": "https://cdn.example/avatar.jpg"}), patch.object(MODULE, "public_profile_embed", return_value=context), patch("sys.stdout", out):
                self.assertTrue(MODULE.emit_public_header(loader, args))
            pages.append([MODULE.json.loads(line) for line in out.getvalue().splitlines()])
        self.assertEqual(query.call_count, 1)  # Later windows do not re-query an earlier Reel.
        ids = [r["id"] for page in pages for r in page if r["record"] == "media"]
        self.assertEqual(ids, ["profile-zeuve", "1000", "1001", "1002", "1003", "1004"])
        self.assertEqual([page[-1]["returned"] for page in pages], [2, 3, 1])
        self.assertTrue(all(page[-1]["known_total"] == 7 for page in pages))
        self.assertIsNone(pages[-1][-1]["next_cursor"])
        self.assertFalse(any("_sample_position" in r for page in pages for r in page))

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
