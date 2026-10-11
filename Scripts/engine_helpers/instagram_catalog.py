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
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlsplit

VERSION = "4.15.3-zeuve.5"


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


def set_instagram_cookie(context: Any, name: str, value: str, domain: str, path: str) -> None:
    host = domain.lstrip(".").lower()
    if host != "instagram.com" and not host.endswith(".instagram.com"):
        return
    # Instaloader inicia cookies anónimas sin dominio (sessionid/csrftoken vacías).
    # Requests enviaría ambas al añadir después las cookies de dominio del navegador.
    jar = context._session.cookies
    for cookie in list(jar):
        if cookie.name == name and not cookie.domain:
            jar.clear(cookie.domain, cookie.path, cookie.name)
    jar.set(name, value, domain=domain, path=path)
    if name == "csrftoken" and value:
        context._session.headers["X-CSRFToken"] = value


def load_netscape_cookies(context: Any, path: str) -> None:
    jar = http.cookiejar.MozillaCookieJar(path)
    jar.load(ignore_discard=True, ignore_expires=True)
    for cookie in jar:
        set_instagram_cookie(context, cookie.name, cookie.value, cookie.domain, cookie.path)


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
            set_instagram_cookie(context, name, value, ".instagram.com", "/")


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
        set_instagram_cookie(context, cookie.name, cookie.value, cookie.domain, cookie.path)


class SessionRequestBlocked(Exception):
    """La validación recibió 429: se termina sin reintentar otra consulta."""


def activate_session(loader: Any) -> str | None:
    username = loader.test_login()
    if any("429" in str(message) for message in getattr(loader.context, "error_log", [])):
        raise SessionRequestBlocked()
    if username:
        loader.context.username = username
    return username


def resolve_profile(loader: Any, username: str) -> Any:
    """Resolve a validated session through the library's existing GraphQL metadata route."""
    import instaloader  # type: ignore
    context = loader.context
    if not context.username:
        return instaloader.Profile.from_username(context, username)
    data = context.get_json("web/search/topsearch/", {
        "context": "blended", "query": username, "include_reel": False,
    })
    identifiers = set()
    for item in data.get("users", []):
        user = item.get("user", {})
        if str(user.get("username", "")).lower() != username.lower():
            continue
        identifier = str(user.get("pk") or user.get("id") or "")
        if identifier.isascii() and identifier.isdigit():
            identifiers.add(identifier)
    if len(identifiers) != 1:
        raise RuntimeError("No se ha podido verificar la identidad exacta del perfil.")
    identifier = identifiers.pop()
    profile = instaloader.Profile(context, {"id": identifier, "username": username})
    profile._obtain_metadata()
    if profile.username.lower() != username.lower() or str(profile.userid) != identifier:
        raise RuntimeError("La respuesta no corresponde al perfil solicitado.")
    return profile


def public_profile_header(loader: Any, username: str, timeout: int) -> dict[str, str] | None:
    """Read only the anonymous public page; never infer privacy or a complete catalogue."""
    if loader.context.username:
        return None
    response = loader.context._session.get(
        f"https://www.instagram.com/{username}/", timeout=timeout,
        headers={"User-Agent": "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15 ZEUVE/0.20.8",
                 "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1"},
    )
    if response.status_code != 200 or len(response.content) > 16 * 1024 * 1024:
        return None

    class MetadataParser(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=True)
            self.metadata: dict[str, str] = {}

        def handle_starttag(self, tag, attrs):
            if tag.lower() == "meta":
                attributes = dict(attrs)
                key = attributes.get("property") or attributes.get("name")
                if key and attributes.get("content"):
                    self.metadata[key.lower()] = attributes["content"]

    parser = MetadataParser()
    parser.feed(response.text)
    metadata = parser.metadata
    canonical = urlsplit(metadata.get("og:url", ""))
    avatar = urlsplit(metadata.get("og:image", ""))
    if (metadata.get("og:type") != "profile"
            or canonical.scheme != "https"
            or canonical.hostname not in ("instagram.com", "www.instagram.com")
            or canonical.path.strip("/").lower() != username.lower()
            or avatar.scheme != "https" or not avatar.hostname):
        return None
    return metadata


