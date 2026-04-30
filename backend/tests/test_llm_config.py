"""Unit tests for the LLM client config resolution.

Covers GROQ_API_KEY resolution and optional LLM_BASE_URL/LLM_MODEL
overrides.
"""

from __future__ import annotations

import pytest

from app.llm import (
    GROQ_BASE_URL,
    GROQ_MODEL,
    LlmClient,
    LlmConfigError,
)


def _clear_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for k in [
        "GROQ_API_KEY",
        "LLM_BASE_URL",
        "LLM_MODEL",
    ]:
        monkeypatch.delenv(k, raising=False)


def test_groq_key_makes_groq_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test123")
    c = LlmClient()
    assert c.api_key == "gsk_test123"
    assert c.base_url == GROQ_BASE_URL
    assert c.model == GROQ_MODEL


def test_llm_base_url_override_wins(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test123")
    monkeypatch.setenv("LLM_BASE_URL", "https://example.com/v1")
    monkeypatch.setenv("LLM_MODEL", "custom-model")
    c = LlmClient()
    assert c.base_url == "https://example.com/v1"
    assert c.model == "custom-model"


def test_missing_key_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    with pytest.raises(LlmConfigError):
        LlmClient()
