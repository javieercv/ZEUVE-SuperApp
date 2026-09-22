#!/usr/bin/env python3
"""ZEUVE Instagram catalog helper.

Emits one JSON object per line. It never downloads media and never writes session
information to stdout. The executable is bundled with Instaloader for macOS.
"""
from __future__ import annotations

import argparse
import http.cookiejar
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlsplit

VERSION = "4.15.3-zeuve.2"


def emit(value: dict[str, Any]) -> None:
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")), flush=True)


def iso(value: Any) -> str | None:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    return None


def media_extension(url: str, fallback: str) -> str:
    """Return the actual extension exposed by the CDN without guessing from media kind."""
    suffix = Path(urlsplit(url).path).suffix.lower().lstrip(".")
    supported = {"jpg", "jpeg", "png", "webp", "gif", "avif", "heic", "tiff", "mp4", "webm", "mov"}
    if suffix in supported:
        return "jpg" if suffix == "jpeg" else suffix
    return fallback


def load_netscape_cookies(context: Any, path: str) -> None:
    jar = http.cookiejar.MozillaCookieJar(path)
    jar.load(ignore_discard=True, ignore_expires=True)
    for cookie in jar:
        context._session.cookies.set(cookie.name, cookie.value, domain=cookie.domain, path=cookie.path)


def load_cookie_header(context: Any, path: str) -> None:
    raw = Path(path).read_text(encoding="utf-8").strip()
    if raw.lower().startswith("cookie:"):
        raw = raw.split(":", 1)[1].strip()
    for pair in raw.split(";"):
        if "=" not in pair:
            continue
        name, value = pair.split("=", 1)
        name, value = name.strip(), value.strip()
        if name:
            context._session.cookies.set(name, value, domain=".instagram.com", path="/")


def import_browser_cookies(context: Any, browser: str, cookiefile: str | None) -> None:
    try:
        import browser_cookie3  # type: ignore
    except Exception as error:  # pragma: no cover - packaged optional dependency
        raise RuntimeError("El motor no incluye la importación de cookies del navegador.") from error
    mapping = {
        "chrome": browser_cookie3.chrome,
        "chromium": browser_cookie3.chromium,
        "brave": browser_cookie3.brave,
        "edge": browser_cookie3.edge,
        "firefox": browser_cookie3.firefox,
        "opera": browser_cookie3.opera,
        "safari": browser_cookie3.safari,
        "vivaldi": browser_cookie3.vivaldi,
        "arc": getattr(browser_cookie3, "arc", None),
    }
    loader = mapping.get(browser.lower())
    if loader is None:
        raise RuntimeError(f"Navegador no compatible: {browser}")
    kwargs: dict[str, Any] = {"domain_name": ".instagram.com"}
    if cookiefile:
        kwargs["cookie_file"] = cookiefile
    jar = loader(**kwargs)
    for cookie in jar:
        context._session.cookies.set(cookie.name, cookie.value, domain=cookie.domain, path=cookie.path)


def activate_session(loader: Any) -> str | None:
    username = loader.test_login()
    if username:
        loader.context.username = username
    return username


