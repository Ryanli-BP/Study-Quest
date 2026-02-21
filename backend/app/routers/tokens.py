from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models.material import Syllabus
from app.models.token import TokenTransaction
from app.models.user import User
from app.schemas.token import LessonCompleteRequest, TokenBalance, TokenTransactionOut

router = APIRouter(prefix="/tokens", tags=["tokens"])


@router.get("/balance", response_model=TokenBalance)
async def get_balance(current_user: User = Depends(get_current_user)):
    """Get the current token balance for the authenticated user."""
    return TokenBalance(user_id=current_user.id, tokens=current_user.tokens)


@router.get("/history", response_model=list[TokenTransactionOut])
async def get_history(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get recent token transaction history."""
    result = await db.execute(
        select(TokenTransaction)
        .where(TokenTransaction.user_id == current_user.id)
        .order_by(TokenTransaction.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.post("/lesson/complete", response_model=TokenBalance)
async def complete_lesson(
    req: LessonCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Mark a lesson topic as complete and award tokens.
    Call this when the user finishes reading/viewing a lesson in the app.
    """
    # Verify the syllabus belongs to the user
    result = await db.execute(
        select(Syllabus).where(
            Syllabus.id == req.syllabus_id,
            Syllabus.user_id == current_user.id,
        )
    )
    syllabus = result.scalar_one_or_none()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")

    # Simple duplicate-completion guard: check if this lesson was already rewarded
    result = await db.execute(
        select(TokenTransaction).where(
            TokenTransaction.user_id == current_user.id,
            TokenTransaction.transaction_type == "lesson_complete",
            TokenTransaction.description == f"Lesson {req.topic_number} of syllabus {req.syllabus_id}",
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=409,
            detail="Tokens already awarded for this lesson",
        )

    reward = settings.lesson_complete_reward
    current_user.tokens += reward
    tx = TokenTransaction(
        user_id=current_user.id,
        amount=reward,
        transaction_type="lesson_complete",
        description=f"Lesson {req.topic_number} of syllabus {req.syllabus_id}",
    )
    db.add(tx)
    await db.flush()

    return TokenBalance(user_id=current_user.id, tokens=current_user.tokens)
