"""Prompts for the «Меню недели» AI tool.

Adapted from the `myaicook_bot_max` Telegram bot's two-stage flow:
stage 1 returns a structured 7-day plan (names + ingredients + macros)
in JSON; stage 2 returns a single full recipe on demand. Keeping the
templates in their own module lets us iterate on copy without touching
the LLM client.
"""

from __future__ import annotations

# Описания целей питания — используются во всех меню-промптах. Тексты
# воспроизведены из cookbot, чтобы юзеры с тем же опытом получали
# сопоставимые рекомендации.
GOAL_DESCRIPTIONS: dict[str, str] = {
    "lose_weight": (
        "похудение. До 400 ккал на порцию. Приоритет: нежирные белки, "
        "овощи, цельнозерновые. Без сахара, трансжиров, фастфуда."
    ),
    "health": (
        "поддержание здоровья. 400–600 ккал на порцию. "
        "Разнообразие продуктов всех групп, умеренность."
    ),
    "muscle": (
        "набор мышечной массы. Не менее 500 ккал на порцию. "
        "Белок ≥30г на порцию. Упор на яйца, мясо, рыбу, творог, крупы."
    ),
    "energy": (
        "повышение энергии. 400–550 ккал. Сложные углеводы, продукты "
        "с магнием/железом, минимум быстрых углеводов."
    ),
    "classic": "разнообразное домашнее питание. 400–600 ккал на порцию.",
}


def goal_description(goal: str) -> str:
    """Return the human-readable goal blurb, falling back to «classic».

    Centralised so request validation and prompt rendering stay in sync.
    """
    return GOAL_DESCRIPTIONS.get(goal, GOAL_DESCRIPTIONS["classic"])


def menu_system_prompt(servings: int, goal: str, restrictions: str) -> str:
    """System prompt for stage 1 — week structure only, no recipes.

    The model must return strict JSON matching `MenuPlan` (see
    `schemas.py`). We embed servings + goal explicitly so the macros
    line up with what the user asked for.
    """
    restr = restrictions.strip() or "(нет)"
    return (
        "Ты — AI-повар Noetica. Составь структуру меню на 7 дней.\n\n"
        "ПРАВИЛА:\n"
        "1. Для каждого дня: завтрак, обед, ужин. Перекус — опционально, "
        "добавляй только если уместно для цели.\n"
        "2. Если приём пищи не нужен — ставь строго null (не пустой объект, "
        "не пустую строку).\n"
        f"3. Цель питания: {goal_description(goal)}\n"
        f"4. Порций на каждое блюдо: {servings}.\n"
        f"5. Ограничения и аллергии пользователя: {restr}.\n"
        "6. Только продукты из обычных российских магазинов, сезонные.\n"
        "7. Не повторять блюдо дважды за неделю. Чередуй: птица, рыба, "
        "мясо, яйца, крупы, бобовые.\n"
        "8. НЕ включай шаги приготовления — только название блюда, "
        "ингредиенты с граммовкой и КБЖУ на одну порцию.\n"
        "9. Также верни сводный shopping_list (список покупок на всю "
        "неделю), сгруппированный по категориям. Соль/воду/растительное "
        "масло не включай.\n\n"
        "Верни СТРОГО JSON в указанной схеме, без markdown-обёрток."
    )


def menu_user_prompt(extra_notes: str) -> str:
    """User-side prompt — schema + free-form preferences from the form."""
    schema = (
        '{\n'
        '  "days": [\n'
        '    {\n'
        '      "day_name": "Понедельник",\n'
        '      "breakfast": {"name": "...", "ingredients": [{"name": "...", "amount": "..."}], '
        '"calories": 0, "protein": 0, "fat": 0, "carbs": 0},\n'
        '      "lunch": {...},\n'
        '      "dinner": {...},\n'
        '      "snack": null\n'
        '    }\n'
        '  ],\n'
        '  "daily_avg_calories": 0,\n'
        '  "notes": "...",\n'
        '  "shopping_list": {\n'
        '    "Мясо и рыба": [{"name": "...", "amount": "..."}],\n'
        '    "Молочные": [...],\n'
        '    "Овощи": [...],\n'
        '    "Фрукты": [...],\n'
        '    "Крупы": [...],\n'
        '    "Другое": [...]\n'
        '  }\n'
        '}'
    )
    notes = extra_notes.strip()
    sections = [f"СХЕМА (строго в этом виде):\n{schema}"]
    if notes:
        sections.append(f"ДОПОЛНИТЕЛЬНЫЕ ПОЖЕЛАНИЯ:\n{notes}")
    sections.append("Сгенерируй меню на 7 дней.")
    return "\n\n".join(sections)


def recipe_system_prompt() -> str:
    """System prompt for stage 2 — single full recipe in markdown.

    We deliberately ask for markdown (not JSON) so the result drops
    straight into Noetica's note body without post-processing.
    """
    return (
        "Ты — AI-повар Noetica. Составь полный рецепт одного блюда.\n\n"
        "ПРАВИЛА:\n"
        "1. Используй ТОЛЬКО указанные ингредиенты. Соль, перец, "
        "растительное масло — по умолчанию доступны.\n"
        "2. Шаги приготовления — чёткие, понятные, 4-7 шагов.\n"
        "3. КБЖУ — приблизительное, ставь ~ перед числами.\n"
        "4. Отвечай в формате markdown — без code-fence, без HTML.\n\n"
        "ШАБЛОН (соблюдай разметку):\n"
        "## {{Название}}\n\n"
        "**Сложность:** Легко / Средне / Сложно  \n"
        "**Время:** X минут  \n"
        "**КБЖУ (на порцию):** ~K ккал · ~Б г · ~Ж г · ~У г\n\n"
        "### Ингредиенты\n"
        "- ингредиент — количество\n\n"
        "### Способ приготовления\n"
        "1. Шаг 1\n"
        "2. Шаг 2"
    )


def recipe_user_prompt(
    meal_name: str,
    ingredients: list[dict[str, str]],
    goal: str,
    servings: int,
) -> str:
    ing_lines = "\n".join(
        f"- {it.get('name', '').strip()} — {it.get('amount', '').strip()}"
        for it in ingredients
        if it.get("name", "").strip()
    ) or "- (без ингредиентов)"
    return (
        f"Блюдо: {meal_name}\n"
        f"Цель питания: {goal_description(goal)}\n"
        f"Порций: {servings}\n\n"
        f"Ингредиенты:\n{ing_lines}\n\n"
        "Составь рецепт строго по шаблону из system-промпта."
    )
