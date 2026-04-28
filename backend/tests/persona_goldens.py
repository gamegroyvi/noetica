"""Integration 'golden' tests for the LLM axis + roadmap pipeline.

Not a pytest suite — runs as a standalone script so the output can be
reviewed by a human. Feeds 4 realistic personas through the same calls
the Flutter client makes (`generate_axes` then `generate_roadmap`) and
dumps each result into a markdown file under `reports/` so we can eyeball
axis distinctiveness, axis↔goal fit, task difficulty calibration, and
per-axis coverage.

Usage:
    DEEPSEEK_API_KEY=sk-... python -m tests.persona_goldens

Requires the `backend` venv with httpx + pydantic installed and a valid
DEEPSEEK_API_KEY (or OPENAI_API_KEY) in the environment.
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.llm import LlmClient  # noqa: E402
from app.schemas import AxisInput, ProfileInput  # noqa: E402


@dataclass
class Persona:
    slug: str
    name: str
    aspiration: str
    pain_point: str
    weekly_hours: int
    interests: list[str]
    interest_levels: dict[str, str]
    summary: str  # short intro for the reader of the report


PERSONAS: list[Persona] = [
    Persona(
        slug="01_burned_out_student",
        name="Артём",
        aspiration="Хочу перестать выгорать и вернуть любовь к учёбе,"
                   " закрыть сессию без нервов",
        pain_point="сплю по 4 часа, не могу начать курсач, тревога, залипаю в телефоне",
        weekly_hours=10,
        interests=[
            "учёба в универе (CS, 3 курс)",
            "сон и режим",
            "сократить экранное время",
            "спорт дома",
        ],
        interest_levels={
            "учёба в универе (CS, 3 курс)": "confident",
            "сон и режим": "novice",
            "сократить экранное время": "novice",
            "спорт дома": "learning",
        },
        summary="Студент CS, 3 курс. Выгорание, бессонница, прокрастинация. "
                "Хочет пережить сессию без коллапса и вернуть базовое "
                "самочувствие.",
    ),
    Persona(
        slug="02_new_mom_returning",
        name="Маша",
        aspiration="Вернуться в форму после родов и плавно заходить в "
                   "работу фронтендом после декрета",
        pain_point="мало сна, голова не соображает, тело не своё, прокрастинирую",
        weekly_hours=6,
        interests=[
            "фронтенд (React, Next.js)",
            "послеродовое восстановление",
            "питание",
            "английский для чтения доков",
        ],
        interest_levels={
            "фронтенд (React, Next.js)": "confident",
            "послеродовое восстановление": "novice",
            "питание": "learning",
            "английский для чтения доков": "confident",
        },
        summary="Мама в декрете, 8 месяцев ребёнку. Фронтенд-разработчик 4 года "
                "опыта до декрета. Хочет вернуться постепенно без ущерба для себя.",
    ),
    Persona(
        slug="03_senior_to_manager",
        name="Денис",
        aspiration="Перейти из senior-разработчика в инженер-менеджера в "
                   "своей компании в течение года",
        pain_point="не умею давать фидбек, избегаю конфликтов, боюсь делегировать",
        weekly_hours=12,
        interests=[
            "people management",
            "engineering strategy",
            "публичные выступления",
            "системный дизайн",
        ],
        interest_levels={
            "people management": "novice",
            "engineering strategy": "learning",
            "публичные выступления": "novice",
            "системный дизайн": "expert",
        },
        summary="Senior backend engineer с 8 лет опытом, хочет стать EM. "
                "Технически силён, но hard skills менеджмента — с нуля.",
    ),
    Persona(
        slug="04_med_student_ordinatura",
        name="Лиза",
        aspiration="Пройти в ординатуру по кардиологии и не сломаться "
                   "морально по пути",
        pain_point="тревога перед экзаменом, много зубрёжки, забывчивость, "
                   "нет друзей на факультете",
        weekly_hours=25,
        interests=[
            "кардиология (база)",
            "тесты ординатуры",
            "английский медицинский",
            "соцсвязи (друзья, знакомства)",
            "отдых и сон",
        ],
        interest_levels={
            "кардиология (база)": "confident",
            "тесты ординатуры": "learning",
            "английский медицинский": "learning",
            "соцсвязи (друзья, знакомства)": "novice",
            "отдых и сон": "learning",
        },
        summary="Студентка медвуза, 6 курс. Цель — ординатура по "
                "кардиологии. Учится много, но одиноко и тревожно.",
    ),
]


def _fmt_axes(axes_drafts) -> str:
    out = []
    for i, a in enumerate(axes_drafts, 1):
        out.append(f"**{i}. {a.symbol} {a.name}**  \n    _{a.description}_")
    return "\n".join(out)


def _fmt_tasks(tasks, axes_by_id) -> str:
    out = []
    for i, t in enumerate(tasks, 1):
        links = ", ".join(
            f"{axes_by_id.get(axid, axid)}" for axid in t.axis_ids
        )
        due = f" · +{t.due_in_days}д"
        xp = f" · {t.xp} XP"
        out.append(f"**{i}. {t.title}**  \n    _axes:_ {links}{due}{xp}")
        if t.body:
            out.append(f"    _body:_ {t.body.strip()[:200]}")
        if t.steps:
            out.append("    _steps:_")
            for s in t.steps:
                out.append(f"      - {s}")
    return "\n".join(out)


async def run_persona(client: LlmClient, persona: Persona) -> dict:
    profile = ProfileInput(
        name=persona.name,
        aspiration=persona.aspiration,
        pain_point=persona.pain_point,
        weekly_hours=persona.weekly_hours,
        interest_levels=persona.interest_levels,
    )

    axes_drafts = await client.generate_axes(
        profile=profile,
        interests=persona.interests,
        count=5,
    )

    # The roadmap call needs axes as AxisInput (with stable ids). Assign
    # sequential ids just like the Flutter client does.
    axes: list[AxisInput] = [
        AxisInput(
            id=f"axis_{i + 1}",
            name=d.name,
            symbol=d.symbol,
        )
        for i, d in enumerate(axes_drafts)
    ]
    axes_by_id = {a.id: f"{a.symbol} {a.name}" for a in axes}

    tasks, summary = await client.generate_roadmap(
        goal=persona.aspiration,
        profile=profile,
        axes=axes,
        horizon_days=30,
        task_count=10,
    )

    return {
        "persona": persona,
        "axes_drafts": axes_drafts,
        "axes": axes,
        "axes_by_id": axes_by_id,
        "tasks": tasks,
        "summary": summary,
    }


def render_markdown(result: dict) -> str:
    p: Persona = result["persona"]
    md = [
        f"# Persona · {p.slug}",
        "",
        f"**Имя:** {p.name}",
        f"**Цель на год:** {p.aspiration}",
        f"**Болевая точка:** {p.pain_point}",
        f"**Часов в неделю:** {p.weekly_hours}",
        f"**Интересы (уровень):**",
    ]
    for s in p.interests:
        lvl = p.interest_levels.get(s, "—")
        md.append(f"  - {s} [{lvl}]")
    md += [
        "",
        f"**Краткое описание:** {p.summary}",
        "",
        "---",
        "",
        "## Сгенерированные оси",
        "",
        _fmt_axes(result["axes_drafts"]),
        "",
        "---",
        "",
        "## Сгенерированный roadmap (10 задач · 30 дней)",
        "",
        f"_LLM summary:_ {result['summary'] or '—'}",
        "",
        _fmt_tasks(result["tasks"], result["axes_by_id"]),
        "",
    ]
    return "\n".join(md)


async def main() -> None:
    client = LlmClient()
    out_dir = Path(__file__).resolve().parent.parent / "reports"
    out_dir.mkdir(exist_ok=True)
    index_lines = [
        "# Noetica · LLM persona golden tests",
        "",
        f"Backend: `{client.base_url}` · Model: `{client.model}`",
        "",
    ]

    for persona in PERSONAS:
        print(f"→ {persona.slug}  ({persona.name})")
        try:
            result = await run_persona(client, persona)
        except Exception as exc:  # noqa: BLE001
            print(f"  ✗ FAILED: {exc}")
            index_lines.append(f"- **{persona.slug}** — FAILED: `{exc}`")
            continue
        md = render_markdown(result)
        out_file = out_dir / f"{persona.slug}.md"
        out_file.write_text(md, encoding="utf-8")
        print(f"  ✓ saved → {out_file}")
        axes_str = ", ".join(f"{a.symbol} {a.name}" for a in result["axes"])
        index_lines.append(
            f"- [{persona.slug}]({persona.slug}.md) — {axes_str}"
        )

    index_lines.append("")
    (out_dir / "index.md").write_text("\n".join(index_lines), encoding="utf-8")
    print(f"\nReports index: {out_dir / 'index.md'}")


if __name__ == "__main__":
    asyncio.run(main())
