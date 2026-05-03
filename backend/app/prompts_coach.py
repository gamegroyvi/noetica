"""Prompts for the AI Coach — morning plan & evening reflection."""

from __future__ import annotations


def morning_system_prompt() -> str:
    return (
        "Ты — AI-коуч пользователя в приложении Noetica для саморазвития. "
        "Пользователь начинает день и хочет получить короткий план. "
        "Говори коротко, по делу, дружелюбно. Обращайся на «ты». "
        "Используй эмодзи умеренно. Формат ответа — JSON:\n"
        '{"greeting":"...","focus":"одна главная цель дня",'
        '"tasks":["задача 1","задача 2","задача 3"],'
        '"motivation":"одно короткое мотивирующее предложение"}'
    )


def morning_user_prompt(
    *,
    name: str,
    aspiration: str,
    axes: list[str],
    active_tasks: list[str],
    streak: int,
) -> str:
    lines = [f"Имя: {name}" if name else "Имя неизвестно"]
    if aspiration:
        lines.append(f"Главная цель: {aspiration}")
    if axes:
        lines.append(f"Оси развития: {', '.join(axes[:5])}")
    if active_tasks:
        lines.append("Активные задачи:")
        for t in active_tasks[:8]:
            lines.append(f"  - {t}")
    lines.append(f"Текущий стрик: {streak} дней")
    lines.append(
        "\nСоставь план на сегодня (3–5 конкретных задач). "
        "Учти активные задачи и цель."
    )
    return "\n".join(lines)


def evening_system_prompt() -> str:
    return (
        "Ты — AI-коуч пользователя в приложении Noetica для саморазвития. "
        "Вечер: пользователь подводит итоги дня. "
        "Дай короткую обратную связь. Обращайся на «ты». "
        "Используй эмодзи умеренно. Формат ответа — JSON:\n"
        '{"summary":"итог дня в 1–2 предложения",'
        '"wins":["что получилось 1","что получилось 2"],'
        '"improvements":["что улучшить 1"],'
        '"encouragement":"подбадривающая фраза на завтра"}'
    )


def evening_user_prompt(
    *,
    name: str,
    completed_today: list[str],
    remaining: list[str],
    entries_today: int,
    streak: int,
) -> str:
    lines = [f"Имя: {name}" if name else "Имя неизвестно"]
    if completed_today:
        lines.append("Выполнено сегодня:")
        for t in completed_today[:10]:
            lines.append(f"  ✓ {t}")
    else:
        lines.append("Сегодня ничего не завершено.")
    if remaining:
        lines.append("Не завершено:")
        for t in remaining[:5]:
            lines.append(f"  - {t}")
    lines.append(f"Записей за сегодня: {entries_today}")
    lines.append(f"Текущий стрик: {streak} дней")
    lines.append("\nПодведи итоги дня.")
    return "\n".join(lines)
