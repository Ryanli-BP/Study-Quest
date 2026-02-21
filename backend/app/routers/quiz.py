import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models.material import Syllabus
from app.models.quiz import Quiz, QuizAttempt
from app.models.token import TokenTransaction
from app.models.user import User
from app.schemas.quiz import (
    GenerateAssessmentRequest,
    GenerateLessonQuizRequest,
    QuizOut,
    QuizResult,
    QuizSubmit,
)
from app.services import claude as gemini_svc

router = APIRouter(prefix="/quiz", tags=["quiz"])


def _strip_answers(questions: list[dict]) -> list[dict]:
    """Return questions without correct_index so the client can't cheat."""
    return [
        {k: v for k, v in q.items() if k != "correct_index"}
        for q in questions
    ]


async def _get_syllabus_for_user(
    syllabus_id: int, user_id: int, db: AsyncSession
) -> Syllabus:
    result = await db.execute(
        select(Syllabus).where(Syllabus.id == syllabus_id, Syllabus.user_id == user_id)
    )
    syllabus = result.scalar_one_or_none()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")
    return syllabus


# ---------------------------------------------------------------------------
# Quiz generation endpoints
# ---------------------------------------------------------------------------

@router.post("/assessment/generate", response_model=QuizOut, status_code=status.HTTP_201_CREATED)
async def generate_assessment_quiz(
    req: GenerateAssessmentRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate a knowledge-level assessment quiz from a syllabus."""
    syllabus = await _get_syllabus_for_user(req.syllabus_id, current_user.id, db)
    syllabus_data = {
        "summary": json.loads(syllabus.summary),
        "topics": json.loads(syllabus.topics),
    }

    questions = await gemini_svc.generate_assessment_quiz(syllabus_data, req.num_questions)

    quiz = Quiz(
        user_id=current_user.id,
        syllabus_id=syllabus.id,
        quiz_type="assessment",
        topic=None,
        questions=json.dumps(questions),
    )
    db.add(quiz)
    await db.flush()
    await db.refresh(quiz)

    return QuizOut(
        id=quiz.id,
        quiz_type=quiz.quiz_type,
        topic=quiz.topic,
        questions=_strip_answers(questions),
        created_at=quiz.created_at,
    )


@router.post("/lesson/generate", response_model=QuizOut, status_code=status.HTTP_201_CREATED)
async def generate_lesson_quiz(
    req: GenerateLessonQuizRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate a quiz for a specific lesson topic."""
    syllabus = await _get_syllabus_for_user(req.syllabus_id, current_user.id, db)
    topics = json.loads(syllabus.topics)

    topic = next(
        (t for t in topics if t["topic_number"] == req.topic_number), None
    )
    if not topic:
        raise HTTPException(status_code=404, detail=f"Topic {req.topic_number} not found in syllabus")

    questions = await gemini_svc.generate_lesson_quiz(topic, req.num_questions)

    quiz = Quiz(
        user_id=current_user.id,
        syllabus_id=syllabus.id,
        quiz_type="lesson",
        topic=topic["title"],
        questions=json.dumps(questions),
    )
    db.add(quiz)
    await db.flush()
    await db.refresh(quiz)

    return QuizOut(
        id=quiz.id,
        quiz_type=quiz.quiz_type,
        topic=quiz.topic,
        questions=_strip_answers(questions),
        created_at=quiz.created_at,
    )


# ---------------------------------------------------------------------------
# Quiz submission + evaluation
# ---------------------------------------------------------------------------

@router.post("/{quiz_id}/submit", response_model=QuizResult)
async def submit_quiz(
    quiz_id: int,
    submission: QuizSubmit,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit answers for a quiz. Returns score, feedback, and tokens earned."""
    result = await db.execute(
        select(Quiz).where(Quiz.id == quiz_id, Quiz.user_id == current_user.id)
    )
    quiz = result.scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")

    questions = json.loads(quiz.questions)
    if len(submission.answers) != len(questions):
        raise HTTPException(
            status_code=400,
            detail=f"Expected {len(questions)} answers, got {len(submission.answers)}",
        )

    # Score the quiz
    correct_count = 0
    feedback = []
    for i, (q, user_ans) in enumerate(zip(questions, submission.answers)):
        is_correct = user_ans == q["correct_index"]
        if is_correct:
            correct_count += 1
        feedback.append({
            "question_index": i,
            "question": q["question"],
            "your_answer": q["options"][user_ans] if 0 <= user_ans < 4 else "Invalid",
            "correct_answer": q["options"][q["correct_index"]],
            "is_correct": is_correct,
            "explanation": q["explanation"],
        })

    score = correct_count / len(questions)

    # Calculate token reward
    if quiz.quiz_type == "assessment":
        base_reward = settings.quiz_complete_reward
    else:
        base_reward = settings.quiz_complete_reward
    bonus = settings.quiz_perfect_score_bonus if score == 1.0 else 0
    tokens_earned = base_reward + bonus

    # Save attempt
    attempt = QuizAttempt(
        user_id=current_user.id,
        quiz_id=quiz.id,
        answers=json.dumps(submission.answers),
        score=score,
        tokens_earned=tokens_earned,
    )
    db.add(attempt)

    # Award tokens
    current_user.tokens += tokens_earned
    tx = TokenTransaction(
        user_id=current_user.id,
        amount=tokens_earned,
        transaction_type="quiz_complete",
        description=f"Completed {quiz.quiz_type} quiz (score: {round(score * 100)}%)",
    )
    db.add(tx)
    await db.flush()
    await db.refresh(attempt)

    # For assessment quizzes, generate a level assessment via Gemini
    level_assessment = None
    if quiz.quiz_type == "assessment":
        try:
            assessment = await gemini_svc.assess_knowledge_level(score, correct_count, len(questions))
            level_assessment = f"{assessment['level']}: {assessment['assessment']} {assessment['recommendation']}"
        except Exception:
            level_assessment = f"Score: {round(score * 100)}%"

    return QuizResult(
        quiz_id=quiz.id,
        attempt_id=attempt.id,
        score=score,
        correct_count=correct_count,
        total_questions=len(questions),
        tokens_earned=tokens_earned,
        feedback=feedback,
        level_assessment=level_assessment,
    )


@router.get("/{quiz_id}", response_model=QuizOut)
async def get_quiz(
    quiz_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Quiz).where(Quiz.id == quiz_id, Quiz.user_id == current_user.id)
    )
    quiz = result.scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")

    questions = json.loads(quiz.questions)
    return QuizOut(
        id=quiz.id,
        quiz_type=quiz.quiz_type,
        topic=quiz.topic,
        questions=_strip_answers(questions),
        created_at=quiz.created_at,
    )
