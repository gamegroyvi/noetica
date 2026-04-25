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
    # Self-assessed level per interest. Keys are interest strings (matching
    # `AxesRequest.interests`); values are one of "novice"/"learning"/
    # "confident"/"expert". The LLM uses this to calibrate task difficulty
    # so a senior dev doesn't get "install Flutter" tasks.
    interest_levels: dict[str, str] = Field(default_factory=dict)


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
    # Optional ordered checklist of concrete sub-steps the LLM may include
    # when a task warrants more guidance than a single sentence (e.g.
    # "Read State Management chapter" → ["watch lecture", "do exercise",
    # "build mini-app"]). The Flutter UI may render these as bullet
    # checkboxes inside the task body.
    steps: list[str] = Field(default_factory=list)
    axis_ids: list[str] = Field(default_factory=list)
    xp: int = Field(ge=5, le=100)
    due_in_days: int | None = Field(default=None, ge=0, le=365)


class RoadmapResponse(BaseModel):
    model: str
    tasks: list[RoadmapTask]
    summary: str = ""


class AxesRequest(BaseModel):
    profile: ProfileInput = ProfileInput()
    interests: list[str] = Field(default_factory=list)
    count: int = Field(default=5, ge=3, le=8)

    @field_validator("interests")
    @classmethod
    def _trim_interests(cls, value: list[str]) -> list[str]:
        return [s.strip() for s in value if isinstance(s, str) and s.strip()][:12]


class AxisDraft(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    symbol: str = Field(min_length=1, max_length=4)
    description: str = Field(default="", max_length=200)


class AxesResponse(BaseModel):
    model: str
    axes: list[AxisDraft]


class ErrorResponse(BaseModel):
    detail: str
    kind: Literal["upstream_error", "validation_error", "config_error"] = (
        "upstream_error"
    )