def emit_public_header(loader: Any, args: argparse.Namespace) -> bool:
    try:
        metadata = public_profile_header(loader, args.username, max(1, min(getattr(args, "request_timeout", 20), 300)))
    except Exception:
        return False
    if not metadata:
        return False
    avatar = metadata["og:image"]
    emit({"record": "profile", "username": args.username,
          "full_name": metadata.get("og:title", args.username),
          "biography": metadata.get("description"), "is_private": None,
          "requires_authentication": False, "session_supplied": False,
          "session_validated": False, "profile_picture_url": avatar})
    if args.offset == 0:
        emit({"record": "media", "section": "profile", "username": args.username,
              "id": f"profile-{args.username.lower()}", "index": 1,
              "kind": "profilePicture", "media_url": avatar,
              "extension": media_extension(avatar, "jpg"),
              "source_page": f"https://www.instagram.com/{args.username}/"})
    for section in ("posts", "reels"):
        emit({"record": "warning", "section": section, "code": "public_header_only"})
    for section in ("stories", "highlights"):
        emit({"record": "warning", "section": section, "code": "section_requires_authentication"})
    emit({"record": "page", "offset": args.offset, "returned": int(args.offset == 0),
          "has_more": False, "next_cursor": None})
    return True


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



def section_failure(error: Exception, section: str) -> dict[str, Any]:
    lower = f"{type(error).__name__} {error}".lower()
    if any(value in lower for value in ("403", "429", "timeout", "timed out", "connection", "checkpoint", "challenge_required")):
        code = "section_request_blocked"
        message = f"Instagram no ha permitido completar la consulta de {section}."
    elif any(value in lower for value in ("loginrequired", "login required", "authentication required")):
        code = "section_requires_authentication"
        message = f"La sección {section} requiere una sesión con acceso autorizado."
    else:
        code = "section_failed"
        message = f"No se ha podido completar la sección {section}."
    return {"record": "warning", "section": section, "code": code, "message": message}

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
        emit({"record": "error", "code": "engine_missing", "message": "El motor no ha podido completar esta fase."})
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
        fatal_status_codes=[429],
        request_timeout=max(1, min(getattr(args, "request_timeout", 20), 300)),
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


def highlight_items(highlight: Any, context: Any) -> Iterable[Any]:
    """Keep authorized GraphQL items if optional mobile quality metadata omits this reel."""
    try:
        yield from highlight.get_items()
    except KeyError as error:
        expected = f"highlight:{highlight.unique_id}"
        nodes = getattr(highlight, "_items", None)
        if error.args != (expected,) or not isinstance(nodes, list):
            raise
        import instaloader  # type: ignore
        previous = context.iphone_support
        try:
            context.iphone_support = False
            for node in nodes:
                owner = node.get("owner", {})
                if owner.get("id") is not None and str(owner["id"]) != str(highlight.owner_profile.userid):
                    raise RuntimeError("La destacada no corresponde al perfil solicitado.")
                yield instaloader.StoryItem(context, node, highlight.owner_profile)
        finally:
            context.iphone_support = previous


