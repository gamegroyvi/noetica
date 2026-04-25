"""OpenAI-compatible LLM client used for roadmap generation.

Works against OpenRouter (default) — same shape works with OmniRoute self-hosted
if `LLM_BASE_URL` is overridden. Keeps the request/response surface minimal
because we only need non-streaming chat completions with JSON output.
"""

from __future__ import annotations

import json
import os
from typing import Any

import httpx

from .schemas import AxisInput, ProfileInput, RoadmapTask

DEFAULT_BASE_URL = "https://api.openai.com/v1"
DEFAULT_MODEL = "gpt-4o-mini"
REQUEST_TIMEOUT = 45.0


class LlmConfigError(RuntimeError):
    pass


class LlmUpstreamError(RuntimeError):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status


def _system_prompt(task_count: int, horizon_days: int) -> str:
    return (
        "You are Noetica, a mentor that turns a personal growth goal into a "
        "concrete plan of small, trackable tasks. "
        "Return STRICT JSON matching the provided schema. "
        "Write all human-facing text in the SAME language as the user's goal "
        "(Russian if they write in Russian, English if English, etc.). "
        "Do not wrap the JSON in markdown fences. "
        f"Produce exactly {task_count} tasks spanning ~{horizon_days} days. "
        "Each task.xp must be 10..60 and reflect difficulty / effort. "
        "Link each task to 1-2 axis_ids from the provided axes (use the axis "
        "'id' field, never invent new ids). Keep titles short and imperative "
        "(<=80 chars). Use 'body' for one-line context only when it adds "
        "information. Spread due_in_days so tasks are not all on day 0."
    )


def _user_prompt(
    goal: str,
    profile: ProfileInput,
    axes: list[AxisInput],
    horizon_days: int,
    task_count: int,
) -> str:
    axes_lines = "\n".join(
        f'  - {{"id": "{a.id}", "name": "{a.name}", "symbol": "{a.symbol}"}}'
        for a in axes
    )
    profile_lines = []
    if profile.name:
        profile_lines.append(f"Name: {profile.name}")
    if profile.aspiration:
        profile_lines.append(f"Year aspiration: {profile.aspiration}")
    if profile.pain_point:
        profile_lines.append(f"Pain point: {profile.pain_point}")
    profile_lines.append(f"Weekly hours available: {profile.weekly_hours}")

    schema = (
        '{\n'
        '  "summary": "one-sentence framing of the plan",\n'
        '  "tasks": [\n'
        '    {"title": "str", "body": "str (optional)", '
        '"axis_ids": ["axis-id"], "xp": 10-60, '
        '"due_in_days": 0-' + str(horizon_days) + "}\n"
        "  ]\n"
        "}"
    )

    return (
        f"GOAL: {goal}\n\n"
        f"PROFILE:\n" + "\n".join(profile_lines) + "\n\n"
        "AXES (vertices of the user's pentagon, use their 'id' fields):\n"
        f"{axes_lines}\n\n"
        f"Return JSON exactly in this shape (no extra keys, no fences):\n{schema}"
    )


class LlmClient:
    def __init__(self) -> None:
        self.base_url = os.getenv("LLM_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
        self.model = os.getenv("LLM_MODEL", DEFAULT_MODEL)
        self.api_key = (
            os.getenv("OPENAI_API_KEY")
            or os.getenv("OPENROUTER_API_KEY")
            or os.getenv("LLM_API_KEY")
        )
        if not self.api_key:
            raise LlmConfigError(
                "No API key configured (OPENAI_API_KEY / "
                "OPENROUTER_API_KEY / LLM_API_KEY)."
            )
        self.referer = os.getenv(
            "LLM_HTTP_REFERER", "https://noetica.app"
        )
        self.title = os.getenv("LLM_APP_TITLE", "Noetica")

    async def generate_roadmap(
        self,
        goal: str,
        profile: ProfileInput,
        axes: list[AxisInput],
        horizon_days: int,
        task_count: int,
    ) -> tuple[list[RoadmapTask], str]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            # OpenRouter-specific attribution headers (ignored by OmniRoute).
            "HTTP-Referer": self.referer,
            "X-Title": self.title,
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": _system_prompt(task_count, horizon_days),
                },
                {
                    "role": "user",
                    "content": _user_prompt(
                        goal, profile, axes, horizon_days, task_count
                    ),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.6,
            "max_tokens": 1400,
        }

        url = f"{self.base_url}/chat/completions"
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.post(url, json=payload, headers=headers)

        if response.status_code >= 400:
            raise LlmUpstreamError(
                response.status_code,
                f"LLM upstream error ({response.status_code}): {response.text[:500]}",
            )

        data = response.json()
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LlmUpstreamError(
                502, f"Malformed LLM response: {exc}: {data!r}"
            ) from exc

        parsed = _parse_roadmap_json(content)
        axis_ids = {a.id for a in axes}
        tasks = _normalize_tasks(parsed.get("tasks", []), axis_ids, horizon_days)
        summary = str(parsed.get("summary", "")).strip()
        return tasks, summary


def _parse_roadmap_json(content: str) -> dict[str, Any]:
    text = content.strip()
    if text.startswith("```"):
        # Strip ```json ... ``` fences in case the model ignored the instruction.
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
        text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise LlmUpstreamError(
            502, f"LLM did not return valid JSON: {exc}"
        ) from exc


def _normalize_tasks(
    raw_tasks: list[Any],
    axis_ids: set[str],
    horizon_days: int,
) -> list[RoadmapTask]:
    out: list[RoadmapTask] = []
    for item in raw_tasks:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title", "")).strip()
        if not title:
            continue
        body = str(item.get("body", "")).strip()
        xp_raw = item.get("xp", 20)
        try:
            xp = int(xp_raw)
        except (TypeError, ValueError):
            xp = 20
        xp = max(5, min(60, xp))
        due_raw = item.get("due_in_days")
        due_in_days: int | None
        if due_raw is None:
            due_in_days = None
        else:
            try:
                due_in_days = max(0, min(horizon_days, int(due_raw)))
            except (TypeError, ValueError):
                due_in_days = None

        raw_axes = item.get("axis_ids") or []
        if not isinstance(raw_axes, list):
            raw_axes = []
        filtered = [aid for aid in raw_axes if isinstance(aid, str) and aid in axis_ids]

        out.append(
            RoadmapTask(
                title=title[:120],
                body=body[:400],
                axis_ids=filtered,
                xp=xp,
                due_in_days=due_in_days,
            )
        )
    return out
