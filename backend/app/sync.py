"""Last-Writer-Wins sync between client SQLite and server SQLite.

Two endpoints:
    POST /sync/pull   { since_ms: int }  → all rows updated_at > since_ms
    POST /sync/push   { axes, entries, profile, deletes }  → upserted rows

Conflict resolution: the row with the **larger** `updated_at` wins. Both sides
soft-delete by setting `deleted_at` (and the row is still synced so the peer
can mirror the deletion).

The `entry_axes` join table is treated as part of the entry: each entry payload
carries its full `axis_ids` list, and the server replaces the join rows
atomically when it accepts an incoming entry.
"""

from __future__ import annotations

import json
import time
from typing import Any

from fastapi import APIRouter, HTTPException

from . import db
from .auth import CurrentUser

router = APIRouter(prefix="/sync", tags=["sync"])


# ---------- payload schemas ----------

from pydantic import BaseModel, Field


class PullRequest(BaseModel):
    since_ms: int = Field(default=0, ge=0)


class AxisPayload(BaseModel):
    id: str
    name: str
    symbol: str
    position: int
    created_at: int
    updated_at: int
    deleted_at: int | None = None


class EntryPayload(BaseModel):
    id: str
    title: str
    body: str = ""
    kind: str  # "note" | "task"
    created_at: int
    updated_at: int
    due_at: int | None = None
    completed_at: int | None = None
    xp: int = 10
    axis_ids: list[str] = Field(default_factory=list)
    deleted_at: int | None = None
    tags: str = ""
    bookmarked: int = 0


class ProfilePayload(BaseModel):
    data_json: str
    updated_at: int
    deleted_at: int | None = None


class KnowledgePayload(BaseModel):
    """Personal-knowledge document — same shape as ProfilePayload but stored
    in its own table so the two can be synced independently and so an empty
    profile doesn't fight with a populated knowledge doc on LWW."""

    data_json: str
    updated_at: int
    deleted_at: int | None = None


class PushRequest(BaseModel):
    axes: list[AxisPayload] = Field(default_factory=list)
    entries: list[EntryPayload] = Field(default_factory=list)
    profile: ProfilePayload | None = None
    knowledge: KnowledgePayload | None = None


class PullResponse(BaseModel):
    server_time_ms: int
    axes: list[AxisPayload]
    entries: list[EntryPayload]
    profile: ProfilePayload | None
    knowledge: KnowledgePayload | None = None


class PushResponse(BaseModel):
    server_time_ms: int
    accepted_axes: int
    accepted_entries: int
    accepted_profile: bool
    accepted_knowledge: bool = False


# ---------- helpers ----------


def _now_ms() -> int:
    return int(time.time() * 1000)


async def _load_axes(conn, user_id: str, since_ms: int) -> list[AxisPayload]:
    cur = await conn.execute(
        """
        SELECT id, name, symbol, position, created_at, updated_at, deleted_at
        FROM axes WHERE user_id = ? AND updated_at > ?
        """,
        (user_id, since_ms),
    )
    rows = await cur.fetchall()
    return [
        AxisPayload(
            id=r["id"],
            name=r["name"],
            symbol=r["symbol"],
            position=r["position"],
            created_at=r["created_at"],
            updated_at=r["updated_at"],
            deleted_at=r["deleted_at"],
        )
        for r in rows
    ]


async def _load_entries(
    conn, user_id: str, since_ms: int
) -> list[EntryPayload]:
    cur = await conn.execute(
        """
        SELECT id, title, body, kind, created_at, updated_at, due_at,
               completed_at, xp, deleted_at, tags, bookmarked
        FROM entries WHERE user_id = ? AND updated_at > ?
        """,
        (user_id, since_ms),
    )
    rows = await cur.fetchall()
    if not rows:
        return []
    ids = [r["id"] for r in rows]
    placeholders = ",".join("?" * len(ids))
    cur = await conn.execute(
        f"SELECT entry_id, axis_id FROM entry_axes WHERE entry_id IN ({placeholders})",
        ids,
    )
    join_rows = await cur.fetchall()
    by_entry: dict[str, list[str]] = {eid: [] for eid in ids}
    for jr in join_rows:
        by_entry[jr["entry_id"]].append(jr["axis_id"])
    return [
        EntryPayload(
            id=r["id"],
            title=r["title"],
            body=r["body"],
            kind=r["kind"],
            created_at=r["created_at"],
            updated_at=r["updated_at"],
            due_at=r["due_at"],
            completed_at=r["completed_at"],
            xp=r["xp"],
            axis_ids=by_entry.get(r["id"], []),
            deleted_at=r["deleted_at"],
            tags=r["tags"] or "",
            bookmarked=r["bookmarked"] or 0,
        )
        for r in rows
    ]


