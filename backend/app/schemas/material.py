from datetime import datetime
from typing import Any
from pydantic import BaseModel


class LessonTopic(BaseModel):
    topic_number: int
    title: str
    summary: str
    key_concepts: list[str]
    estimated_minutes: int


class LessonPlanDay(BaseModel):
    day: int
    date_label: str  # e.g. "Day 1", "Week 1 - Monday"
    topics: list[str]
    duration_minutes: int


class SyllabusOut(BaseModel):
    id: int
    material_id: int
    user_id: int
    summary: dict[str, Any]
    topics: list[LessonTopic]
    lesson_plan: list[LessonPlanDay]
    created_at: datetime

    model_config = {"from_attributes": True}


class MaterialSummary(BaseModel):
    """Lightweight syllabus info embedded in the materials list."""
    id: int
    created_at: datetime

    model_config = {"from_attributes": True}


class MaterialOut(BaseModel):
    id: int
    user_id: int
    original_filename: str
    file_type: str
    processed: bool
    created_at: datetime
    syllabus: MaterialSummary | None = None

    model_config = {"from_attributes": True}
