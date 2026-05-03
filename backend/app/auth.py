"""Google Sign-In + our own JWT session tokens.

Flow:
1. Flutter calls `GoogleSignIn.signIn()`, gets a Google ID token.
2. Flutter POSTs that token to `/auth/google`.
3. We verify the token against Google's certs (audience = our Web Client ID),
   upsert the user by `sub`, mint our own JWT, return it.
4. Every other endpoint reads `Authorization: Bearer <jwt>`, decodes it,
   loads the user.

JWTs are HS256 signed with `JWT_SECRET`; we don't bother with refresh tokens
yet — the lifetime is 30 days, and re-auth via Google is one tap.
"""

from __future__ import annotations

import os
import secrets
import time
import uuid
from pathlib import Path
from typing import Annotated

import jwt
from fastapi import Depends, Header, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from . import db


JWT_ALGO = "HS256"
JWT_TTL_SECONDS = 60 * 60 * 24 * 30  # 30 days

# Public Google OAuth Web client ID — used both by Flutter (`serverClientId`
# on Android) and the backend (`audience`). It's not a secret — it's literally
# the `aud` claim of every ID token Google emits. Override via env if you fork.
DEFAULT_WEB_CLIENT_ID = (
    "566738030703-24f45u0l2b6ou8h4etgapqbcm6doo5na.apps.googleusercontent.com"
)
# Desktop installed-app client. Tokens minted by `googleapis_auth` on Windows
# carry `aud = Desktop Client ID`, so we have to accept it alongside the Web
# client. Like the Web ID, this is public.
DEFAULT_DESKTOP_CLIENT_ID = (
    "566738030703-gkifuci0i16bumgbsp6gb11k5elh8igi.apps.googleusercontent.com"
)
# Android client. `google_sign_in` doesn't expose this in the token by default
# (the `aud` is the Web Client ID via `serverClientId`), but if anyone
# reconfigures the package to omit `serverClientId`, tokens will carry the
# Android Client ID. Accepting it costs nothing and prevents another round of
# "wrong audience" errors.
DEFAULT_ANDROID_CLIENT_ID = (
    "566738030703-lmo4a5k7u2i5l0okkd6b6r50mgmlma30.apps.googleusercontent.com"
)


def _jwt_secret() -> str:
    """Return the JWT signing secret, generating + persisting one on first run.

    Resolution order:
    1. `JWT_SECRET` env var (preferred — set via Fly secrets in production).
    2. A 64-byte token persisted at `/data/jwt_secret` (auto-created so the
       app boots without manual env config; survives across deploys via the
       Fly volume).
    3. An in-memory fallback if /data isn't writable (dev/CI only — JWTs
       won't survive process restart).
    """
    env = os.getenv("JWT_SECRET")
    if env:
        return env
    secret_path = Path(os.getenv("JWT_SECRET_FILE", "/data/jwt_secret"))
    try:
        if secret_path.exists():
            value = secret_path.read_text().strip()
            if value:
                return value
        secret_path.parent.mkdir(parents=True, exist_ok=True)
        value = secrets.token_urlsafe(64)
        secret_path.write_text(value)
        try:
            secret_path.chmod(0o600)
        except OSError:
            pass
        return value
    except OSError:
        # Last resort — process-local secret. Re-issued on every restart.
        return secrets.token_urlsafe(64)


def _web_client_id() -> str:
    return os.getenv("GOOGLE_OAUTH_WEB_CLIENT_ID") or DEFAULT_WEB_CLIENT_ID


def _accepted_audiences() -> list[str]:
    """All Google OAuth client IDs whose ID tokens we accept.

    - Web Client ID: tokens minted via Android `google_sign_in` with
      `serverClientId=...`.
    - Desktop Client ID: tokens minted via `googleapis_auth` on
      Windows/macOS/Linux installed-app flow.

    Extra audiences can be appended via `GOOGLE_OAUTH_EXTRA_AUDIENCES`
    (comma-separated).
    """
    audiences = [_web_client_id()]
    desktop = os.getenv("GOOGLE_OAUTH_DESKTOP_CLIENT_ID") or DEFAULT_DESKTOP_CLIENT_ID
    if desktop and desktop not in audiences:
        audiences.append(desktop)
    android = os.getenv("GOOGLE_OAUTH_ANDROID_CLIENT_ID") or DEFAULT_ANDROID_CLIENT_ID
    if android and android not in audiences:
        audiences.append(android)
    extra = os.getenv("GOOGLE_OAUTH_EXTRA_AUDIENCES", "")
    for entry in extra.split(","):
        entry = entry.strip()
        if entry and entry not in audiences:
            audiences.append(entry)
    return audiences


