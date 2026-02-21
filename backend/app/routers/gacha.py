from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models.gacha import UserCharacter
from app.models.token import TokenTransaction
from app.models.user import User
from app.schemas.gacha import GachaPullResponse, PullResult, UserCharacterOut, GachaCharacterOut
from app.services import gacha as gacha_svc

router = APIRouter(prefix="/gacha", tags=["gacha"])


@router.post("/pull/single", response_model=GachaPullResponse)
async def single_pull(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Spend tokens for a single gacha pull."""
    cost = settings.single_pull_cost
    if current_user.tokens < cost:
        raise HTTPException(
            status_code=402,
            detail=f"Insufficient tokens. Need {cost}, have {current_user.tokens}.",
        )

    current_user.tokens -= cost
    results = await gacha_svc.perform_pulls(db, current_user.id, num_pulls=1)

    tx = TokenTransaction(
        user_id=current_user.id,
        amount=-cost,
        transaction_type="gacha_pull",
        description="Single gacha pull",
    )
    db.add(tx)
    await db.flush()

    return GachaPullResponse(
        pulls=[PullResult(
            character=GachaCharacterOut.model_validate(r["character"]),
            is_new=r["is_new"],
            is_duplicate=r["is_duplicate"],
        ) for r in results],
        tokens_spent=cost,
        remaining_tokens=current_user.tokens,
    )


@router.post("/pull/ten", response_model=GachaPullResponse)
async def ten_pull(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Spend tokens for 10 gacha pulls (discounted)."""
    cost = settings.ten_pull_cost
    if current_user.tokens < cost:
        raise HTTPException(
            status_code=402,
            detail=f"Insufficient tokens. Need {cost}, have {current_user.tokens}.",
        )

    current_user.tokens -= cost
    results = await gacha_svc.perform_pulls(db, current_user.id, num_pulls=10)

    tx = TokenTransaction(
        user_id=current_user.id,
        amount=-cost,
        transaction_type="gacha_pull",
        description="10x gacha pull",
    )
    db.add(tx)
    await db.flush()

    return GachaPullResponse(
        pulls=[PullResult(
            character=GachaCharacterOut.model_validate(r["character"]),
            is_new=r["is_new"],
            is_duplicate=r["is_duplicate"],
        ) for r in results],
        tokens_spent=cost,
        remaining_tokens=current_user.tokens,
    )


@router.get("/collection", response_model=list[UserCharacterOut])
async def get_collection(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all characters owned by the current user."""
    result = await db.execute(
        select(UserCharacter).where(UserCharacter.user_id == current_user.id)
    )
    user_chars = result.scalars().all()

    # Load characters (lazy-safe: access within session)
    from app.models.gacha import GachaCharacter
    output = []
    for uc in user_chars:
        char = await db.get(GachaCharacter, uc.character_id)
        output.append(UserCharacterOut(
            id=uc.id,
            character=GachaCharacterOut.model_validate(char),
            obtained_at=uc.obtained_at,
            is_duplicate=uc.is_duplicate,
        ))
    return output


@router.get("/characters", response_model=list[GachaCharacterOut])
async def list_all_characters(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all available gacha characters (for a preview/roster view)."""
    from app.models.gacha import GachaCharacter
    from sqlalchemy import select
    result = await db.execute(select(GachaCharacter))
    return result.scalars().all()
