"""Smoke tests for /tools/menu endpoints.

We don't hit the real Groq API — we monkey-patch the LLM client's
`generate_menu_plan` / `generate_meal_recipe` methods to return canned
responses, then verify FastAPI plumbing (auth, validation, response
shape) and the JSON normaliser at the boundary.
"""

from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app import llm
from app.schemas import MenuPlan
from app.llm import LlmClient


_FAKE_PLAN_JSON: dict[str, Any] = {
    "days": [
        {
            "day_name": "Понедельник",
            "breakfast": {
                "name": "Овсянка с ягодами",
                "ingredients": [
                    {"name": "Овсяные хлопья", "amount": "60 г"},
                    {"name": "Молоко", "amount": "200 мл"},
                    {"name": "Голубика", "amount": "50 г"},
                ],
                "calories": 380,
                "protein": 14,
                "fat": 8,
                "carbs": 60,
            },
            "lunch": {
                "name": "Куриная грудка с гречкой",
                "ingredients": [
                    {"name": "Куриная грудка", "amount": "150 г"},
                    {"name": "Гречка", "amount": "80 г"},
                ],
                "calories": 520,
                "protein": 45,
                "fat": 9,
                "carbs": 50,
            },
            "dinner": {
                "name": "Запечённая рыба с овощами",
                "ingredients": [
                    {"name": "Треска", "amount": "180 г"},
                    {"name": "Кабачок", "amount": "200 г"},
                ],
                "calories": 410,
                "protein": 38,
                "fat": 12,
                "carbs": 30,
            },
            "snack": None,
        },
    ],
    "daily_avg_calories": 1310,
    "notes": "Меню балансное, сезонное",
    "shopping_list": {
        "Мясо и рыба": [
            {"name": "Куриная грудка", "amount": "1 кг"},
            {"name": "Треска", "amount": "0.7 кг"},
        ],
        "Крупы": [{"name": "Гречка", "amount": "300 г"}],
    },
}


def test_menu_generate_requires_auth(app_with_db: TestClient) -> None:
    r = app_with_db.post(
        "/tools/menu/generate",
        json={"goal": "classic", "servings": 2},
    )
    assert r.status_code in (401, 403)


def test_menu_generate_validates_goal(
    app_with_db: TestClient, auth_headers: dict[str, str]
) -> None:
    r = app_with_db.post(
        "/tools/menu/generate",
        headers=auth_headers,
        json={"goal": "make_me_fly", "servings": 2},
    )
    assert r.status_code == 422


