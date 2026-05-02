"""Groq LLM client used for roadmap generation.

Uses Groq's OpenAI-compatible endpoint so the request/response surface
stays the standard chat-completions shape. Only `GROQ_API_KEY` is
required — free tier gives 30 RPM / 14 400 RPD for
llama-3.3-70b-versatile.
"""

from __future__ import annotations

import json
import os
from typing import Any

import httpx

from .schemas import (
    AxisDraft,
    AxisInput,
    GeneratorItem,
    GeneratorRunRequest,
    GeneratorRunResponse,
    HabitDay,
    HabitsPlan,
    KnowledgeInput,
    MenuDay,
    MenuIngredient,
    MenuMeal,
    MenuPlan,
    ProfileInput,
    RoadmapTask,
)
from .prompts_habits import (
    habits_system_prompt,
    habits_user_prompt,
)
from .prompts_runtime import render_template, schema_addendum
from .prompts_menu import (
    menu_system_prompt,
    menu_user_prompt,
    recipe_system_prompt,
    recipe_user_prompt,
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

# Groq — free, fast, OpenAI-compatible.
GROQ_BASE_URL = "https://api.groq.com/openai/v1"
GROQ_MODEL = "llama-3.3-70b-versatile"
REQUEST_TIMEOUT = 45.0


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
        self.api_key = os.getenv("GROQ_API_KEY", "")
        if not self.api_key:
            raise LlmConfigError(
                "No API key configured. Set the GROQ_API_KEY "
                "environment variable (https://console.groq.com/keys)."
            )
        self.base_url = os.getenv(
            "LLM_BASE_URL", GROQ_BASE_URL
        ).rstrip("/")
        self.model = os.getenv("LLM_MODEL", GROQ_MODEL)

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
        regen_hint: str | None = None,
        variation_seed: int | None = None,
    ) -> list[AxisDraft]:
        """Have the LLM design 3..8 personalised growth axes.

        We do NOT pre-bake any «TeloUmDelo» pseudo-defaults — the model gets
        the user's free-form intents and produces names + symbols + a one-line
        description per axis. The Flutter UI lets the user edit them after.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": _axes_system_prompt(count)},
                {
                    "role": "user",
                    "content": _axes_user_prompt(
                        profile, interests, count, knowledge,
                        regen_hint=regen_hint,
                        variation_seed=variation_seed,
                    ),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.7,
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
            raise LlmUpstreamError(
                502,
                "LLM axes response was truncated "
                "(finish_reason=length). Increase max_tokens or "
                "request fewer axes.",
            )
        parsed = _parse_json(content)
        return _normalize_axes(parsed.get("axes", []), count)

    async def generate_menu_plan(
        self,
        goal: str,
        servings: int,
        restrictions: str,
        extra_notes: str,
    ) -> MenuPlan:
        """Stage 1 — full week structure (names + ingredients + macros).

        Returns a `MenuPlan` ready to be normalised into Entry-y on the
        client. The model is asked for strict JSON; we hard-fail with a
        502 if it doesn't parse so callers can surface a retry button.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": menu_system_prompt(servings, goal, restrictions),
                },
                {
                    "role": "user",
                    "content": menu_user_prompt(extra_notes),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.7,
            # 21 meals + shopping list comfortably fit; bump if we ever
            # add a snack-by-default mode.
            "max_tokens": 6000,
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
            raise LlmUpstreamError(
                502,
                "LLM menu response was truncated (finish_reason=length). "
                "Increase max_tokens or simplify the request.",
            )
        parsed = _parse_json(content)
        return _normalize_menu_plan(parsed, model=self.model)

    async def generate_meal_recipe(
        self,
        meal_name: str,
        ingredients: list[dict[str, str]],
        goal: str,
        servings: int,
    ) -> str:
        """Stage 2 — single meal recipe rendered as markdown.

        Returns the raw markdown body. `temperature` is slightly lower
        than stage 1 so we get terse recipes that respect the template
        rather than chatty re-introductions.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": recipe_system_prompt()},
                {
                    "role": "user",
                    "content": recipe_user_prompt(
                        meal_name, ingredients, goal, servings,
                    ),
                },
            ],
            "temperature": 0.5,
            "max_tokens": 900,
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
            raise LlmUpstreamError(
                502,
                "LLM recipe response was truncated (finish_reason=length). "
                "Increase max_tokens or simplify the request.",
            )
        markdown = str(content).strip()
        # Strip accidental code-fence wrappers — Groq sometimes wraps
        # markdown content in triple backticks despite instruction.
        # Mirrors the prefix-trimming logic in `_parse_json` so we don't
        # accidentally eat real recipe characters (e.g. a meal that
        # starts with "marinated…").
        if markdown.startswith("```"):
            markdown = markdown.strip("`")
            if markdown.lower().startswith("markdown"):
                markdown = markdown[len("markdown"):]
            markdown = markdown.strip()
        if not markdown:
            raise LlmUpstreamError(502, "Empty recipe content from LLM.")
        return markdown

    async def generate_habits_plan(
        self,
        intent: str,
        duration_days: int,
        axis_hint: str,
        notes: str,
    ) -> HabitsPlan:
        """Single-stage habit plan — `duration_days` micro-actions.

        We ask for strict JSON shaped like `HabitsPlan`. The route
        validates the day count post-hoc; the normaliser drops
        malformed entries silently and lets the route decide whether
        the remaining list is acceptable.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": habits_system_prompt(duration_days, axis_hint),
                },
                {
                    "role": "user",
                    "content": habits_user_prompt(intent, duration_days, notes),
                },
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.6,
            # 30 days × ~80 tokens per micro-action + summary fits under
            # 3 k tokens with comfort. Bump if we ever extend the cap.
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
            raise LlmUpstreamError(
                502,
                "LLM habits response was truncated (finish_reason=length). "
                "Reduce duration_days or simplify the intent.",
            )
        parsed = _parse_json(content)
        return _normalize_habits_plan(
            parsed,
            model=self.model,
            intent=intent,
            duration_days=duration_days,
        )

    async def run_generator(
        self,
        request: GeneratorRunRequest,
    ) -> GeneratorRunResponse:
        """Universal manifest runtime.

        Renders the author's prompts against the form values, calls
        the LLM with strict JSON mode, validates against the fixed
        item schema, trims overshoot. Author-controlled prompts +
        server-controlled output contract = the same client can
        consume any tool's results.

        We choose `max_tokens` proportionally to `max_items` — each
        item is roughly 100 tokens (title + body + offset + JSON
        overhead) so 50 items × ~100 = 5 k tokens with headroom.
        """
        try:
            user_prompt = render_template(
                request.prompt_user, dict(request.inputs),
            )
            system_prompt = render_template(
                request.prompt_system, dict(request.inputs),
            ) + schema_addendum(request.max_items)
        except KeyError as exc:
            # 422-shaped error — the route catches and rewraps.
            raise ValueError(
                f"prompt template references unknown input: {exc.args[0]!r}",
            ) from exc

        max_tokens = min(8000, 600 + request.max_items * 110)

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "response_format": {"type": "json_object"},
            "temperature": float(request.temperature),
            "max_tokens": max_tokens,
        }
        url = f"{self.base_url}/chat/completions"
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.post(url, json=payload, headers=headers)
        if response.status_code >= 400:
            raise LlmUpstreamError(
                response.status_code,
                f"LLM upstream error ({response.status_code}): "
                f"{response.text[:500]}",
            )
        data = response.json()
        try:
            content = data["choices"][0]["message"]["content"]
            finish = data["choices"][0].get("finish_reason")
        except (KeyError, IndexError, TypeError) as exc:
            raise LlmUpstreamError(
                502, f"Malformed LLM response: {exc}: {data!r}",
            ) from exc
        if finish == "length":
            raise LlmUpstreamError(
                502,
                "LLM run was truncated (finish_reason=length). "
                "Reduce max_items or simplify the prompt.",
            )
        parsed = _parse_json(content)
        return _normalize_run_response(
            parsed,
            model=self.model,
            max_items=request.max_items,
        )