def classify_profile_lookup_error(
    error: Exception,
    *,
    session_supplied: bool,
    session_validated: bool | None,
) -> dict[str, Any]:
    """Classify an Instagram profile lookup without claiming that a profile is absent.

    Instagram may return an empty search result, an authentication challenge or a
    throttled response for an existing profile. Instaloader historically maps some
    of those responses to ProfileNotExistsException, so ZEUVE treats that result as
    inconclusive unless another engine resolves the profile.
    """
    class_name = type(error).__name__
    raw_message = str(error).strip()
    lower = f"{class_name} {raw_message}".lower()

    if session_supplied and session_validated is not True:
        code = "session_not_validated"
        message = (
            "La sesión aportada no se ha podido validar y la consulta pública tampoco ha podido completarse. "
            "El perfil no se considera privado ni se exige una sesión para volver a intentarlo."
        )
    elif any(token in lower for token in (
        "loginrequired", "login required", "you need to log in",
        "authentication required", "checkpoint", "challenge_required",
    )):
        code = "public_lookup_blocked"
        message = (
            "Instagram ha bloqueado la consulta pública del perfil en este momento. "
            "ZEUVE probará otros métodos públicos y no considerará obligatoria una sesión."
        )
    elif any(token in lower for token in (
        "profilenotexistsexception", "profile ", "does not exist",
        "not found", "graphql query returned none",
    )):
        code = "profile_lookup_ambiguous"
        message = (
            "Instagram no ha permitido comprobar si el perfil existe. "
            "El resultado puede deberse a una sesión necesaria, una respuesta bloqueada "
            "o una limitación temporal; no se considera una confirmación de que el perfil no exista."
        )
    elif any(token in lower for token in (
        "401", "403", "429", "too many requests", "rate limit",
        "blocked", "forbidden", "unauthorized",
    )):
        code = "request_blocked"
        message = (
            "Instagram ha rechazado o limitado temporalmente la consulta pública. "
            "Vuelve a intentarlo más adelante; una sesión no se considera obligatoria para este perfil."
        )
    else:
        code = "profile_lookup_failed"
        message = "Instagram no ha devuelto información suficiente para comprobar el perfil."

    return {
        "record": "error",
        "code": code,
        "message": message,
        "requires_authentication": False,
        "session_supplied": session_supplied,
        "session_validated": session_validated,
        "technical_error_type": class_name,
    }


def post_records(post: Any, section: str, source_page: str | None = None) -> Iterable[dict[str, Any]]:
    base = {
        "record": "media",
        "section": section,
        "username": post.owner_username,
        "post_id": str(post.mediaid),
        "shortcode": post.shortcode,
        "date": iso(post.date_utc),
        "caption": post.caption or "",
        "alt_text": getattr(post, "accessibility_caption", None) or "",
        "source_page": source_page or f"https://www.instagram.com/p/{post.shortcode}/",
    }
    if post.typename == "GraphSidecar":
        for index, node in enumerate(post.get_sidecar_nodes(), start=1):
            is_video = bool(node.is_video)
            media_url = str(node.video_url if is_video else node.display_url)
            yield {
                **base,
                "id": f"{post.mediaid}-{index}",
                "index": index,
                "kind": "reel" if section == "reels" else ("video" if is_video else "photo"),
                "media_url": media_url,
                "thumbnail_url": str(node.display_url),
                "extension": media_extension(media_url, "mp4" if is_video else "jpg"),
            }
    else:
        is_video = bool(post.is_video)
        media_url = str(post.video_url if is_video else post.url)
        yield {
            **base,
            "id": str(post.mediaid),
            "index": 1,
            "kind": "reel" if section == "reels" else ("video" if is_video else "photo"),
            "media_url": media_url,
            "thumbnail_url": str(post.url),
            "extension": media_extension(media_url, "mp4" if is_video else "jpg"),
        }


def classify_direct_lookup_error(error: Exception) -> dict[str, Any]:
    class_name = type(error).__name__
    raw_message = str(error).strip()
    lower = f"{class_name} {raw_message}".lower()
    private_tokens = (
        "privateprofilenotfollowed", "private profile", "private account",
        "this account is private", "private post", "cuenta privada", "perfil privado",
    )
    if any(token in lower for token in private_tokens):
        return {
            "record": "error",
            "code": "private_content",
            "message": "Instagram ha indicado que la publicación pertenece a una cuenta privada.",
            "requires_authentication": True,
            "technical_error_type": class_name,
        }
    if any(token in lower for token in (
        "loginrequired", "login required", "you need to log in", "checkpoint",
        "challenge_required", "401", "403", "429", "too many requests",
        "rate limit", "blocked", "forbidden", "unauthorized",
    )):
        return {
            "record": "error",
            "code": "public_direct_lookup_blocked",
            "message": (
                "Instagram ha rechazado o limitado temporalmente la resolución pública de la publicación. "
                "ZEUVE probará los otros motores públicos antes de solicitar una sesión."
            ),
            "requires_authentication": False,
            "technical_error_type": class_name,
        }
    return {
        "record": "error",
        "code": "direct_lookup_failed",
        "message": "El motor específico de Instagram no ha podido resolver esta publicación.",
        "requires_authentication": False,
        "technical_error_type": class_name,
    }