def test_menu_generate_returns_plan(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def _fake_generate(self: LlmClient, **kwargs: Any) -> MenuPlan:
        # The route should pass through the request fields unchanged.
        assert kwargs["goal"] == "muscle"
        assert kwargs["servings"] == 3
        return llm._normalize_menu_plan(_FAKE_PLAN_JSON, model=self.model)

    monkeypatch.setattr(LlmClient, "generate_menu_plan", _fake_generate)

    r = app_with_db.post(
        "/tools/menu/generate",
        headers=auth_headers,
        json={
            "goal": "muscle",
            "servings": 3,
            "restrictions": "без свинины",
            "extra_notes": "Люблю острое",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["days"][0]["day_name"] == "Понедельник"
    assert body["days"][0]["breakfast"]["calories"] == 380
    # `snack: null` must round-trip as `None`/null
    assert body["days"][0]["snack"] is None
    assert "Мясо и рыба" in body["shopping_list"]
    assert body["daily_avg_calories"] == 1310
    assert body["model"]


def test_menu_generate_502_on_empty_plan(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def _empty(self: LlmClient, **kwargs: Any) -> MenuPlan:
        return MenuPlan(model=self.model, days=[])

    monkeypatch.setattr(LlmClient, "generate_menu_plan", _empty)

    r = app_with_db.post(
        "/tools/menu/generate",
        headers=auth_headers,
        json={"goal": "classic", "servings": 2},
    )
    assert r.status_code == 502


def test_menu_recipe_returns_markdown(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def _fake_recipe(self: LlmClient, **kwargs: Any) -> str:
        assert kwargs["meal_name"] == "Овсянка с ягодами"
        return (
            "## Овсянка с ягодами\n\n"
            "**Сложность:** Легко\n\n"
            "### Способ приготовления\n1. Залить кипятком."
        )

    monkeypatch.setattr(LlmClient, "generate_meal_recipe", _fake_recipe)

    r = app_with_db.post(
        "/tools/menu/recipe",
        headers=auth_headers,
        json={
            "meal_name": "Овсянка с ягодами",
            "ingredients": [{"name": "Овсянка", "amount": "60 г"}],
            "goal": "health",
            "servings": 2,
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["markdown"].startswith("## Овсянка")
    assert "Способ приготовления" in body["markdown"]
    assert body["model"]


@pytest.mark.asyncio
async def test_recipe_strips_code_fence_without_corrupting_content(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Regression: code-fence stripper must not chew up real letters.

    Earlier draft used `lstrip("markdown\\n")`, which treats the argument
    as a character set, so a recipe that legitimately starts with
    "marinated" would have been silently mangled into "inated". We must
    strip the literal prefix instead.
    """
    monkeypatch.setenv("GROQ_API_KEY", "gsk_fake")

    fence_wrapped = (
        "```markdown\n"
        "## Маринованная курица\n\n"
        "marinated chicken with herbs"
        "\n```"
    )

    class _FakeResponse:
        status_code = 200
        text = ""

        def json(self) -> dict[str, Any]:
            return {
                "choices": [
                    {"message": {"content": fence_wrapped}, "finish_reason": "stop"}
                ]
            }

    class _FakeAsyncClient:
        def __init__(self, *_args: Any, **_kwargs: Any) -> None:
            pass

        async def __aenter__(self) -> "_FakeAsyncClient":
            return self

        async def __aexit__(self, *exc_info: Any) -> None:
            return None

        async def post(self, *_args: Any, **_kwargs: Any) -> _FakeResponse:
            return _FakeResponse()

    monkeypatch.setattr(llm.httpx, "AsyncClient", _FakeAsyncClient)

    client = LlmClient()
    md = await client.generate_meal_recipe(
        meal_name="Маринованная курица",
        ingredients=[{"name": "Курица", "amount": "500 г"}],
        goal="muscle",
        servings=2,
    )

    # Fence and language tag stripped, but every legitimate character
    # preserved — no lstrip-as-character-set damage.
    assert not md.startswith("```")
    assert "marinated chicken with herbs" in md
    assert md.startswith("## Маринованная курица")


def test_normalize_menu_plan_handles_dirty_input() -> None:
    """Bot-side hardening: stringy macros, null meals, missing fields."""
    raw = {
        "days": [
            {
                "day_name": "Вторник",
                "breakfast": {
                    "name": "Тост",
                    "calories": "300",
                    "protein": "12.4",
                    "fat": None,
                    "ingredients": [{"name": "Хлеб", "amount": "60 г"}],
                },
                "lunch": {},  # empty dict → None
                "dinner": None,
            }
        ],
        "daily_avg_calories": "abc",
        "shopping_list": {"Овощи": [{"name": "Помидор", "amount": "200 г"}]},
    }
    plan = llm._normalize_menu_plan(raw, model="m")
    assert len(plan.days) == 1
    day = plan.days[0]
    assert day.breakfast and day.breakfast.calories == 300
    assert day.breakfast.protein == 12  # floors stringy float
    assert day.breakfast.fat == 0  # null → 0
    assert day.lunch is None  # empty dict drops
    assert day.dinner is None
    assert plan.daily_avg_calories == 0  # invalid → 0


def test_normalize_menu_plan_handles_stringy_avg_calories() -> None:
    """LLM may return `"1500.5"` as a string; we coerce via float→int."""
    raw = {
        "days": [
            {"day_name": "Среда", "breakfast": {"name": "Йогурт"}},
        ],
        "daily_avg_calories": "1500.5",
    }
    plan = llm._normalize_menu_plan(raw, model="m")
    assert plan.daily_avg_calories == 1500