def catalog(args: argparse.Namespace) -> int:
    try:
        import instaloader
    except Exception as error:
        emit({"record": "error", "code": "engine_missing", "message": "El motor no ha podido completar esta fase."})
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
        fatal_status_codes=[429],
        request_timeout=max(1, min(getattr(args, "request_timeout", 20), 300)),
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
            fatal_status_codes=[429],
            request_timeout=max(1, min(getattr(args, "request_timeout", 20), 300)),
        )
        session_validated = False

    if session_supplied:
        try:
            session_username = activate_session(loader)
            session_validated = True if session_username else None
        except SessionRequestBlocked:
            emit({
                "record": "error",
                "code": "session_request_blocked",
                "message": "Instagram ha limitado temporalmente la validación de la sesión. Espera antes de volver a intentarlo; este rechazo no demuestra que la sesión sea inválida.",
                "requires_authentication": False,
                "session_supplied": True,
                "session_validated": None,
            })
            return 21
        except Exception:
            # A failed validation request must not discard the cookies before the
            # actual profile lookup; Instagram may allow one endpoint and reject another.
            session_validated = None

    try:
        profile = resolve_profile(loader, args.username)
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
                fatal_status_codes=[429],
                request_timeout=max(1, min(getattr(args, "request_timeout", 20), 300)),
            )
            try:
                profile = instaloader.Profile.from_username(anonymous_loader.context, args.username)
                loader = anonymous_loader
                session_username = None
                session_validated = False
                emit({
                    "record": "warning",
                    "section": "session",
                    "code": "session_ignored_for_public_lookup",
                    "message": "La consulta con sesión ha fallado; el perfil se ha consultado sin sesión.",
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
            if emit_public_header(loader, args):
                return 0
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

    def append_record(record: dict[str, Any]) -> None:
        record["requires_authentication"] = bool(profile.is_private or record.get("section") in ("stories", "highlights"))
        position = len(all_records)
        all_records.append(record)
        start = max(0, int(args.offset))
        if start <= position < start + max(1, int(args.limit)):
            emit(record)

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
    append_record(profile_picture)

    def add_posts(iterator_factory: Any, section: str) -> None:
        try:
            for post in iterator_factory():
                for record in post_records(post, section):
                    key = str(record["id"])
                    if key not in seen_ids:
                        seen_ids.add(key)
                        append_record(record)
                if len(all_records) >= args.offset + args.limit + 1:
                    break
        except Exception as error:
            emit(section_failure(error, section))

    # Un recuento confirmado de cero evita una consulta de feed innecesaria.
    if profile.mediacount > 0:
        add_posts(profile.get_posts, "posts")
    if args.reels and len(all_records) <= args.offset + args.limit:
        add_posts(profile.get_reels, "reels")

    if args.stories:
        if not session_validated:
            emit({
                "record": "warning",
                "section": "stories",
                "code": "section_requires_authentication",
                "message": "Stories no disponibles sin una sesión de Instagram.",
            })
        elif len(all_records) <= args.offset + args.limit:
            try:
                for story in loader.get_stories(userids=[profile.userid]):
                    for index, item in enumerate(story.get_items(), start=1):
                        append_record(story_record(item, "stories", index=index))
                        if len(all_records) > args.offset + args.limit:
                            break
                    if len(all_records) > args.offset + args.limit:
                        break
            except Exception as error:
                emit(section_failure(error, "stories"))

    if args.highlights:
        if not session_validated:
            emit({
                "record": "warning",
                "section": "highlights",
                "code": "section_requires_authentication",
                "message": "Destacadas no disponibles sin una sesión de Instagram.",
            })
        elif len(all_records) <= args.offset + args.limit:
            try:
                for highlight in loader.get_highlights(profile):
                    for index, item in enumerate(highlight_items(highlight, loader.context), start=1):
                        append_record(story_record(item, "highlights", highlight.title, index))
                        if len(all_records) > args.offset + args.limit:
                            break
                    if len(all_records) > args.offset + args.limit:
                        break
            except Exception as error:
                emit(section_failure(error, "highlights"))

    start = max(0, int(args.offset))
    end = start + max(1, int(args.limit))
    page = all_records[start:end]
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
        emit({"record": "error", "code": "browser_cookie_missing", "message": "El motor no ha podido completar esta fase."})
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
        host = cookie.domain.lstrip(".").lower()
        if host == "instagram.com" or host.endswith(".instagram.com"):
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
    cat.add_argument("--request-timeout", type=int, default=20)
    cat.add_argument("--cookies")
    cat.add_argument("--cookie-header-file")
    cat.add_argument("--browser")
    cat.add_argument("--browser-cookie-file")
    direct_post = sub.add_parser("direct")
    direct_post.add_argument("--shortcode", required=True)
    direct_post.add_argument("--source-url", required=True)
    direct_post.add_argument("--content-kind", choices=("post", "reel"), default="post")
    direct_post.add_argument("--request-timeout", type=int, default=20)
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
