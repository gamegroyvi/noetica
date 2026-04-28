"""Regression tests for backend SQLite schema migrations.

Ensures that already-existing prod databases (created before the
PR #16 schema bump) get the new `tags` and `bookmarked` columns
added on next startup, instead of crashing sync queries with
`OperationalError: no such column: tags`.
"""

from __future__ import annotations

import os
import tempfile

import aiosqlite
import pytest


@pytest.mark.asyncio
async def test_init_schema_adds_missing_columns_to_existing_entries_table() -> None:
    """A pre-PR-16 entries table missing `tags`/`bookmarked` must be
    upgraded in place by `_init_schema`, not silently left alone."""
    from app import db as db_module

    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    legacy_path = tmp.name
    try:
        # Create the legacy schema (entries WITHOUT tags / bookmarked).
        async with aiosqlite.connect(legacy_path) as legacy:
            await legacy.execute(
                """
                CREATE TABLE users (
                    id TEXT PRIMARY KEY,
                    google_sub TEXT UNIQUE NOT NULL,
                    email TEXT NOT NULL,
                    name TEXT,
                    picture_url TEXT,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL
                )
                """
            )
            await legacy.execute(
                """
                CREATE TABLE entries (
                    id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL DEFAULT '',
                    kind TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    due_at INTEGER,
                    completed_at INTEGER,
                    xp INTEGER NOT NULL DEFAULT 10,
                    deleted_at INTEGER
                )
                """
            )
            await legacy.commit()

        # Now run the production initializer and verify both columns
        # are present afterwards.
        async with aiosqlite.connect(legacy_path) as upgraded:
            await db_module._init_schema(upgraded)
            cursor = await upgraded.execute("PRAGMA table_info(entries)")
            cols = {row[1]: row for row in await cursor.fetchall()}

        assert "tags" in cols, (
            "Expected `_init_schema` to ALTER an existing entries table "
            "and add the `tags` column. Without this migration the "
            "backend would crash on every sync query referencing tags."
        )
        assert "bookmarked" in cols, (
            "Expected `_init_schema` to ALTER an existing entries table "
            "and add the `bookmarked` column."
        )

        # Re-running the initializer must be idempotent.
        async with aiosqlite.connect(legacy_path) as repeat:
            await db_module._init_schema(repeat)
            cursor = await repeat.execute("PRAGMA table_info(entries)")
            cols2 = {row[1]: row for row in await cursor.fetchall()}
        assert "tags" in cols2 and "bookmarked" in cols2

    finally:
        try:
            os.unlink(legacy_path)
        except OSError:
            pass
