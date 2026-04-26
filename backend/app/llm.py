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

from .schemas import (
    AxisDraft,
    AxisInput,
    KnowledgeInput,
    ProfileInput,
    RoadmapTask,
)


def _knowledge_lines(knowledge: KnowledgeInput | None) -> list[str]:
    """Render the persistent knowledge document into a compact prompt
    fragment. Each section is capped to keep the total under ~600 tokens
    so the model retains room for actual reasoning even with verbose
    histories. Returns an empty list when there is nothing useful to
    inline."""
    if knowledge is None:
        return []
    lines: list[str] = []
    if knowledge.summary:
        lines.append(f"About the user: {knowledge.summary}")
    if knowledge.goals:
        lines.append("Stated goals:")
        for g in knowledge.goals[:5]:
            lines.append(f"  - {g}")
    if knowledge.constraints:
        lines.append("Constraints to respect:")
        for c in knowledge.constraints[:5]:
            lines.append(f"  - {c}")
    if knowledge.completed_highlights:
        lines.append("Recently completed (do NOT regenerate equivalents):")
        for h in knowledge.completed_highlights[:8]:
            lines.append(f"  - {h}")
    if knowledge.recent_reflections:
        lines.append("Recent reflections (lessons learned):")
        for r in knowledge.recent_reflections[:5]:
            # cap individual entries so a long blurb can't dominate
            snippet = r if len(r) <= 200 else r[:197] + "…"
            lines.append(f"  - {snippet}")
    return lines

DEFAULT_BASE_URL = "https://api.openai.com/v1"
DEFAULT_MODEL = "gpt-4o-mini"
REQUEST_TIMEOUT = 45.0

# DeepSeek-native endpoint. When DEEPSEEK_API_KEY is set and no explicit
# LLM_BASE_URL / LLM_MODEL override is provided, we route to DeepSeek
# automatically — it's OpenAI-compatible and significantly cheaper, so
# it makes sense as the default when available.
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1"
DEEPSEEK_MODEL = "deepseek-chat"

# Deploy-time fallback for the DeepSeek key; see LlmClient.__init__ for
# the rationale. Committed copy is empty — only populated in the local
# working tree of the deployer's session when the hosting platform can't
# inject real secrets.
_BAKED_DEEPSEEK_KEY = ""


class LlmConfigError(RuntimeError):
    pass


class LlmUpstreamError(RuntimeError):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status


_LEVEL_LABELS = {
    "novice": "novice (just starting, needs basics & gentle pace)",
    "learning": "learning (some exposure, ready for guided practice)",
    "confident": "confident (mid-level, ready for real projects & deeper concepts)",
    "expert": "expert (senior, needs leverage / depth / architecture, NOT tutorials)",
}


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
        "(<=80 chars). Use 'body' for a one-paragraph context. Spread "
        "due_in_days so tasks are not all on day 0.\n\n"
        "CALIBRATE DIFFICULTY TO THE USER'S LEVEL.\n"
        "  - novice: assume zero prior knowledge. Tasks like 'install X', "
        "'pass intro tutorial', 'do 5 exercises from chapter 1'. Avoid "
        "jargon.\n"
        "  - learning: short guided exercises, small projects scoped to "
        "1-2 hours each.\n"
        "  - confident: real projects with concrete deliverables (e.g. "
        "'ship a CRUD app with Riverpod state management').\n"
        "  - expert: NO tutorials, NO 'learn the basics'. Architecture, "
        "performance, mentorship, OSS contributions, design docs, public "
        "talks, optimisation. If a task sounds like it belongs in a "
        "bootcamp, you have failed.\n\n"
        "USE STEPS WHEN HELPFUL. If a task is bigger than ~30 minutes or "
        "spans multiple sub-actions, fill `steps` with 2-5 concrete "
        "sub-steps the user will tick off. Examples:\n"
        '  - {"title": "Освоить state management в Flutter", '
        '"steps": ["Прочитать главу про Riverpod", "Сделать пример '
        'TodoApp с Riverpod", "Добавить тесты на провайдеры"]}\n'
        "Skip `steps` (or leave empty) for trivial one-liners like "
        '"Сходить на пробежку 3км".'
    )


