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
    CoachRequest,
    CoachResponse,
    GeneratorRunRequest,
    GeneratorRunResponse,
    HabitsPlan,
    HabitsRequest,
    MenuPlan,
    MenuRecipeRequest,
    MenuRecipeResponse,
    MenuRequest,
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


# ---------- /tools/menu (Ассистент → Меню недели) ----------


@app.post("/tools/menu/generate", response_model=MenuPlan)
async def tools_menu_generate(
    request: MenuRequest,
    user: CurrentUser,
) -> MenuPlan:
    """Stage-1 — return a 7-day menu structure (no recipe steps).

    The client renders this into a preview table. Recipes are pulled
    on-demand via `/tools/menu/recipe` only for meals the user opens.
    """
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        plan = await client.generate_menu_plan(
            goal=request.goal,
            servings=request.servings,
            restrictions=request.restrictions,
            extra_notes=request.extra_notes,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM menu upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    if not plan.days:
        raise HTTPException(
            status_code=502, detail="LLM returned no days for the menu.",
        )

    logger.info(
        "Generated menu: user=%s model=%s days=%d goal=%s servings=%d",
        user["id"][:8],
        plan.model,
        len(plan.days),
        request.goal,
        request.servings,
    )
    return plan


@app.post("/coach/generate", response_model=CoachResponse)
async def generate_coach(
    request: CoachRequest,
    user: CurrentUser,
) -> CoachResponse:
    """AI Coach — morning plan or evening reflection."""
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        result = await client.generate_coach(
            mode=request.mode,
            name=request.name,
            aspiration=request.aspiration,
            axes=request.axes,
            active_tasks=request.active_tasks,
            completed_today=request.completed_today,
            remaining=request.remaining,
            entries_today=request.entries_today,
            streak=request.streak,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM coach upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    mode = request.mode
    if mode == "morning":
        resp = CoachResponse(
            model=result.get("model", ""),
            mode=mode,
            morning={
                "greeting": result.get("greeting", ""),
                "focus": result.get("focus", ""),
                "tasks": result.get("tasks", []),
                "motivation": result.get("motivation", ""),
            },
        )
    else:
        resp = CoachResponse(
            model=result.get("model", ""),
            mode=mode,
            evening={
                "summary": result.get("summary", ""),
                "wins": result.get("wins", []),
                "improvements": result.get("improvements", []),
                "encouragement": result.get("encouragement", ""),
            },
        )

    logger.info(
        "Coach generated: user=%s mode=%s model=%s",
        user["id"][:8],
        mode,
        resp.model,
    )
    return resp


@app.post("/tools/menu/recipe", response_model=MenuRecipeResponse)
async def tools_menu_recipe(
    request: MenuRecipeRequest,
    user: CurrentUser,
) -> MenuRecipeResponse:
    """Stage-2 — return a single full recipe rendered as markdown."""
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        markdown = await client.generate_meal_recipe(
            meal_name=request.meal_name,
            ingredients=[i.model_dump() for i in request.ingredients],
            goal=request.goal,
            servings=request.servings,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM recipe upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    logger.info(
        "Generated recipe: user=%s model=%s meal=%r ings=%d",
        user["id"][:8],
        client.model,
        request.meal_name[:40],
        len(request.ingredients),
    )
    return MenuRecipeResponse(model=client.model, markdown=markdown)


@app.post("/tools/habits/generate", response_model=HabitsPlan)
async def tools_habits_generate(
    request: HabitsRequest,
    user: CurrentUser,
) -> HabitsPlan:
    """Generate an N-day micro-habit plan from a free-form intent.

    Returns one tiny daily action per requested day. The client
    imports them as N due-dated tasks tagged with `challenge/<id>`.
    """
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        plan = await client.generate_habits_plan(
            intent=request.intent,
            duration_days=request.duration_days,
            axis_hint=request.axis_hint,
            notes=request.notes,
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM habits upstream error: status=%s", exc.status)
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    if len(plan.days) < request.duration_days:
        raise HTTPException(
            status_code=502,
            detail=(
                f"LLM returned {len(plan.days)} days but {request.duration_days} "
                "were requested."
            ),
        )

    logger.info(
        "Generated habits: user=%s model=%s days=%d",
        user["id"][:8],
        plan.model,
        len(plan.days),
    )
    return plan


@app.post("/tools/run", response_model=GeneratorRunResponse)
async def tools_run(
    request: GeneratorRunRequest,
    user: CurrentUser,
) -> GeneratorRunResponse:
    """Universal manifest runtime.

    Accepts a manifest's prompt template + form values, returns a
    generic `{summary, items[]}` shape that the client knows how to
    import. This is the endpoint user-authored tools (PR #33+) talk
    to — builtins gradually migrate to it as well so we don't have
    to maintain N specialised endpoints.

    We log only the manifest_id and shape stats — NEVER prompts,
    inputs or outputs (they are user content).
    """
    try:
        client = LlmClient()
    except LlmConfigError as exc:
        logger.error("LLM config error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        result = await client.run_generator(request)
    except ValueError as exc:
        # render_template raised on an unknown placeholder — surface
        # to the author as 422 with a precise message.
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except LlmUpstreamError as exc:
        logger.warning(
            "LLM run upstream error: manifest=%s status=%s",
            request.manifest_id, exc.status,
        )
        raise HTTPException(
            status_code=502, detail="LLM upstream error.",
        ) from exc

    logger.info(
        "Generated run: user=%s manifest=%s model=%s items=%d",
        user["id"][:8],
        request.manifest_id,
        result.model,
        len(result.items),
    )
    return result


_ = Depends  # silence unused import warning when no other Depends is used here
