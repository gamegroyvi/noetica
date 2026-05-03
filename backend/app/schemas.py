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


class KnowledgeInput(BaseModel):
    """Optional persistent context the LLM should respect.

    Fed from the client's local PersonalKnowledge document — accumulated
    summary of who the user is, their goals, recent reflections on
    completed work, and high-level highlights. Truncated server-side
    before being inlined into the prompt to keep token usage bounded.
    """

    summary: str = ""
    goals: list[str] = Field(default_factory=list)
    constraints: list[str] = Field(default_factory=list)
    recent_reflections: list[str] = Field(default_factory=list)
    completed_highlights: list[str] = Field(default_factory=list)


class RoadmapRequest(BaseModel):
    goal: str = Field(min_length=3, max_length=500)
    profile: ProfileInput = ProfileInput()
    knowledge: KnowledgeInput | None = None
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
    # Optional explicit XP split across the task's axes. Keys are a
    # subset of `axis_ids`; values are non-negative weights. The client
    # normalises them to sum to 1.0 at score time, so absolute scale
    # doesn't matter — only ratios. If empty, the client falls back to
    # an even 1/N split which is the deterministic default the user
    # explicitly asked for ("a 40 XP task split evenly between 2 axes
    # = 20 each").
    axis_weights: dict[str, float] = Field(default_factory=dict)
    xp: int = Field(ge=5, le=100)
    due_in_days: int | None = Field(default=None, ge=0, le=365)


class RoadmapResponse(BaseModel):
    model: str
    tasks: list[RoadmapTask]
    summary: str = ""


class AxesRequest(BaseModel):
    profile: ProfileInput = ProfileInput()
    knowledge: KnowledgeInput | None = None
    interests: list[str] = Field(default_factory=list)
    count: int = Field(default=5, ge=3, le=8)
    # Free-form hint from the user when calling regeneration — appended
    # to the LLM prompt so the new set actually addresses the user's
    # ask instead of converging to the same answer every time. Empty /
    # None means "no preference".
    regen_hint: str | None = Field(default=None, max_length=500)
    # Random integer client-side, included verbatim in the prompt as a
    # variation hash. LLMs reliably produce different outputs when the
    # prompt differs even by a meaningless tail string, so this is what
    # makes "regenerate without a hint" actually feel different on each
    # tap. None means "let the LLM decide deterministically".
    variation_seed: int | None = Field(default=None, ge=0, le=2**31)

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


# ---------- /tools/menu ----------

# Допустимые цели питания. Дублируется в `prompts_menu.GOAL_DESCRIPTIONS`,
# но Pydantic-валидация даёт ранний 422 на уровне FastAPI — без раунд-трипа
# к LLM при опечатках.
MenuGoal = Literal[
    "lose_weight",
    "health",
    "muscle",
    "energy",
    "classic",
]


class MenuIngredient(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    amount: str = Field(default="", max_length=40)


class MenuMeal(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    ingredients: list[MenuIngredient] = Field(default_factory=list)
    calories: int = Field(default=0, ge=0, le=5000)
    protein: int = Field(default=0, ge=0, le=400)
    fat: int = Field(default=0, ge=0, le=400)
    carbs: int = Field(default=0, ge=0, le=800)


class MenuDay(BaseModel):
    day_name: str = Field(min_length=1, max_length=24)
    breakfast: MenuMeal | None = None
    lunch: MenuMeal | None = None
    dinner: MenuMeal | None = None
    snack: MenuMeal | None = None


class MenuRequest(BaseModel):
    goal: MenuGoal = "classic"
    servings: int = Field(default=2, ge=1, le=8)
    restrictions: str = Field(default="", max_length=400)
    extra_notes: str = Field(default="", max_length=600)


class MenuPlan(BaseModel):
    """Stage-1 response: structure only, no recipes.

    `shopping_list` is keyed by category (Мясо и рыба / Молочные / etc.)
    and is sized for the whole week × servings — the client renders it
    as a single «Список покупок» note when the user imports.
    """

    model: str
    days: list[MenuDay]
    daily_avg_calories: int = Field(default=0, ge=0, le=5000)
    notes: str = ""
    shopping_list: dict[str, list[MenuIngredient]] = Field(default_factory=dict)


class MenuRecipeRequest(BaseModel):
    meal_name: str = Field(min_length=1, max_length=120)
    ingredients: list[MenuIngredient] = Field(default_factory=list)
    goal: MenuGoal = "classic"
    servings: int = Field(default=2, ge=1, le=8)


class MenuRecipeResponse(BaseModel):
    """Stage-2 response: a single recipe rendered as markdown.

    We return markdown directly (not JSON) so it slots into Noetica's
    note body without any client-side post-processing.
    """

    model: str
    markdown: str


# ---------- /tools/habits ----------


class HabitsRequest(BaseModel):
    """User-facing form for the «Микро-привычки» 7-day micro-action plan.

    `intent` is the free-form goal ("заснуть раньше", "перестать
    залипать в телефон утром"). The LLM expands it into a sequence of
    tiny daily actions; the client imports them as N due-dated tasks.
    """

    intent: str = Field(min_length=3, max_length=300)
    duration_days: int = Field(default=7, ge=3, le=30)
    axis_hint: str = Field(default="", max_length=40)
    notes: str = Field(default="", max_length=400)


class HabitDay(BaseModel):
    """A single day's micro-action."""

    day_index: int = Field(ge=1, le=30)
    title: str = Field(min_length=1, max_length=80)
    why: str = Field(default="", max_length=240)


class HabitsPlan(BaseModel):
    """Structured result for the habits generator.

    `intent` echoes the user's goal so the client can render it as the
    plan's header without re-storing it. `summary` is a one-line
    framing the LLM uses to explain how the days build on each other —
    optional but useful for the preview screen.
    """

    model: str
    intent: str = Field(default="", max_length=300)
    summary: str = Field(default="", max_length=400)
    days: list[HabitDay]


# ---------------------------------------------------------------------------
# AI Coach
# ---------------------------------------------------------------------------

class CoachRequest(BaseModel):
    """Request for morning plan or evening reflection."""

    mode: Literal["morning", "evening"]
    name: str = ""
    aspiration: str = ""
    axes: list[str] = Field(default_factory=list)
    active_tasks: list[str] = Field(default_factory=list)
    completed_today: list[str] = Field(default_factory=list)
    remaining: list[str] = Field(default_factory=list)
    entries_today: int = 0
    streak: int = 0


class MorningPlan(BaseModel):
    greeting: str
    focus: str
    tasks: list[str]
    motivation: str


class EveningReflection(BaseModel):
    summary: str
    wins: list[str]
    improvements: list[str]
    encouragement: str


class CoachResponse(BaseModel):
    model: str
    mode: Literal["morning", "evening"]
    morning: MorningPlan | None = None
    evening: EveningReflection | None = None
