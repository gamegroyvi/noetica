"""End-to-end sync tests against the FastAPI app with a temp SQLite."""

from __future__ import annotations


def _push_sample(client, headers) -> dict:
    body = {
        "axes": [
            {
                "id": "axis-1",
                "name": "Body",
                "symbol": "◐",
                "position": 0,
                "created_at": 1_000,
                "updated_at": 1_000,
            },
            {
                "id": "axis-2",
                "name": "Mind",
                "symbol": "◇",
                "position": 1,
                "created_at": 1_000,
                "updated_at": 1_000,
            },
        ],
        "entries": [
            {
                "id": "entry-1",
                "title": "Run 5km",
                "body": "",
                "kind": "task",
                "created_at": 1_500,
                "updated_at": 1_500,
                "due_at": 2_000,
                "xp": 20,
                "axis_ids": ["axis-1"],
            }
        ],
        "profile": {
            "data_json": '{"name":"Alice"}',
            "updated_at": 2_500,
        },
    }
    response = client.post("/sync/push", json=body, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_push_then_pull_round_trip(app_with_db, auth_headers) -> None:
    push_result = _push_sample(app_with_db, auth_headers)
    assert push_result["accepted_axes"] == 2
    assert push_result["accepted_entries"] == 1
    assert push_result["accepted_profile"] is True

    pull_response = app_with_db.post(
        "/sync/pull", json={"since_ms": 0}, headers=auth_headers
    )
    assert pull_response.status_code == 200
    body = pull_response.json()
    assert len(body["axes"]) == 2
    assert len(body["entries"]) == 1
    assert body["entries"][0]["axis_ids"] == ["axis-1"]
    assert body["profile"]["data_json"] == '{"name":"Alice"}'


def test_push_lww_older_rejected(app_with_db, auth_headers) -> None:
    _push_sample(app_with_db, auth_headers)
    older = {
        "axes": [
            {
                "id": "axis-1",
                "name": "Body OLD",
                "symbol": "X",
                "position": 0,
                "created_at": 500,
                "updated_at": 500,
            }
        ]
    }
    response = app_with_db.post("/sync/push", json=older, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["accepted_axes"] == 0

    pull = app_with_db.post(
        "/sync/pull", json={"since_ms": 0}, headers=auth_headers
    ).json()
    body_axis = next(a for a in pull["axes"] if a["id"] == "axis-1")
    assert body_axis["name"] == "Body"


def test_push_lww_newer_accepted(app_with_db, auth_headers) -> None:
    _push_sample(app_with_db, auth_headers)
    newer = {
        "axes": [
            {
                "id": "axis-1",
                "name": "Body v2",
                "symbol": "Y",
                "position": 0,
                "created_at": 1_000,
                "updated_at": 5_000,
            }
        ]
    }
    response = app_with_db.post("/sync/push", json=newer, headers=auth_headers)
    assert response.json()["accepted_axes"] == 1

    pull = app_with_db.post(
        "/sync/pull", json={"since_ms": 0}, headers=auth_headers
    ).json()
    body_axis = next(a for a in pull["axes"] if a["id"] == "axis-1")
    assert body_axis["name"] == "Body v2"


def test_pull_since_filters(app_with_db, auth_headers) -> None:
    _push_sample(app_with_db, auth_headers)
    pull = app_with_db.post(
        "/sync/pull", json={"since_ms": 1_400}, headers=auth_headers
    ).json()
    # axes have updated_at=1000 → filtered out; entry updated_at=1500 → in.
    assert len(pull["axes"]) == 0
    assert len(pull["entries"]) == 1
    assert pull["profile"] is not None  # profile updated_at=2500


def test_user_isolation(app_with_db) -> None:
    # User A pushes
    r_a = app_with_db.post(
        "/auth/google", json={"id_token": "fake:user-a:a@example.com"}
    ).json()
    headers_a = {"Authorization": f"Bearer {r_a['access_token']}"}
    _push_sample(app_with_db, headers_a)

    # User B should see nothing
    r_b = app_with_db.post(
        "/auth/google", json={"id_token": "fake:user-b:b@example.com"}
    ).json()
    headers_b = {"Authorization": f"Bearer {r_b['access_token']}"}
    pull_b = app_with_db.post(
        "/sync/pull", json={"since_ms": 0}, headers=headers_b
    ).json()
    assert pull_b["axes"] == []
    assert pull_b["entries"] == []
    assert pull_b["profile"] is None


def test_entry_axis_ids_filtered_to_user_owned(app_with_db, auth_headers) -> None:
    body = {
        "entries": [
            {
                "id": "entry-x",
                "title": "Bad refs",
                "kind": "note",
                "created_at": 1_000,
                "updated_at": 1_000,
                "xp": 10,
                "axis_ids": ["unknown-axis-id"],  # doesn't exist for this user
            }
        ]
    }
    r = app_with_db.post("/sync/push", json=body, headers=auth_headers)
    assert r.status_code == 200, r.text
    pull = app_with_db.post(
        "/sync/pull", json={"since_ms": 0}, headers=auth_headers
    ).json()
    e = next(e for e in pull["entries"] if e["id"] == "entry-x")
    assert e["axis_ids"] == []
