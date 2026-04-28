"""Smoke tests for the auth flow."""

from __future__ import annotations


def test_auth_google_creates_user(app_with_db) -> None:
    response = app_with_db.post(
        "/auth/google",
        json={"id_token": "fake:abc-sub:foo@example.com"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["token_type"] == "Bearer"
    assert body["access_token"]
    assert body["user"]["email"] == "foo@example.com"
    assert body["user"]["id"]


def test_auth_google_idempotent(app_with_db) -> None:
    r1 = app_with_db.post(
        "/auth/google",
        json={"id_token": "fake:abc-sub:foo@example.com"},
    )
    r2 = app_with_db.post(
        "/auth/google",
        json={"id_token": "fake:abc-sub:foo@example.com"},
    )
    assert r1.status_code == r2.status_code == 200
    assert r1.json()["user"]["id"] == r2.json()["user"]["id"]


def test_me_requires_bearer(app_with_db) -> None:
    assert app_with_db.get("/auth/me").status_code == 401
    assert (
        app_with_db.get("/auth/me", headers={"Authorization": "Bearer junk"}).status_code
        == 401
    )


def test_me_returns_user(app_with_db, auth_headers) -> None:
    response = app_with_db.get("/auth/me", headers=auth_headers)
    assert response.status_code == 200, response.text
    assert response.json()["email"] == "test@example.com"


def test_protected_endpoints_require_auth(app_with_db) -> None:
    # /sync/pull requires auth
    assert (
        app_with_db.post("/sync/pull", json={"since_ms": 0}).status_code == 401
    )
    assert (
        app_with_db.post(
            "/roadmap/generate",
            json={
                "goal": "anything",
                "axes": [
                    {"id": "a", "name": "A", "symbol": "A"},
                    {"id": "b", "name": "B", "symbol": "B"},
                    {"id": "c", "name": "C", "symbol": "C"},
                ],
            },
        ).status_code
        == 401
    )
