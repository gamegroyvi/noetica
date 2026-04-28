"""SQLite-backed persistence for users, profiles, axes and entries.

Single file, mounted from a Fly.io volume at `/data/noetica.db` (override via
`NOETICA_DB_PATH`). The schema mirrors the on-device Flutter SQLite schema so
sync can map 1:1, but every table carries a `user_id` (FK to `users`) and an
`updated_at` / `deleted_at` pair to make Last-Writer-Wins sync trivial.
"""

from __future__ import annotations

import os
from contextlib import asynccontextmanager
from typing import AsyncIterator

import aiosqlite

DEFAULT_DB_PATH = os.getenv("NOETICA_DB_PATH", "/data/noetica.db")


_SCHEMA_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        google_sub TEXT UNIQUE NOT NULL,
        email TEXT NOT NULL,
        name TEXT,
        picture_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_users_google_sub ON users(google_sub)",
    """
    CREATE TABLE IF NOT EXISTS profiles (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        data_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS personal_knowledge (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        data_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS axes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        position INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_axes_user ON axes(user_id, updated_at)",
    """
    CREATE TABLE IF NOT EXISTS entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        due_at INTEGER,
        completed_at INTEGER,
        xp INTEGER NOT NULL DEFAULT 10,
        deleted_at INTEGER,
        tags TEXT NOT NULL DEFAULT '',
        bookmarked INTEGER NOT NULL DEFAULT 0
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_entries_user ON entries(user_id, updated_at)",
    """
    CREATE TABLE IF NOT EXISTS entry_axes (
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        axis_id TEXT NOT NULL REFERENCES axes(id) ON DELETE CASCADE,
        PRIMARY KEY (entry_id, axis_id)
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_entry_axes_entry ON entry_axes(entry_id)",
    "CREATE INDEX IF NOT EXISTS idx_entry_axes_axis ON entry_axes(axis_id)",
    """
    CREATE TABLE IF NOT EXISTS entry_links (
        source_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        target_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (source_id, target_id)
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_entry_links_source ON entry_links(source_id)",
    "CREATE INDEX IF NOT EXISTS idx_entry_links_target ON entry_links(target_id)",
]


# Idempotent ALTER TABLE migrations for already-existing databases.
# `CREATE TABLE IF NOT EXISTS` above is a no-op if the table already exists,
# so newly-added columns must be ALTERed in. SQLite has no
# `ADD COLUMN IF NOT EXISTS`, so we read `PRAGMA table_info` first.
async def _ensure_column(
    db: aiosqlite.Connection,
    table: str,
    column: str,
    coldef: str,
) -> None:
    cursor = await db.execute(f"PRAGMA table_info({table})")
    rows = await cursor.fetchall()
    existing = {row[1] for row in rows}  # row[1] is the column name.
    if column in existing:
        return
    await db.execute(f"ALTER TABLE {table} ADD COLUMN {coldef}")


async def _init_schema(db: aiosqlite.Connection) -> None:
    await db.execute("PRAGMA foreign_keys = ON")
    for stmt in _SCHEMA_STATEMENTS:
        await db.execute(stmt)
    # Migrations for databases created before these columns existed.
    await _ensure_column(
        db, "entries", "tags", "tags TEXT NOT NULL DEFAULT ''"
    )
    await _ensure_column(
        db, "entries", "bookmarked", "bookmarked INTEGER NOT NULL DEFAULT 0"
    )
    await db.commit()


_db_path: str = DEFAULT_DB_PATH


def configure(db_path: str) -> None:
    """Override the database path (used by tests + lifespan startup)."""
    global _db_path
    _db_path = db_path


async def init() -> None:
    """Ensure the schema exists. Idempotent."""
    os.makedirs(os.path.dirname(_db_path) or ".", exist_ok=True)
    async with aiosqlite.connect(_db_path) as db:
        await _init_schema(db)


@asynccontextmanager
async def connect() -> AsyncIterator[aiosqlite.Connection]:
    """Open a fresh connection per request; SQLite is fast enough for our load."""
    async with aiosqlite.connect(_db_path) as db:
        await db.execute("PRAGMA foreign_keys = ON")
        db.row_factory = aiosqlite.Row
        yield db
