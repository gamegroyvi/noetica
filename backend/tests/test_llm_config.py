"""Unit tests for the LLM client config resolution.

Covers GOOGLE_AI_KEY resolution and optional LLM_BASE_URL/LLM_MODEL
overrides.
"""

from __future__ import annotations

import pytest

from app.llm import (
    GEMINI_BASE_URL,
    GEMINI_MODEL,
    LlmClient,
    LlmConfigError,
)


def _clear_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for k in [
        "GOOGLE_AI_KEY",
        "LLM_BASE_URL",
        "LLM_MODEL",
    ]:
        monkeypatch.delenv(k, raising=False)


def test_google_ai_key_makes_gemini_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("GOOGLE_AI_KEY", "AIzaSyTest123")
    c = LlmClient()
    assert c.api_key == "AIzaSyTest123"
    assert c.base_url == GEMINI_BASE_URL
    assert c.model == GEMINI_MODEL


def test_llm_base_url_override_wins(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("GOOGLE_AI_KEY", "AIzaSyTest123")
    monkeypatch.setenv("LLM_BASE_URL", "https://example.com/v1")
    monkeypatch.setenv("LLM_MODEL", "custom-model")
    c = LlmClient()
    assert c.base_url == "https://example.com/v1"
    assert c.model == "custom-model"


def test_missing_key_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    with pytest.raises(LlmConfigError):
        LlmClient()