def _user_prompt(
    goal: str,
    profile: ProfileInput,
    axes: list[AxisInput],
    horizon_days: int,
    task_count: int,
    knowledge: KnowledgeInput | None = None,
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
    if profile.interest_levels:
        profile_lines.append("Self-assessed levels:")
        for interest, lvl in profile.interest_levels.items():
            label = _LEVEL_LABELS.get(lvl, lvl)
            profile_lines.append(f"  - {interest}: {label}")

    schema = (
        '{\n'
        '  "summary": "one-sentence framing of the plan",\n'
        '  "tasks": [\n'
        '    {"title": "str", "body": "str (optional)", '
        '"steps": ["str", ...optional], '
        '"axis_ids": ["axis-id"], '
        '"axis_weights": {"axis-id": 0.0..1.0, ...}, '
        '"xp": 10-60, '
        '"due_in_days": 0-' + str(horizon_days) + "}\n"
        "  ]\n"
        "}"
        "\n\nIMPORTANT about axis_weights: include this object whenever a "
        "task contributes UNEQUALLY to its axes. Keys must match `axis_ids` "
        "exactly. Values are non-negative numbers; their ratio is what "
        "matters (the client normalises). Example: a 'design and run a "
        "5-km race' task linked to 'Body' (0.7) and 'Discipline' (0.3) "
        "tells the client to give 70% of the XP to Body, 30% to "
        "Discipline. If you OMIT axis_weights, the client splits XP "
        "evenly across all linked axes — only do that if the task really "
        "is balanced."
    )

    sections = [
        f"GOAL: {goal}",
        "PROFILE:\n" + "\n".join(profile_lines),
    ]
    klines = _knowledge_lines(knowledge)
    if klines:
        sections.append("CONTEXT (persistent knowledge about the user):\n" + "\n".join(klines))
    sections.append(
        "AXES (vertices of the user's pentagon, use their 'id' fields):\n"
        + axes_lines
    )
    sections.append(
        f"Return JSON exactly in this shape (no extra keys, no fences):\n{schema}"
    )
    return "\n\n".join(sections)


class LlmClient:
    def __init__(self) -> None:
        # Devin's deploy tool auto-generates its own Dockerfile/fly.toml
        # and doesn't carry env vars from the committed fly.toml, so
        # secrets have to live in the Python source to reach the fly
        # container. _BAKED_DEEPSEEK_KEY is injected at deploy time by
        # a session-local edit and intentionally left empty in the
        # committed tree; real deployments should set DEEPSEEK_API_KEY
        # via flyctl secrets. Remove this fallback once the deploy
        # tool grows a `--env` option.
        deepseek_key = os.getenv("DEEPSEEK_API_KEY") or _BAKED_DEEPSEEK_KEY
        # Key resolution order:
        #   1. DEEPSEEK_API_KEY — if present, make DeepSeek the default
        #      backend (cheap, OpenAI-compatible, strong JSON output).
        #   2. OPENAI_API_KEY / OPENROUTER_API_KEY / LLM_API_KEY — fallback
        #      for the previous default OpenAI gateway.
        # LLM_BASE_URL / LLM_MODEL overrides always win over these
        # defaults, so an ops override stays authoritative.
        if deepseek_key:
            self.api_key = deepseek_key
            self.base_url = os.getenv(
                "LLM_BASE_URL", DEEPSEEK_BASE_URL
            ).rstrip("/")
            self.model = os.getenv("LLM_MODEL", DEEPSEEK_MODEL)
        else:
            self.api_key = (
                os.getenv("OPENAI_API_KEY")
                or os.getenv("OPENROUTER_API_KEY")
                or os.getenv("LLM_API_KEY")
            )
            self.base_url = os.getenv(
                "LLM_BASE_URL", DEFAULT_BASE_URL
            ).rstrip("/")
            self.model = os.getenv("LLM_MODEL", DEFAULT_MODEL)
        if not self.api_key:
            raise LlmConfigError(
                "No API key configured (DEEPSEEK_API_KEY / OPENAI_API_KEY"
                " / OPENROUTER_API_KEY / LLM_API_KEY)."
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
        knowledge: KnowledgeInput | None = None,
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
                        goal,
                        profile,
                        axes,
                        horizon_days,
                        task_count,
                        knowledge,
                    ),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.6,
            # 1400 is enough for 6–8 tasks from gpt-4o-mini but gets
            # truncated by verbose models (DeepSeek, Llama) on 10-task
            # requests with bodies + steps. 3000 lets those complete
            # cleanly without blowing latency up noticeably.
            "max_tokens": 3000,
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
            finish = data["choices"][0].get("finish_reason")
        except (KeyError, IndexError, TypeError) as exc:
            raise LlmUpstreamError(
                502, f"Malformed LLM response: {exc}: {data!r}"
            ) from exc

        if finish == "length":
            # The model ran out of tokens mid-JSON — the subsequent
            # `_parse_json` will blow up with a confusing "Unterminated
            # string" error. Fail loudly up front with an actionable
            # message so callers/ops know to bump max_tokens.
            raise LlmUpstreamError(
                502,
                "LLM response was truncated (finish_reason=length). "
                "Increase max_tokens or ask for fewer/shorter tasks.",
            )

        parsed = _parse_json(content)
        axis_ids = {a.id for a in axes}
        tasks = _normalize_tasks(parsed.get("tasks", []), axis_ids, horizon_days)
        summary = str(parsed.get("summary", "")).strip()
        return tasks, summary

    async def generate_axes(
        self,
        profile: ProfileInput,
        interests: list[str],
        count: int,
        knowledge: KnowledgeInput | None = None,
    ) -> list[AxisDraft]:
        """Have the LLM design 3..8 personalised growth axes.

        We do NOT pre-bake any «TeloUmDelo» pseudo-defaults — the model gets
        the user's free-form intents and produces names + symbols + a one-line
        description per axis. The Flutter UI lets the user edit them after.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": self.referer,
            "X-Title": self.title,
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": _axes_system_prompt(count)},
                {
                    "role": "user",
                    "content": _axes_user_prompt(
                        profile, interests, count, knowledge
                    ),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.7,
            # 700 was fine for gpt-4o-mini but tight for DeepSeek/Llama
            # when asked for 6–7 axes each with a full description —
            # the tail of the JSON array gets truncated. 1200 gives
            # enough headroom without meaningfully hurting latency.
            "max_tokens": 1200,
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
            finish = data["choices"][0].get("finish_reason")
        except (KeyError, IndexError, TypeError) as exc:
            raise LlmUpstreamError(
                502, f"Malformed LLM response: {exc}: {data!r}"
            ) from exc
        if finish == "length":
            # Mirror the safeguard from generate_roadmap — verbose
            # models (DeepSeek/Llama) can truncate a partially-emitted
            # axes array and produce unparseable JSON; surface the real
            # reason instead of a cryptic "LLM did not return valid JSON".
            raise LlmUpstreamError(
                502,
                "LLM axes response was truncated "
                "(finish_reason=length). Increase max_tokens or "
                "request fewer axes.",
            )
        parsed = _parse_json(content)
        return _normalize_axes(parsed.get("axes", []), count)


def _axes_system_prompt(count: int) -> str:
    return (
        "You are Noetica, a personal growth designer. "
        "Given a user's free-form interests and aspirations, design "
        f"EXACTLY {count} personal growth AXES tailored to THEIR life. "
        "Each axis is a vertex of their personal pentagon and will track XP "
        "from completed tasks. "
        "\n\n"
        "CRITICAL RULES:\n"
        "1. **No overlap.** Axes must cover DIFFERENT life domains. Do NOT "
        "create two axes that describe the same skill, profession, or "
        "activity from different angles. Examples of FORBIDDEN duplicates:\n"
        "   - 'Programming' + 'Software Testing' (same domain — merge into "
        "'Engineering' or 'Crafts')\n"
        "   - 'Running' + 'Marathon Training' (merge into 'Body')\n"
        "   - 'Coding' + 'Open Source' (merge — open source IS coding)\n"
        "   If the user listed two related interests, MERGE them under a "
        "single broader axis and mention both in the description.\n"
        "2. **Cover the whole life, not just the goal.** Even if the user "
        "only mentions one ambition, the pentagon needs balance — pick "
        "axes from at least 3 different domains: craft/profession, body, "
        "mind/learning, social/family, finance, creativity, recovery/play. "
        "A user who only said 'become a Flutter QA engineer' still has a "
        "body, relationships, and rest needs.\n"
        "3. **No generic fallback.** Do NOT default to 'Body / Mind / "
        "Family / Work / Soul' unless the user literally listed those. "
        "Names must reflect THEIR phrasing.\n"
        "4. **Distinct symbols.** Each symbol used at most once.\n"
        "\n"
        "Return STRICT JSON in the SAME language as the user's interests "
        "(Russian if Russian, English if English, etc.). Do not wrap in markdown fences. "
        "Each axis must have: a 1-2 word name (<=24 chars), a single-character "
        "unicode symbol/emoji (geometric shapes preferred for B/W minimalism: "
        "● ○ ◆ ◇ ▲ △ ■ □ ● ◐ ◑ ▹ ☆ ✪ ✣), and a short 'description' "
        "(<=140 chars) in 2nd person describing what counts as growth on this axis."
    )


def _axes_user_prompt(
    profile: ProfileInput,
    interests: list[str],
    count: int,
    knowledge: KnowledgeInput | None = None,
) -> str:
    profile_lines: list[str] = []
    if profile.name:
        profile_lines.append(f"Name: {profile.name}")
    if profile.aspiration:
        profile_lines.append(f"Year aspiration: {profile.aspiration}")
    if profile.pain_point:
        profile_lines.append(f"Pain point: {profile.pain_point}")
    profile_lines.append(f"Weekly hours available: {profile.weekly_hours}")
    if interests:
        lines = []
        for s in interests:
            lvl = profile.interest_levels.get(s)
            if lvl:
                lines.append(f"  - {s} [{lvl}]")
            else:
                lines.append(f"  - {s}")
        interests_block = (
            "INTERESTS / DESIRED GROWTH AREAS (free-form, with self-assessed level):\n"
            + "\n".join(lines)
        )
    else:
        interests_block = (
            "INTERESTS: (none provided — design from the aspiration alone)"
        )
    schema = (
        '{\n'
        '  "axes": [\n'
        '    {"name": "", "symbol": "", "description": ""}\n'
        f"  ]\n"  # exactly {count} items
        "}"
    )
    sections = [
        "PROFILE:\n" + "\n".join(profile_lines),
        interests_block,
    ]
    klines = _knowledge_lines(knowledge)
    if klines:
        sections.append("CONTEXT (persistent knowledge about the user):\n" + "\n".join(klines))
    sections.append(
        f"Design exactly {count} personalised growth axes. "
        "Names should reflect the user's real interests, not abstract life "
        "buckets. Symbols must be unique across the set."
    )
    sections.append(
        f"Return JSON exactly in this shape (no extra keys, no fences):\n{schema}"
    )
    return "\n\n".join(sections)


def _normalize_axes(raw_axes: list[Any], count: int) -> list[AxisDraft]:
    out: list[AxisDraft] = []
    seen_symbols: set[str] = set()
    seen_names: set[str] = set()
    for item in raw_axes:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        symbol = str(item.get("symbol") or "").strip()
        description = str(item.get("description") or "").strip()
        if not name or not symbol:
            continue
        # First grapheme cluster only; symbol field is bounded to 4 chars.
        symbol = symbol[:4]
        name_key = name.lower()
        if name_key in seen_names or symbol in seen_symbols:
            continue
        seen_names.add(name_key)
        seen_symbols.add(symbol)
        out.append(
            AxisDraft(
                name=name[:40],
                symbol=symbol,
                description=description[:200],
            )
        )
        if len(out) >= count:
            break
    return out


def _parse_json(content: str) -> dict[str, Any]:
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
        title = str(item.get("title") or "").strip()
        if not title:
            continue
        body = str(item.get("body") or "").strip()
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

        raw_steps = item.get("steps") or []
        if not isinstance(raw_steps, list):
            raw_steps = []
        steps = [
            str(s).strip()[:200]
            for s in raw_steps
            if isinstance(s, (str, int, float)) and str(s).strip()
        ][:8]

        # Optional per-axis XP split. Drop keys that aren't in `filtered`,
        # coerce to float, drop non-positives. Keep raw ratios — the
        # client normalises so absolute scale is irrelevant.
        raw_weights = item.get("axis_weights") or {}
        weights: dict[str, float] = {}
        if isinstance(raw_weights, dict):
            allowed = set(filtered)
            for k, v in raw_weights.items():
                if not isinstance(k, str) or k not in allowed:
                    continue
                try:
                    fv = float(v)
                except (TypeError, ValueError):
                    continue
                if fv > 0:
                    weights[k] = fv

        out.append(
            RoadmapTask(
                title=title[:120],
                body=body[:400],
                steps=steps,
                axis_ids=filtered,
                axis_weights=weights,
                xp=xp,
                due_in_days=due_in_days,
            )
        )
    return out