async def _load_profile(
    conn, user_id: str, since_ms: int
) -> ProfilePayload | None:
    cur = await conn.execute(
        """
        SELECT data_json, updated_at, deleted_at
        FROM profiles WHERE user_id = ? AND updated_at > ?
        """,
        (user_id, since_ms),
    )
    row = await cur.fetchone()
    if row is None:
        return None
    return ProfilePayload(
        data_json=row["data_json"],
        updated_at=row["updated_at"],
        deleted_at=row["deleted_at"],
    )


async def _accept_axis(conn, user_id: str, axis: AxisPayload) -> bool:
    """LWW upsert. Returns True if accepted."""
    cur = await conn.execute(
        "SELECT updated_at FROM axes WHERE id = ? AND user_id = ?",
        (axis.id, user_id),
    )
    row = await cur.fetchone()
    if row is not None and row["updated_at"] >= axis.updated_at:
        return False
    if row is None:
        await conn.execute(
            """
            INSERT INTO axes (id, user_id, name, symbol, position,
                              created_at, updated_at, deleted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                axis.id,
                user_id,
                axis.name,
                axis.symbol,
                axis.position,
                axis.created_at,
                axis.updated_at,
                axis.deleted_at,
            ),
        )
    else:
        await conn.execute(
            """
            UPDATE axes
            SET name = ?, symbol = ?, position = ?, updated_at = ?,
                deleted_at = ?
            WHERE id = ? AND user_id = ?
            """,
            (
                axis.name,
                axis.symbol,
                axis.position,
                axis.updated_at,
                axis.deleted_at,
                axis.id,
                user_id,
            ),
        )
    return True


async def _accept_entry(
    conn, user_id: str, entry: EntryPayload
) -> bool:
    cur = await conn.execute(
        "SELECT updated_at FROM entries WHERE id = ? AND user_id = ?",
        (entry.id, user_id),
    )
    row = await cur.fetchone()
    if row is not None and row["updated_at"] >= entry.updated_at:
        return False
    if row is None:
        await conn.execute(
            """
            INSERT INTO entries (id, user_id, title, body, kind, created_at,
                                 updated_at, due_at, completed_at, xp,
                                 deleted_at, tags, bookmarked)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry.id,
                user_id,
                entry.title,
                entry.body,
                entry.kind,
                entry.created_at,
                entry.updated_at,
                entry.due_at,
                entry.completed_at,
                entry.xp,
                entry.deleted_at,
                entry.tags,
                entry.bookmarked,
            ),
        )
    else:
        await conn.execute(
            """
            UPDATE entries
            SET title = ?, body = ?, kind = ?, updated_at = ?, due_at = ?,
                completed_at = ?, xp = ?, deleted_at = ?,
                tags = ?, bookmarked = ?
            WHERE id = ? AND user_id = ?
            """,
            (
                entry.title,
                entry.body,
                entry.kind,
                entry.updated_at,
                entry.due_at,
                entry.completed_at,
                entry.xp,
                entry.deleted_at,
                entry.tags,
                entry.bookmarked,
                entry.id,
                user_id,
            ),
        )
    # Replace join rows. Skip axis_ids that don't exist for this user
    # (defensive against client bugs and stale references).
    await conn.execute("DELETE FROM entry_axes WHERE entry_id = ?", (entry.id,))
    if entry.axis_ids and entry.deleted_at is None:
        cur = await conn.execute(
            f"""
            SELECT id FROM axes WHERE user_id = ? AND id IN (
              {",".join("?" * len(entry.axis_ids))}
            )
            """,
            [user_id, *entry.axis_ids],
        )
        valid_ids = {r["id"] for r in await cur.fetchall()}
        for axis_id in entry.axis_ids:
            if axis_id not in valid_ids:
                continue
            await conn.execute(
                "INSERT OR IGNORE INTO entry_axes (entry_id, axis_id) VALUES (?, ?)",
                (entry.id, axis_id),
            )
    return True


