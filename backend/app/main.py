"""Noetica backend — auth, cloud sync, and roadmap generation.

OpenAI-compatible LLM gateway (OpenRouter by default) sits behind
`/roadmap/generate`. We never log prompts or LLM responses — only status,
model, and counts.
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from . import db
from .auth import (
    AuthConfigError,
    CurrentUser,
    issue_jwt,
    upsert_user_from_google,
    verify_google_id_token,
)
from .llm import LlmClient, LlmConfigError, LlmUpstreamError
from .schemas import (
    AxesRequest,
    AxesResponse,
    RoadmapRequest,
    RoadmapResponse,
)
from .sync import router as sync_router

load_dotenv()

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)
logger = logging.getLogger("noetica.backend")


@asynccontextmanager
async def _lifespan(app: FastAPI):
    db.configure(os.getenv("NOETICA_DB_PATH", db.DEFAULT_DB_PATH))
    await db.init()
    logger.info("DB initialised at %s", db._db_path)  # noqa: SLF001
    yield


app = FastAPI(
    title="Noetica Backend",
    version="0.2.0",
    description="Auth + cloud sync + LLM roadmap generation.",
    lifespan=_lifespan,
)

_cors_origins = [
    o.strip()
    for o in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:8080",
    ).split(",")
    if o.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins if _cors_origins else ["http://localhost:8080"],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


# ---------- /healthz, /auth ----------


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/healthz/llm")
async def healthz_llm() -> dict[str, object]:
    """Diagnostic — reports whether the LLM client can initialise.

    Intentionally does NOT return the API key itself, just whether a
    backend is selected and what model/provider is in use.
    """
    from .llm import LlmClient, LlmConfigError
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        return {"ok": False, "error": str(exc)}
    provider = "groq"
    if "groq" in (client.base_url or ""):
        provider = "groq"
    elif "generativelanguage" in (client.base_url or ""):
        provider = "gemini"
    elif "openai.com" in (client.base_url or ""):
        provider = "openai"
    return {
        "ok": True,
        "provider": provider,
        "model": client.model,
        "base_url": client.base_url,
    }


class GoogleAuthRequest(BaseModel):
    id_token: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    user: dict


@app.post("/auth/google", response_model=AuthResponse)
async def auth_google(req: GoogleAuthRequest) -> AuthResponse:
    try:
        payload = verify_google_id_token(req.id_token)
    except AuthConfigError as exc:
        logger.error("Auth config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    user = await upsert_user_from_google(payload)
    token = issue_jwt(user["id"])
    logger.info("auth_google ok user=%s", user["id"][:8])
    return AuthResponse(access_token=token, user=user)


@app.get("/auth/me", response_model=dict)
async def auth_me(user: CurrentUser) -> dict:
    return user


# ---------- /sync ----------

app.include_router(sync_router)


# ---------- /roadmap, /onboarding (now require auth) ----------


@app.post("/roadmap/generate", response_model=RoadmapResponse)
async def generate_roadmap(
    request: RoadmapRequest,
    user: CurrentUser,
) -> RoadmapResponse:
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        tasks, summary = await client.generate_roadmap(
            goal=request.goal,
            profile=request.profile,
            axes=request.axes,
            horizon_days=request.horizon_days,
            task_count=request.task_count,
            knowledge=request.knowledge,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    if not tasks:
        raise HTTPException(
            status_code=502,
            detail="LLM returned no usable tasks.",
        )

    logger.info(
        "Generated roadmap: user=%s model=%s tasks=%d axes=%d",
        user["id"][:8],
        client.model,
        len(tasks),
        len(request.axes),
    )
    return RoadmapResponse(
        model=client.model,
        tasks=tasks,
        summary=summary,
    )


@app.post("/onboarding/axes", response_model=AxesResponse)
async def generate_axes(
    request: AxesRequest,
    user: CurrentUser,
) -> AxesResponse:
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        axes = await client.generate_axes(
            profile=request.profile,
            interests=request.interests,
            count=request.count,
            knowledge=request.knowledge,
            regen_hint=request.regen_hint,
            variation_seed=request.variation_seed,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    if len(axes) < 3:
        raise HTTPException(
            status_code=502,
            detail="LLM returned fewer than 3 usable axes.",
        )

    logger.info(
        "Generated axes: user=%s model=%s axes=%d interests=%d",
        user["id"][:8],
        client.model,
        len(axes),
        len(request.interests),
    )
    return AxesResponse(model=client.model, axes=axes)


_ = Depends  # silence unused import warning when no other Depends is used here