def _normalize_run_response(
    parsed: dict[str, Any],
    *,
    model: str,
    max_items: int,
) -> GeneratorRunResponse:
    """Coerce a possibly-fuzzy LLM JSON into a clean response.

    Rules:
    - Drop items missing a non-empty title.
    - Truncate `body` and `title` if they exceed schema limits (the
      LLM occasionally overshoots even with explicit caps).
    - Coerce `due_offset_days` to int when string-typed; drop if
      out-of-range or unparseable rather than 502'ing the whole run.
    - Trim to `max_items`. The LLM occasionally returns one extra.
    """
    items_raw = parsed.get("items") if isinstance(parsed, dict) else None
    if not isinstance(items_raw, list):
        raise LlmUpstreamError(
            502, "LLM response missing `items` array.",
        )

    cleaned: list[GeneratorItem] = []
    for raw in items_raw:
        if not isinstance(raw, dict):
            continue
        title = str(raw.get("title", "")).strip()
        if not title:
            continue
        if len(title) > 120:
            title = title[:117] + "\u2026"
        body = str(raw.get("body", "") or "").strip()
        if len(body) > 2000:
            body = body[:1997] + "\u2026"

        due: int | None = None
        due_raw = raw.get("due_offset_days")
        if due_raw is not None:
            try:
                due_int = int(due_raw)
                if 0 <= due_int <= 365:
                    due = due_int
            except (TypeError, ValueError):
                pass

        cleaned.append(
            GeneratorItem(title=title, body=body, due_offset_days=due),
        )

    cleaned = cleaned[:max_items]
    summary = str(parsed.get("summary", "") or "").strip()
    if len(summary) > 500:
        summary = summary[:497] + "\u2026"
    return GeneratorRunResponse(
        model=model, summary=summary, items=cleaned,
    )


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
    regen_hint: str | None = None,
    variation_seed: int | None = None,
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
    if regen_hint:
        sections.append(
            "REGENERATION REQUEST: the user already has a set of axes "
            "and is asking for a *different* one. Honour this guidance "
            "— don't repeat the previous answer:\n"
            f"  {regen_hint.strip()}"
        )
    if variation_seed is not None:
        # Pure-noise tail — ensures the prompt hashes differently per
        # call so the LLM produces a fresh sample on repeated taps.
        sections.append(f"VARIATION HASH: 0x{variation_seed:08x}")
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


