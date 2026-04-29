"""Test fixtures: spin up a temp SQLite + override auth so we don't need
network access to real Google certs."""

from __future__ import annotations

import os
import tempfile
from typing import Iterator

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def app_with_db(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    db_path = tmp.name
    monkeypatch.setenv("NOETICA_DB_PATH", db_path)
    monkeypatch.setenv("JWT_SECRET", "test-secret-not-real")
    monkeypatch.setenv("GOOGLE_OAUTH_WEB_CLIENT_ID", "fake-web-client-id")
    monkeypatch.setenv("GOOGLE_AI_KEY", "AIzaSyFake")
    # Avoid CORS warnings noise in test logs.
    monkeypatch.setenv("LOG_LEVEL", "WARNING")

    from app import auth, db, main

    db.configure(db_path)

    def _fake_verify(token: str) -> dict:
        # token format in tests: "fake:<sub>:<email>"
        parts = token.split(":", 2)
        if parts[0] != "fake":
            raise ValueError("test token must start with 'fake:'")
        return {
            "sub": parts[1],
            "email": parts[2] if len(parts) > 2 else "",
            "name": "Test User",
            "picture": "",
            "iss": "https://accounts.google.com",
        }

    monkeypatch.setattr(auth, "verify_google_id_token", _fake_verify)
    monkeypatch.setattr(main, "verify_google_id_token", _fake_verify)

    with TestClient(main.app) as client:
        yield client

    try:
        os.unlink(db_path)
    except OSError:
        pass


@pytest.fixture
def auth_token(app_with_db: TestClient) -> str:
    response = app_with_db.post(
        "/auth/google",
        json={"id_token": "fake:user-1:test@example.com"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


@pytest.fixture
def auth_headers(auth_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth_token}"}
