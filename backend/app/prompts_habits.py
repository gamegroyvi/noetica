"""Prompts for the «Микро-привычки» AI tool.

Single-stage flow: user gives a free-form intent + duration; we ask
the LLM to expand it into N tiny, doable daily actions ordered such
that each day builds on the previous one without overwhelming.

Kept separate from `prompts_menu.py` so we can iterate on copy in
isolation. The LLM client (`llm.py`) only knows the function names.
"""

from __future__ import annotations


def habits_system_prompt(duration_days: int, axis_hint: str) -> str:
    """System prompt — micro-actions only, language follows user.

    The model gets a single hard constraint: actions must be tiny
    (≤2 minutes effort) so the user actually does them. We've seen
    repeatedly that "go to gym" and "meditate 30 min" land as 0%
    completion; "put on shoes by the door" and "breathe 3 times" land
    as 80%+. We bake that bias into the prompt.
    """
    axis_clause = ""
    if axis_hint.strip():
        axis_clause = (
            f"\n7. Действия должны касаться сферы: «{axis_hint.strip()}». "
            "Не уходи в смежные темы."
        )
    return (
        "Ты — Noetica-коуч по микро-привычкам. Преврати желание "
        f"пользователя в план из ровно {duration_days} крошечных "
        "ежедневных действий.\n\n"
        "ПРАВИЛА:\n"
        "1. Каждое действие — НЕ БОЛЬШЕ 2 минут реального усилия. "
        "«Завести таймер на 60 секунд», «положить телефон в другую "
        "комнату», «выпить стакан воды». НЕ «помедитировать 20 минут», "
        "НЕ «сходить в зал». Если по другому никак — раздели на два дня.\n"
        "2. Дни идут по нарастающей: день 1 — самое лёгкое (тренируем "
        "появление), последний день — закрепляющий ритуал.\n"
        "3. Не повторяй формулировки. Каждый день — новое микро-действие "
        "или эволюция вчерашнего (2-3 шт. подряд можно как «связка»).\n"
        "4. Заголовок (`title`) ≤ 80 символов, императивный, на «ты».\n"
        "5. Поле `why` — ОДНО предложение, до 200 символов. Зачем "
        "именно это действие, без воды, без «это поможет тебе…».\n"
        "6. Отвечай на ТОМ ЖЕ языке, на котором написан intent."
        f"{axis_clause}\n\n"
        "Верни СТРОГО JSON в указанной схеме, без markdown-обёрток, "
        "без комментариев."
    )


def habits_user_prompt(
    intent: str,
    duration_days: int,
    notes: str,
) -> str:
    """User-side prompt — schema + the intent itself."""
    schema = (
        '{\n'
        '  "summary": "1 строкой, как этот план движет к цели",\n'
        '  "days": [\n'
        '    {"day_index": 1, "title": "...", "why": "..."},\n'
        '    {"day_index": 2, "title": "...", "why": "..."}\n'
        '  ]\n'
        '}'
    )
    sections = [
        f"ЦЕЛЬ ПОЛЬЗОВАТЕЛЯ:\n{intent.strip()}",
        f"ДЛИТЕЛЬНОСТЬ: ровно {duration_days} дней.",
        f"СХЕМА (строго в этом виде):\n{schema}",
    ]
    if notes.strip():
        sections.append(f"ДОПОЛНИТЕЛЬНЫЕ ПОЖЕЛАНИЯ:\n{notes.strip()}")
    sections.append(
        f"Сгенерируй массив из ровно {duration_days} объектов в `days`, "
        "по одному на каждый день."
    )
    return "\n\n".join(sections)
