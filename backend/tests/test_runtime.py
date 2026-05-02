"""Tests for /tools/run — the universal manifest runtime.

Same approach as test_habits.py: don't hit Groq, monkey-patch
`LlmClient.run_generator`, exercise FastAPI plumbing + normaliser.
"""

from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app import llm
from app.llm import LlmClient
from app.prompts_runtime import render_template, schema_addendum
from app.schemas import GeneratorRunRequest, GeneratorRunResponse


def _fake_run_json(items: int = 3) -> dict[str, Any]:
    return {
        "summary": "Три действия для бодрого утра.",
        "items": [
            {
                "title": f"Действие {i + 1}",
                "body": f"Что и как сделать ({i + 1}).",
                "due_offset_days": i,
            }
            for i in range(items)
        ],
    }


# ---------- template renderer ----------


def test_render_template_substitutes_known_keys() -> None:
    out = render_template(
        "Сделай {n} вещей для {goal}.",
        {"n": 5, "goal": "уснуть раньше"},
    )
    assert out == "Сделай 5 вещей для уснуть раньше."


def test_render_template_renders_bool_as_human_label() -> None:
    out = render_template("strict={strict}", {"strict": True})
    assert out == "strict=true"
    out = render_template("strict={strict}", {"strict": False})
    assert out == "strict=false"


def test_render_template_strips_braces_in_values() -> None:
    """A user-supplied value can't sneak in a new placeholder."""
    out = render_template(
        "intent: {intent}", {"intent": "{n} шагов"},
    )
    assert "{" not in out and "}" not in out
    assert out == "intent: n шагов"


def test_render_template_raises_on_unknown_key() -> None:
    with pytest.raises(KeyError):
        render_template("{x} {y}", {"x": "1"})


def test_schema_addendum_mentions_max_items() -> None:
    s = schema_addendum(7)
    assert "7" in s
    assert "items" in s


# ---------- /tools/run route ----------


def test_run_requires_auth(app_with_db: TestClient) -> None:
    r = app_with_db.post(
        "/tools/run",
        json={
            "manifest_id": "test",
            "prompt_system": "be helpful",
            "prompt_user": "do stuff",
        },
    )
    assert r.status_code in (401, 403)


def test_run_validates_oversized_prompt(
    app_with_db: TestClient, auth_headers: dict[str, str],
) -> None:
    r = app_with_db.post(
        "/tools/run",
        headers=auth_headers,
        json={
            "manifest_id": "test",
            "prompt_system": "x" * 5000,
            "prompt_user": "do",
        },
    )
    assert r.status_code == 422


def test_run_validates_too_many_inputs(
    app_with_db: TestClient, auth_headers: dict[str, str],
) -> None:
    r = app_with_db.post(
        "/tools/run",
        headers=auth_headers,
        json={
            "manifest_id": "test",
            "prompt_system": "be helpful",
            "prompt_user": "do",
            "inputs": {f"k{i}": "v" for i in range(40)},
        },
    )
    assert r.status_code == 422


def test_run_returns_normalized_items(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, Any] = {}

    async def _fake(
        self: LlmClient, request: GeneratorRunRequest,
    ) -> GeneratorRunResponse:
        captured["manifest_id"] = request.manifest_id
        captured["max_items"] = request.max_items
        return llm._normalize_run_response(  # noqa: SLF001
            _fake_run_json(3),
            model=self.model,
            max_items=request.max_items,
        )

    monkeypatch.setattr(LlmClient, "run_generator", _fake)

    r = app_with_db.post(
        "/tools/run",
        headers=auth_headers,
        json={
            "manifest_id": "morning-ritual",
            "prompt_system": "you are a coach",
            "prompt_user": "intent: {intent}",
            "inputs": {"intent": "хочу проснуться бодро"},
            "max_items": 5,
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["items"]) == 3
    assert body["items"][0]["title"] == "Действие 1"
    assert body["items"][2]["due_offset_days"] == 2
    assert body["model"]
    assert captured["manifest_id"] == "morning-ritual"
    assert captured["max_items"] == 5


def test_run_422_on_unknown_placeholder(
    app_with_db: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Author typo'd a placeholder that isn't in inputs — should 422
    with a precise message, not 500.

    We stub `LlmClient.run_generator` to call the same `render_template`
    path the real method would, so the route's `except ValueError`
    branch is exercised without touching Groq.
    """

    async def _stub(
        self: LlmClient, request: GeneratorRunRequest,
    ) -> GeneratorRunResponse:
        try:
            render_template(
                request.prompt_user, dict(request.inputs),
            )
        except KeyError as exc:
            raise ValueError(
                f"prompt template references unknown input: "
                f"{exc.args[0]!r}",
            ) from exc
        return GeneratorRunResponse(model="m", summary="", items=[])

    monkeypatch.setattr(LlmClient, "run_generator", _stub)

    r = app_with_db.post(
        "/tools/run",
        headers=auth_headers,
        json={
            "manifest_id": "test",
            "prompt_system": "ok",
            "prompt_user": "{intent} {missing_key}",
            "inputs": {"intent": "x"},
        },
    )
    assert r.status_code == 422
    assert "missing_key" in r.json()["detail"]


# ---------- normaliser ----------


def test_normalize_drops_items_without_title() -> None:
    raw = {
        "summary": "...",
        "items": [
            {"title": "ok", "body": "good"},
            {"title": "", "body": "no title"},
            "not-a-dict",
            {"title": " padded ", "body": ""},
        ],
    }
    out = llm._normalize_run_response(  # noqa: SLF001
        raw, model="m", max_items=10,
    )
    titles = [i.title for i in out.items]
    assert titles == ["ok", "padded"]


def test_normalize_trims_to_max_items() -> None:
    raw = _fake_run_json(15)
    out = llm._normalize_run_response(  # noqa: SLF001
        raw, model="m", max_items=5,
    )
    assert len(out.items) == 5


def test_normalize_truncates_oversized_strings() -> None:
    long_title = "a" * 200
    long_body = "b" * 3000
    raw = {
        "summary": "x" * 700,
        "items": [{"title": long_title, "body": long_body}],
    }
    out = llm._normalize_run_response(  # noqa: SLF001
        raw, model="m", max_items=10,
    )
    assert len(out.items[0].title) <= 120
    assert out.items[0].title.endswith("…")
    assert len(out.items[0].body) <= 2000
    assert len(out.summary) <= 500


def test_normalize_502_on_missing_items() -> None:
    raw: dict[str, Any] = {"summary": "..."}
    with pytest.raises(llm.LlmUpstreamError):
        llm._normalize_run_response(  # noqa: SLF001
            raw, model="m", max_items=10,
        )


def test_normalize_drops_invalid_due_offset() -> None:
    raw = {
        "items": [
            {"title": "no offset", "body": ""},
            {"title": "negative", "due_offset_days": -3},
            {"title": "huge", "due_offset_days": 999},
            {"title": "string-num", "due_offset_days": "5"},
            {"title": "garbage", "due_offset_days": "soon"},
            {"title": "valid", "due_offset_days": 7},
        ],
    }
    out = llm._normalize_run_response(  # noqa: SLF001
        raw, model="m", max_items=10,
    )
    by_title = {i.title: i for i in out.items}
    assert by_title["no offset"].due_offset_days is None
    assert by_title["negative"].due_offset_days is None
    assert by_title["huge"].due_offset_days is None
    assert by_title["string-num"].due_offset_days == 5
    assert by_title["garbage"].due_offset_days is None
    assert by_title["valid"].due_offset_days == 7
