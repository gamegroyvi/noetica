"""Smoke tests for /tools/habits/generate.

Mirrors `test_menu.py` — we don't hit the real Groq API, we
monkey-patch `LlmClient.generate_habits_plan` to return canned
responses, then verify FastAPI plumbing (auth, validation, response
shape) and the JSON normaliser at the boundary.
"""

from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app import llm
from app.llm import LlmClient
from app.schemas import HabitsPlan


def _fake_plan_json(days: int = 7) -> dict[str, Any]:
    """Build a canned LLM response with `days` micro-actions."""
    return {
        "summary": "Семь дней — от первого жеста до закрепления.",
        "days": [
            {
                "day_index": i + 1,
                "title": f"Действие {i + 1}: налить стакан воды",
                "why": "Маленький якорь, который запускает остальное утро.",
            }
            for i in range(days)
        ],
    }


def test_habits_generate_requires_auth(app_with_db: TestClient) -> None:
    r = app_with_db.post(
        "/tools/habits/generate",
        json={"intent": "Хочу засыпать раньше"},
    )
    assert r.status_code in (401, 403)


def test_habits_generate_validates_intent(
    app_with_db: TestClient, auth_headers: dict[str, str]
) -> None:
    r = app_with_db.post(
        "/tools/habits/generate",
        headers=auth_headers,
        json={"intent": "x"},  # below min_length
    )
    assert r.status_code == 422


def test_habits_generate_validates_duration(
    app_with_db: TestClient, auth_headers: dict[str, str]
) -> None:
    r = app_with_db.post(
        "/tools/habits/generate",
        headers=auth_headers,
        json={"intent": "Хочу засыпать раньше", "duration_days": 100},
    )
    assert r.status_code == 422


def test_habits_generate_returns_plan(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def _fake(self: LlmClient, **kwargs: Any) -> HabitsPlan:
        # Route should pass form fields through unchanged.
        assert kwargs["intent"] == "Хочу засыпать раньше"
        assert kwargs["duration_days"] == 7
        assert kwargs["axis_hint"] == "сон"
        return llm._normalize_habits_plan(  # noqa: SLF001
            _fake_plan_json(7),
            model=self.model,
            intent=kwargs["intent"],
            duration_days=kwargs["duration_days"],
        )

    monkeypatch.setattr(LlmClient, "generate_habits_plan", _fake)

    r = app_with_db.post(
        "/tools/habits/generate",
        headers=auth_headers,
        json={
            "intent": "Хочу засыпать раньше",
            "duration_days": 7,
            "axis_hint": "сон",
            "notes": "ложусь в 1:30, хочу к 23:30",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["intent"] == "Хочу засыпать раньше"
    assert len(body["days"]) == 7
    assert body["days"][0]["day_index"] == 1
    assert body["days"][6]["day_index"] == 7
    assert body["days"][0]["title"]
    assert body["model"]


def test_habits_generate_502_on_short_plan(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """If the LLM returns fewer days than requested, route 502s."""
    async def _short(self: LlmClient, **kwargs: Any) -> HabitsPlan:
        return llm._normalize_habits_plan(  # noqa: SLF001
            _fake_plan_json(3),
            model=self.model,
            intent=kwargs["intent"],
            duration_days=kwargs["duration_days"],
        )

    monkeypatch.setattr(LlmClient, "generate_habits_plan", _short)

    r = app_with_db.post(
        "/tools/habits/generate",
        headers=auth_headers,
        json={"intent": "Хочу засыпать раньше", "duration_days": 7},
    )
    assert r.status_code == 502


def test_normalize_drops_malformed_entries() -> None:
    """Entries without title (or non-dicts) are silently dropped."""
    raw = {
        "summary": "...",
        "days": [
            {"day_index": 1, "title": "ok", "why": "ok"},
            {"day_index": 2, "title": "", "why": "missing title"},
            "not-a-dict",
            {"day_index": 4, "title": "kept", "why": ""},
        ],
    }
    plan = llm._normalize_habits_plan(  # noqa: SLF001
        raw, model="m", intent="i", duration_days=4,
    )
    assert [d.title for d in plan.days] == ["ok", "kept"]
    # Re-numbering: indices are linear 1..N, not the raw values.
    assert [d.day_index for d in plan.days] == [1, 2]


def test_normalize_trims_overshoot() -> None:
    """If the LLM returns more days than requested, we trim."""
    raw = _fake_plan_json(10)
    plan = llm._normalize_habits_plan(  # noqa: SLF001
        raw, model="m", intent="i", duration_days=5,
    )
    assert len(plan.days) == 5
    assert plan.days[-1].day_index == 5