def direct(args: argparse.Namespace) -> int:
    try:
        import instaloader
    except Exception as error:
        emit({"record": "error", "code": "engine_missing", "message": str(error)})
        return 20

    loader = instaloader.Instaloader(
        download_pictures=False,
        download_videos=False,
        download_video_thumbnails=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=False,
        compress_json=False,
        quiet=True,
        max_connection_attempts=2,
    )
    session_supplied = bool(args.cookies or args.cookie_header_file)
    try:
        if args.cookies:
            load_netscape_cookies(loader.context, args.cookies)
        if args.cookie_header_file:
            load_cookie_header(loader.context, args.cookie_header_file)
    except Exception as error:
        emit({
            "record": "error",
            "code": "session_load_failed",
            "message": "No se ha podido leer la sesión aportada.",
            "requires_authentication": False,
            "session_supplied": session_supplied,
            "technical_error_type": type(error).__name__,
        })
        return 23

    try:
        post = instaloader.Post.from_shortcode(loader.context, args.shortcode)
    except Exception as error:
        value = classify_direct_lookup_error(error)
        value["session_supplied"] = session_supplied
        emit(value)
        return 3 if value["requires_authentication"] else 22

    section = "reels" if args.content_kind == "reel" else "posts"
    records = list(post_records(post, section, source_page=args.source_url))
    emit({
        "record": "post",
        "username": post.owner_username,
        "post_id": str(post.mediaid),
        "shortcode": post.shortcode,
        "typename": post.typename,
        "is_video": bool(post.is_video),
        "media_count": len(records),
        "session_supplied": session_supplied,
    })
    for record in records:
        emit(record)
    emit({
        "record": "page",
        "offset": 0,
        "next_cursor": None,
        "has_more": False,
        "returned": len(records),
        "known_total": len(records),
    })
    return 0


def story_record(item: Any, section: str, highlight_title: str | None = None, index: int = 1) -> dict[str, Any]:
    is_video = bool(item.is_video)
    return {
        "record": "media",
        "section": section,
        "username": item.owner_username,
        "id": str(item.mediaid),
        "shortcode": item.shortcode,
        "index": index,
        "date": iso(item.date_utc),
        "expires_at": iso(getattr(item, "expiring_utc", None)),
        "caption": getattr(item, "caption", None) or "",
        "kind": ("highlightVideo" if is_video else "highlightPhoto") if section == "highlights" else ("storyVideo" if is_video else "storyPhoto"),
        "media_url": str(item.video_url if is_video else item.url),
        "thumbnail_url": str(item.url),
        "extension": media_extension(str(item.video_url if is_video else item.url), "mp4" if is_video else "jpg"),
        "highlight_title": highlight_title,
        "source_page": f"https://www.instagram.com/stories/{item.owner_username}/{item.mediaid}/",
    }