async def _load_knowledge(
    conn, user_id: str, since_ms: int
) -> KnowledgePayload | None:
    cur = await conn.execute(
        """
        SELECT data_json, updated_at, deleted_at
        FROM personal_knowledge WHERE user_id = ? AND updated_at > ?
        """,
        (user_id, since_ms),
    )
    row = await cur.fetchone()
    if row is None:
        return None
    return KnowledgePayload(
        data_json=row["data_json"],
        updated_at=row["updated_at"],
        deleted_at=row["deleted_at"],
    )


async def _accept_knowledge(
    conn, user_id: str, knowledge: KnowledgePayload
) -> bool:
    cur = await conn.execute(
        "SELECT updated_at FROM personal_knowledge WHERE user_id = ?",
        (user_id,),
    )
    row = await cur.fetchone()
    if row is not None and row["updated_at"] >= knowledge.updated_at:
        return False
    try:
        json.loads(knowledge.data_json)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail=f"knowledge.data_json is not valid JSON: {exc}",
        ) from exc
    if row is None:
        await conn.execute(
            """
            INSERT INTO personal_knowledge (
                user_id, data_json, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?)
            """,
            (
                user_id,
                knowledge.data_json,
                knowledge.updated_at,
                knowledge.deleted_at,
            ),
        )
    else:
        await conn.execute(
            """
            UPDATE personal_knowledge
            SET data_json = ?, updated_at = ?, deleted_at = ?
            WHERE user_id = ?
            """,
            (
                knowledge.data_json,
                knowledge.updated_at,
                knowledge.deleted_at,
                user_id,
            ),
        )
    return True


async def _accept_profile(
    conn, user_id: str, profile: ProfilePayload
) -> bool:
    cur = await conn.execute(
        "SELECT updated_at FROM profiles WHERE user_id = ?", (user_id,)
    )
    row = await cur.fetchone()
    if row is not None and row["updated_at"] >= profile.updated_at:
        return False
    # Validate JSON shape early so we don't store garbage.
    try:
        json.loads(profile.data_json)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=400, detail=f"profile.data_json is not valid JSON: {exc}"
        ) from exc
    if row is None:
        await conn.execute(
            """
            INSERT INTO profiles (user_id, data_json, updated_at, deleted_at)
            VALUES (?, ?, ?, ?)
            """,
            (user_id, profile.data_json, profile.updated_at, profile.deleted_at),
        )
    else:
        await conn.execute(
            """
            UPDATE profiles SET data_json = ?, updated_at = ?, deleted_at = ?
            WHERE user_id = ?
            """,
            (profile.data_json, profile.updated_at, profile.deleted_at, user_id),
        )
    return True


# ---------- routes ----------


@router.post("/pull", response_model=PullResponse)
async def pull(req: PullRequest, user: CurrentUser) -> PullResponse:
    async with db.connect() as conn:
        axes = await _load_axes(conn, user["id"], req.since_ms)
        entries = await _load_entries(conn, user["id"], req.since_ms)
        profile = await _load_profile(conn, user["id"], req.since_ms)
        knowledge = await _load_knowledge(conn, user["id"], req.since_ms)
    return PullResponse(
        server_time_ms=_now_ms(),
        axes=axes,
        entries=entries,
        profile=profile,
        knowledge=knowledge,
    )


@router.post("/push", response_model=PushResponse)
async def push(req: PushRequest, user: CurrentUser) -> PushResponse:
    accepted_axes = 0
    accepted_entries = 0
    accepted_profile = False
    accepted_knowledge = False
    async with db.connect() as conn:
        await conn.execute("BEGIN")
        try:
            for axis in req.axes:
                if await _accept_axis(conn, user["id"], axis):
                    accepted_axes += 1
            for entry in req.entries:
                if await _accept_entry(conn, user["id"], entry):
                    accepted_entries += 1
            if req.profile is not None:
                accepted_profile = await _accept_profile(
                    conn, user["id"], req.profile
                )
            if req.knowledge is not None:
                accepted_knowledge = await _accept_knowledge(
                    conn, user["id"], req.knowledge
                )
            await conn.commit()
        except Exception:
            await conn.rollback()
            raise
    return PushResponse(
        server_time_ms=_now_ms(),
        accepted_axes=accepted_axes,
        accepted_entries=accepted_entries,
        accepted_profile=accepted_profile,
        accepted_knowledge=accepted_knowledge,
    )


# Avoid circular import warning from FastAPI: re-export Any to silence linters.
_ = Any