JWT_SECRET = _jwt_secret()
GOOGLE_OAUTH_WEB_CLIENT_ID = _web_client_id()
GOOGLE_OAUTH_ACCEPTED_AUDIENCES = _accepted_audiences()


class AuthConfigError(RuntimeError):
    pass


def _ensure_config() -> None:
    if not JWT_SECRET:
        raise AuthConfigError("JWT_SECRET is not configured.")
    if not GOOGLE_OAUTH_WEB_CLIENT_ID:
        raise AuthConfigError("GOOGLE_OAUTH_WEB_CLIENT_ID is not configured.")


def verify_google_id_token(token: str) -> dict:
    """Verify a Google ID token and return its payload.

    Raises HTTPException(401) on any verification failure. We accept tokens
    issued for our Web Client ID *or* the Android Client ID — Flutter's
    google_sign_in returns one or the other depending on whether
    `serverClientId` is configured.
    """
    _ensure_config()
    try:
        # Verify signature + expiry, but skip the audience check inside
        # google-auth — we manually check against the full accepted list
        # below to give a friendlier error and to support multiple clients.
        payload = google_id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=None,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google ID token: {exc}",
        ) from exc
    aud = payload.get("aud")
    if aud not in GOOGLE_OAUTH_ACCEPTED_AUDIENCES:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                f"Invalid Google ID token: Token has wrong audience {aud}, "
                f"expected one of {GOOGLE_OAUTH_ACCEPTED_AUDIENCES}"
            ),
        )
    if payload.get("iss") not in {
        "accounts.google.com",
        "https://accounts.google.com",
    }:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token issuer is not Google.",
        )
    if not payload.get("sub"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has no subject.",
        )
    return payload


def issue_jwt(user_id: str) -> str:
    _ensure_config()
    now = int(time.time())
    return jwt.encode(
        {
            "sub": user_id,
            "iat": now,
            "exp": now + JWT_TTL_SECONDS,
        },
        JWT_SECRET,
        algorithm=JWT_ALGO,
    )


def decode_jwt(token: str) -> dict:
    _ensure_config()
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired.",
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
        ) from exc


async def upsert_user_from_google(payload: dict) -> dict:
    """Upsert a user row keyed by `google_sub`, return the resulting row."""
    google_sub = payload["sub"]
    email = payload.get("email", "")
    name = payload.get("name", "")
    picture = payload.get("picture", "")
    now_ms = int(time.time() * 1000)
    async with db.connect() as conn:
        cur = await conn.execute(
            "SELECT id FROM users WHERE google_sub = ?",
            (google_sub,),
        )
        row = await cur.fetchone()
        if row is None:
            user_id = str(uuid.uuid4())
            await conn.execute(
                """
                INSERT INTO users (id, google_sub, email, name, picture_url,
                                   created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (user_id, google_sub, email, name, picture, now_ms, now_ms),
            )
        else:
            user_id = row["id"]
            await conn.execute(
                """
                UPDATE users
                SET email = ?, name = ?, picture_url = ?, updated_at = ?
                WHERE id = ?
                """,
                (email, name, picture, now_ms, user_id),
            )
        await conn.commit()
        cur = await conn.execute(
            "SELECT id, email, name, picture_url FROM users WHERE id = ?",
            (user_id,),
        )
        return dict(await cur.fetchone())


_DEV_SKIP_AUTH = os.getenv("DEV_SKIP_AUTH", "true").lower() in ("1", "true", "yes")

_DEV_USER: dict = {
    "id": "dev-local-user-0000",
    "email": "dev@localhost",
    "name": "Dev User",
    "picture_url": None,
}


async def current_user(
    authorization: Annotated[str | None, Header()] = None,
) -> dict:
    """FastAPI dependency: 401 unless the request carries a valid Bearer JWT."""
    if _DEV_SKIP_AUTH and (
        not authorization or not authorization.lower().startswith("bearer ")
    ):
        return _DEV_USER
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer token.",
        )
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_jwt(token)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has no subject.",
        )
    async with db.connect() as conn:
        cur = await conn.execute(
            "SELECT id, email, name, picture_url FROM users WHERE id = ?",
            (user_id,),
        )
        row = await cur.fetchone()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists.",
        )
    return dict(row)


CurrentUser = Annotated[dict, Depends(current_user)]