def catalog(args: argparse.Namespace) -> int:
    try:
        import instaloader
    except Exception as error:
        emit({"record": "error", "code": "engine_missing", "message": str(error)})
        return 20

    loader = instaloader.Instaloader(
        download_pictures=False,
        download_videos=False,
        download_video_thumbnails=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=False,
        compress_json=False,
        quiet=True,
        max_connection_attempts=2,
    )
    session_supplied = bool(args.cookies or args.cookie_header_file or args.browser)
    session_username: str | None = None
    session_validated: bool | None = None
    try:
        if args.cookies:
            load_netscape_cookies(loader.context, args.cookies)
        if args.cookie_header_file:
            load_cookie_header(loader.context, args.cookie_header_file)
        if args.browser:
            import_browser_cookies(loader.context, args.browser, args.browser_cookie_file)
    except Exception as error:
        emit({
            "record": "warning",
            "section": "session",
            "code": "session_load_failed",
            "message": "No se ha podido leer la sesión aportada. Se continuará con el acceso público.",
            "session_supplied": session_supplied,
            "session_validated": False,
            "technical_error_type": type(error).__name__,
        })
        loader = instaloader.Instaloader(
            download_pictures=False,
            download_videos=False,
            download_video_thumbnails=False,
            download_geotags=False,
            download_comments=False,
            save_metadata=False,
            compress_json=False,
            quiet=True,
            max_connection_attempts=2,
        )
        session_validated = False

    if session_supplied:
        try:
            session_username = activate_session(loader)
            session_validated = bool(session_username)
        except Exception:
            # A failed validation request must not discard the cookies before the
            # actual profile lookup; Instagram may allow one endpoint and reject another.
            session_validated = False

    try:
        profile = instaloader.Profile.from_username(loader.context, args.username)
    except Exception as error:
        if session_supplied:
            anonymous_loader = instaloader.Instaloader(
                download_pictures=False,
                download_videos=False,
                download_video_thumbnails=False,
                download_geotags=False,
                download_comments=False,
                save_metadata=False,
                compress_json=False,
                quiet=True,
                max_connection_attempts=2,
            )
            try:
                profile = instaloader.Profile.from_username(anonymous_loader.context, args.username)
                loader = anonymous_loader
                emit({
                    "record": "warning",
                    "section": "session",
                    "code": "session_ignored_for_public_lookup",
                    "message": "La sesión aportada no se ha validado, pero el perfil público se ha consultado sin ella.",
                    "session_supplied": True,
                    "session_validated": False,
                })
            except Exception as anonymous_error:
                emit(classify_profile_lookup_error(
                    anonymous_error,
                    session_supplied=session_supplied,
                    session_validated=session_validated,
                ))
                return 21
        else:
            emit(classify_profile_lookup_error(
                error,
                session_supplied=session_supplied,
                session_validated=session_validated,
            ))
            return 21

    can_access_private = not profile.is_private or bool(profile.followed_by_viewer) or session_username == profile.username
    emit({
        "record": "profile",
        "username": profile.username,
        "full_name": profile.full_name,
        "biography": profile.biography,
        "is_private": bool(profile.is_private),
        "requires_authentication": bool(profile.is_private and not can_access_private),
        "session_supplied": session_supplied,
        "session_validated": session_validated,
        "profile_picture_url": str(profile.profile_pic_url),
        "profile_picture_low_url": str(profile.profile_pic_url_no_iphone),
        "media_count": int(profile.mediacount),
        "has_public_story": bool(profile.has_public_story) if session_validated else None,
        "cursor": str(args.offset),
    })
    if profile.is_private and not can_access_private:
        return 3

    all_records: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    def add_posts(iterator: Iterable[Any], section: str) -> None:
        try:
            for post in iterator:
                for record in post_records(post, section):
                    key = str(record["id"])
                    if key not in seen_ids:
                        seen_ids.add(key)
                        all_records.append(record)
                if len(all_records) >= args.offset + args.limit + 50:
                    break
        except Exception as error:
            emit({"record": "warning", "section": section, "message": str(error)})

    add_posts(profile.get_posts(), "posts")
    if args.reels:
        add_posts(profile.get_reels(), "reels")

    if args.stories:
        if not session_validated:
            emit({
                "record": "warning",
                "section": "stories",
                "code": "section_requires_authentication",
                "message": "Stories no disponibles sin una sesión de Instagram.",
            })
        else:
            try:
                for story in loader.get_stories(userids=[profile.userid]):
                    for index, item in enumerate(story.get_items(), start=1):
                        all_records.append(story_record(item, "stories", index=index))
            except Exception as error:
                emit({
                    "record": "warning",
                    "section": "stories",
                    "code": "section_requires_authentication",
                    "message": "Stories no disponibles con la sesión actual.",
                    "technical_error_type": type(error).__name__,
                })

    if args.highlights:
        if not session_validated:
            emit({
                "record": "warning",
                "section": "highlights",
                "code": "section_requires_authentication",
                "message": "Destacadas no disponibles sin una sesión de Instagram.",
            })
        else:
            try:
                for highlight in loader.get_highlights(profile):
                    for index, item in enumerate(highlight.get_items(), start=1):
                        all_records.append(story_record(item, "highlights", highlight.title, index))
            except Exception as error:
                emit({
                    "record": "warning",
                    "section": "highlights",
                    "code": "section_requires_authentication",
                    "message": "Destacadas no disponibles con la sesión actual.",
                    "technical_error_type": type(error).__name__,
                })

    # The current profile picture is always available as an independently selectable item.
    profile_picture = {
        "record": "media",
        "section": "profile",
        "username": profile.username,
        "id": f"profile-{profile.userid}",
        "index": 1,
        "date": None,
        "kind": "profilePicture",
        "media_url": str(profile.profile_pic_url),
        "thumbnail_url": str(profile.profile_pic_url),
        "extension": media_extension(str(profile.profile_pic_url), "jpg"),
        "source_page": f"https://www.instagram.com/{profile.username}/",
    }
    all_records.insert(0, profile_picture)

    start = max(0, int(args.offset))
    end = start + max(1, int(args.limit))
    page = all_records[start:end]
    for record in page:
        emit(record)
    emit({
        "record": "page",
        "offset": start,
        "next_cursor": str(end) if end < len(all_records) else None,
        "has_more": end < len(all_records),
        "returned": len(page),
        "known_total": len(all_records),
    })
    return 0


