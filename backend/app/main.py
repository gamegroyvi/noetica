"""Noetica backend — roadmap generation endpoint.

OpenAI-compatible gateway (OpenRouter by default) sits behind `/roadmap/generate`.
We never log prompts or LLM responses — only status + model + task count.
"""

from __future__ import annotations

import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .llm import LlmClient, LlmConfigError, LlmUpstreamError
from .schemas import (
    AxesRequest,
    AxesResponse,
    RoadmapRequest,
    RoadmapResponse,
)

load_dotenv()

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)
logger = logging.getLogger("noetica.backend")

app = FastAPI(
    title="Noetica Backend",
    version="0.1.0",
    description="Roadmap generation powered by an OpenAI-compatible LLM gateway.",
)

_cors_origins = [
    o.strip()
    for o in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:8080,https://web-habzzjsv.devinapps.com",
    ).split(",")
    if o.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins if _cors_origins else ["*"],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/roadmap/generate", response_model=RoadmapResponse)
async def generate_roadmap(request: RoadmapRequest) -> RoadmapResponse:
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
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM upstream error: %s", exc)
        raise HTTPException(
            status_code=502, detail=f"LLM upstream error: {exc}"
        ) from exc

    if not tasks:
        raise HTTPException(
            status_code=502,
            detail="LLM returned no usable tasks.",
        )

    logger.info(
        "Generated roadmap: model=%s tasks=%d axes=%d",
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
async def generate_axes(request: AxesRequest) -> AxesResponse:
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
        )
    except LlmUpstreamError as exc:
        logger.warning("LLM upstream error: %s", exc)
        raise HTTPException(
            status_code=502, detail=f"LLM upstream error: {exc}"
        ) from exc

    if len(axes) < 3:
        raise HTTPException(
            status_code=502,
            detail="LLM returned fewer than 3 usable axes.",
        )

    logger.info(
        "Generated axes: model=%s axes=%d interests=%d",
        client.model,
        len(axes),
        len(request.interests),
    )
    return AxesResponse(model=client.model, axes=axes)
