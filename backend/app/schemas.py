"""Pydantic request/response schemas for the Noetica roadmap API."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator


class AxisInput(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1, max_length=40)
    symbol: str = Field(min_length=1, max_length=4)


class ProfileInput(BaseModel):
    name: str = ""
    aspiration: str = ""
    pain_point: str = ""
    weekly_hours: int = Field(default=5, ge=0, le=168)


class RoadmapRequest(BaseModel):
    goal: str = Field(min_length=3, max_length=500)
    profile: ProfileInput = ProfileInput()
    axes: list[AxisInput]
    horizon_days: int = Field(default=30, ge=1, le=365)
    task_count: int = Field(default=6, ge=1, le=12)

    @field_validator("axes")
    @classmethod
    def _validate_axes(cls, value: list[AxisInput]) -> list[AxisInput]:
        if len(value) < 3:
            raise ValueError("At least 3 axes are required.")
        if len(value) > 8:
            raise ValueError("No more than 8 axes supported.")
        return value


class RoadmapTask(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = ""
    axis_ids: list[str] = Field(default_factory=list)
    xp: int = Field(ge=5, le=100)
    due_in_days: int | None = Field(default=None, ge=0, le=365)


class RoadmapResponse(BaseModel):
    model: str
    tasks: list[RoadmapTask]
    summary: str = ""


class ErrorResponse(BaseModel):
    detail: str
    kind: Literal["upstream_error", "validation_error", "config_error"] = (
        "upstream_error"
    )
