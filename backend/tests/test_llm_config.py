"""Unit tests for the LLM client config resolution.

Covers the order in which API keys are selected and ensures the
DeepSeek-auto-defaults path kicks in when only DEEPSEEK_API_KEY is
present.
"""

from __future__ import annotations

import pytest

from app.llm import (
    DEEPSEEK_BASE_URL,
    DEEPSEEK_MODEL,
    DEFAULT_BASE_URL,
    DEFAULT_MODEL,
    LlmClient,
    LlmConfigError,
)


def _clear_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for k in [
        "DEEPSEEK_API_KEY",
        "OPENAI_API_KEY",
        "OPENROUTER_API_KEY",
        "LLM_API_KEY",
        "LLM_BASE_URL",
        "LLM_MODEL",
    ]:
        monkeypatch.delenv(k, raising=False)


def test_deepseek_key_makes_deepseek_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("DEEPSEEK_API_KEY", "sk-deepseek-test")
    c = LlmClient()
    assert c.api_key == "sk-deepseek-test"
    assert c.base_url == DEEPSEEK_BASE_URL
    assert c.model == DEEPSEEK_MODEL


def test_openai_fallback_when_no_deepseek(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("OPENAI_API_KEY", "sk-openai-test")
    c = LlmClient()
    assert c.api_key == "sk-openai-test"
    assert c.base_url == DEFAULT_BASE_URL
    assert c.model == DEFAULT_MODEL


def test_llm_base_url_override_wins(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    monkeypatch.setenv("DEEPSEEK_API_KEY", "sk-deepseek-test")
    monkeypatch.setenv("LLM_BASE_URL", "https://example.com/v1")
    monkeypatch.setenv("LLM_MODEL", "custom-model")
    c = LlmClient()
    assert c.base_url == "https://example.com/v1"
    assert c.model == "custom-model"


def test_missing_key_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    _clear_env(monkeypatch)
    with pytest.raises(LlmConfigError):
        LlmClient()
