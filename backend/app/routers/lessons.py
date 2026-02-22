"""
Lesson content routes.

GET  /lessons/{syllabus_id}/{topic_number}        — fetch (or generate) lesson sections
POST /lessons/{syllabus_id}/{topic_number}/ask    — AI Q&A for that topic
"""

import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.material import Syllabus
from app.models.lesson_content import LessonContent
from app.services import claude as claude_svc
from app.models.token import TokenTransaction

router = APIRouter(prefix="/lessons", tags=["lessons"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class AskRequest(BaseModel):
    question: str
    history: list[dict] = []  # [{role: "user"|"assistant", content: "..."}]


class AskResponse(BaseModel):
    answer: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _get_syllabus_and_topic(
    syllabus_id: int,
    topic_number: int,
    user: User,
    db: AsyncSession,
):
    """Return (syllabus_row, topic_dict) or raise 404."""
    result = await db.execute(
        select(Syllabus).where(
            Syllabus.id == syllabus_id,
            Syllabus.user_id == user.id,
        )
    )
    syllabus = result.scalar_one_or_none()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")

    topics = json.loads(syllabus.topics)
    topic = next((t for t in topics if t["topic_number"] == topic_number), None)
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")

    return syllabus, topic


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("/completedTopics")
async def is_lesson_completed(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(TokenTransaction).where(
            TokenTransaction.transaction_type == "lesson_complete",
            TokenTransaction.description.like(f"Lesson % of syllabus %"),
            TokenTransaction.user_id == current_user.id,
        )
    )
    rows = result.scalars().all()

    # Extract topic numbers from descriptions like "Lesson 3 of syllabus 12"
    import re

    topic_nums = []
    for t in rows:
        if not t.description:
            continue
        m = re.search(r"Lesson\s+(\d+)\s+of\s+syllabus\s+\d+", t.description)
        if m:
            try:
                topic_nums.append(int(m.group(1)))
            except ValueError:
                continue

    return {"completed": topic_nums}


@router.get("/{syllabus_id}/completedTopics")
async def is_lesson_completed(
    syllabus_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(TokenTransaction).where(
            TokenTransaction.transaction_type == "lesson_complete",
            TokenTransaction.description.like(f"Lesson % of syllabus {syllabus_id}"),
            TokenTransaction.user_id == current_user.id,
        )
    )
    rows = result.scalars().all()

    # Extract topic numbers from descriptions like "Lesson 3 of syllabus 12"
    import re

    topic_nums = []
    for t in rows:
        if not t.description:
            continue
        m = re.search(
            r"Lesson\s+(\d+)\s+of\s+syllabus\s+%s" % syllabus_id, t.description
        )
        if m:
            try:
                topic_nums.append(int(m.group(1)))
            except ValueError:
                continue

    return {"completed": topic_nums}


@router.get("/{syllabus_id}/{topic_number}")
async def get_lesson(
    syllabus_id: int,
    topic_number: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return cached lesson content, or generate it fresh via Claude."""
    syllabus, topic = await _get_syllabus_and_topic(
        syllabus_id, topic_number, current_user, db
    )

    # Check cache
    result = await db.execute(
        select(LessonContent).where(
            LessonContent.syllabus_id == syllabus_id,
            LessonContent.topic_number == topic_number,
        )
    )
    cached = result.scalar_one_or_none()
    if cached:
        return {"sections": json.loads(cached.sections), "cached": True}

    # Generate with Claude
    summary = json.loads(syllabus.summary)
    subject = summary.get("subject", "")
    sections = await claude_svc.generate_lesson(topic, subject=subject)

    # Cache in DB
    lesson_content = LessonContent(
        syllabus_id=syllabus_id,
        topic_number=topic_number,
        sections=json.dumps(sections),
    )
    db.add(lesson_content)
    await db.commit()

    return {"sections": sections, "cached": False}


@router.post("/{syllabus_id}/{topic_number}/ask", response_model=AskResponse)
async def ask_question(
    syllabus_id: int,
    topic_number: int,
    body: AskRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Answer a student question about this topic."""
    _, topic = await _get_syllabus_and_topic(
        syllabus_id, topic_number, current_user, db
    )

    answer = await claude_svc.answer_question(
        topic=topic,
        question=body.question,
        history=body.history,
    )
    return AskResponse(answer=answer)