def _normalize_menu_plan(parsed: dict[str, Any], *, model: str) -> MenuPlan:
    """Coerce the LLM's stage-1 JSON into our Pydantic schema.

    The model occasionally returns numbers as strings or wraps `null`
    meals as empty objects. We swallow those quirks here so the
    `/tools/menu/generate` route always returns a clean shape.
    """
    raw_days = parsed.get("days") or []
    days: list[MenuDay] = []
    if isinstance(raw_days, list):
        for d in raw_days:
            if not isinstance(d, dict):
                continue
            day_name = str(d.get("day_name") or "").strip()
            if not day_name:
                continue
            days.append(
                MenuDay(
                    day_name=day_name[:24],
                    breakfast=_normalize_meal(d.get("breakfast")),
                    lunch=_normalize_meal(d.get("lunch")),
                    dinner=_normalize_meal(d.get("dinner")),
                    snack=_normalize_meal(d.get("snack")),
                )
            )

    avg = parsed.get("daily_avg_calories", 0)
    try:
        # Match `_macro`: tolerate stringy floats like "1500.5" since the
        # model occasionally returns macros as strings.
        avg_int = max(0, min(5000, int(round(float(avg)))))
    except (TypeError, ValueError):
        avg_int = 0

    notes = str(parsed.get("notes") or "").strip()[:600]

    raw_shop = parsed.get("shopping_list") or {}
    shopping: dict[str, list[MenuIngredient]] = {}
    if isinstance(raw_shop, dict):
        for category, items in raw_shop.items():
            if not isinstance(category, str) or not isinstance(items, list):
                continue
            cleaned = [
                ing for ing in (_normalize_ingredient(it) for it in items) if ing
            ]
            if cleaned:
                shopping[category[:40]] = cleaned

    return MenuPlan(
        model=model,
        days=days,
        daily_avg_calories=avg_int,
        notes=notes,
        shopping_list=shopping,
    )


def _normalize_meal(raw: Any) -> MenuMeal | None:
    """Return None for missing / null / empty meals — matches schema."""
    if not isinstance(raw, dict):
        return None
    name = str(raw.get("name") or "").strip()
    if not name:
        return None

    raw_ings = raw.get("ingredients") or []
    ingredients: list[MenuIngredient] = []
    if isinstance(raw_ings, list):
        for it in raw_ings:
            ing = _normalize_ingredient(it)
            if ing:
                ingredients.append(ing)

    def _macro(key: str, lim: int) -> int:
        v = raw.get(key, 0)
        try:
            return max(0, min(lim, int(round(float(v)))))
        except (TypeError, ValueError):
            return 0

    return MenuMeal(
        name=name[:120],
        ingredients=ingredients,
        calories=_macro("calories", 5000),
        protein=_macro("protein", 400),
        fat=_macro("fat", 400),
        carbs=_macro("carbs", 800),
    )


def _normalize_ingredient(raw: Any) -> MenuIngredient | None:
    if not isinstance(raw, dict):
        return None
    name = str(raw.get("name") or "").strip()
    if not name:
        return None
    amount = str(raw.get("amount") or "").strip()
    return MenuIngredient(name=name[:80], amount=amount[:40])


def _normalize_habits_plan(
    parsed: dict[str, Any],
    *,
    model: str,
    intent: str,
    duration_days: int,
) -> HabitsPlan:
    """Coerce the LLM's JSON into our `HabitsPlan` schema.

    Drops malformed entries (missing title, non-int day_index, etc.).
    Re-numbers `day_index` linearly (1..N) so the client doesn't have
    to handle gaps when the model occasionally skips a day.
    """
    raw_days = parsed.get("days") or []
    days: list[HabitDay] = []
    if isinstance(raw_days, list):
        for d in raw_days:
            if not isinstance(d, dict):
                continue
            title = str(d.get("title") or "").strip()
            if not title:
                continue
            why = str(d.get("why") or "").strip()
            days.append(
                HabitDay(
                    # Re-numbered below; pass a placeholder that
                    # satisfies pydantic's ge=1 constraint.
                    day_index=1,
                    title=title[:80],
                    why=why[:240],
                )
            )

    # Trim to `duration_days` so prompts that overshoot don't blow the
    # cap, and re-number linearly. We never undershoot — the route
    # raises 502 on `len(days) < requested`.
    days = days[:duration_days]
    days = [
        HabitDay(day_index=i + 1, title=d.title, why=d.why)
        for i, d in enumerate(days)
    ]

    summary = str(parsed.get("summary") or "").strip()[:400]
    return HabitsPlan(
        model=model,
        intent=intent.strip()[:300],
        summary=summary,
        days=days,
    )