def export_cookies(args: argparse.Namespace) -> int:
    try:
        import browser_cookie3  # type: ignore
    except Exception as error:
        emit({"record": "error", "code": "browser_cookie_missing", "message": str(error)})
        return 30
    # Use MozillaCookieJar so the result is directly accepted by all ZEUVE engines.
    jar = http.cookiejar.MozillaCookieJar(args.output)
    mapping = {
        "chrome": browser_cookie3.chrome,
        "chromium": browser_cookie3.chromium,
        "brave": browser_cookie3.brave,
        "edge": browser_cookie3.edge,
        "firefox": browser_cookie3.firefox,
        "opera": browser_cookie3.opera,
        "safari": browser_cookie3.safari,
        "vivaldi": browser_cookie3.vivaldi,
        "arc": getattr(browser_cookie3, "arc", None),
    }
    loader = mapping.get(args.browser.lower())
    if loader is None:
        emit({"record": "error", "code": "unsupported_browser", "message": args.browser})
        return 31
    kwargs: dict[str, Any] = {"domain_name": ".instagram.com"}
    if args.browser_cookie_file:
        kwargs["cookie_file"] = args.browser_cookie_file
    source = loader(**kwargs)
    for cookie in source:
        jar.set_cookie(cookie)
    jar.save(ignore_discard=True, ignore_expires=True)
    emit({"record": "cookie_export", "count": len(jar), "output": Path(args.output).name})
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="instaloader-zeuve")
    root.add_argument("--version", action="store_true")
    sub = root.add_subparsers(dest="command")
    cat = sub.add_parser("catalog")
    cat.add_argument("--username", required=True)
    cat.add_argument("--limit", type=int, default=24)
    cat.add_argument("--offset", type=int, default=0)
    cat.add_argument("--cursor")
    cat.add_argument("--stories", action="store_true")
    cat.add_argument("--highlights", action="store_true")
    cat.add_argument("--reels", action="store_true")
    cat.add_argument("--profile-picture", action="store_true")
    cat.add_argument("--cookies")
    cat.add_argument("--cookie-header-file")
    cat.add_argument("--browser")
    cat.add_argument("--browser-cookie-file")
    direct_post = sub.add_parser("direct")
    direct_post.add_argument("--shortcode", required=True)
    direct_post.add_argument("--source-url", required=True)
    direct_post.add_argument("--content-kind", choices=("post", "reel"), default="post")
    direct_post.add_argument("--cookies")
    direct_post.add_argument("--cookie-header-file")
    exp = sub.add_parser("export-cookies")
    exp.add_argument("--browser", required=True)
    exp.add_argument("--browser-cookie-file")
    exp.add_argument("--output", required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    if args.version:
        print(VERSION)
        return 0
    if args.command == "catalog":
        if args.cursor and not args.offset:
            try:
                args.offset = int(args.cursor)
            except ValueError:
                args.offset = 0
        return catalog(args)
    if args.command == "direct":
        return direct(args)
    if args.command == "export-cookies":
        return export_cookies(args)
    parser().print_help(sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
