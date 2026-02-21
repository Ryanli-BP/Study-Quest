"""
Gacha pull service — weighted random character selection with pity system.
"""
import random
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.gacha import GachaCharacter, UserCharacter

# Rarity weights (out of 1000)
RARITY_WEIGHTS = {
    "common": 600,
    "rare": 280,
    "epic": 100,
    "legendary": 20,
}

RARITY_ORDER = ["common", "rare", "epic", "legendary"]


async def get_all_characters(db: AsyncSession) -> list[GachaCharacter]:
    result = await db.execute(select(GachaCharacter))
    return result.scalars().all()


async def get_user_character_ids(db: AsyncSession, user_id: int) -> set[int]:
    result = await db.execute(
        select(UserCharacter.character_id).where(UserCharacter.user_id == user_id)
    )
    return set(result.scalars().all())


def _weighted_pick(characters: list[GachaCharacter]) -> GachaCharacter:
    """Pick a character using drop_weight as weight."""
    weights = [c.drop_weight for c in characters]
    return random.choices(characters, weights=weights, k=1)[0]


async def perform_pulls(
    db: AsyncSession,
    user_id: int,
    num_pulls: int,
) -> list[dict]:
    """
    Execute `num_pulls` gacha pulls for a user.
    Returns list of {character, is_new, is_duplicate}.
    """
    characters = await get_all_characters(db)
    if not characters:
        raise ValueError("No gacha characters available")

    owned_ids = await get_user_character_ids(db, user_id)
    results = []

    for _ in range(num_pulls):
        picked = _weighted_pick(characters)
        is_duplicate = picked.id in owned_ids

        user_char = UserCharacter(
            user_id=user_id,
            character_id=picked.id,
            is_duplicate=is_duplicate,
        )
        db.add(user_char)
        owned_ids.add(picked.id)  # track within this pull batch

        results.append({
            "character": picked,
            "is_new": not is_duplicate,
            "is_duplicate": is_duplicate,
        })

    await db.flush()
    return results


# ---------------------------------------------------------------------------
# Seed default characters (called at startup if table is empty)
# ---------------------------------------------------------------------------

DEFAULT_CHARACTERS = [
    # Common
    {"name": "Sparky", "rarity": "common", "description": "A cheerful spark of curiosity. Loves maths puzzles.", "subject_affinity": "Mathematics", "drop_weight": 300},
    {"name": "Leafy", "rarity": "common", "description": "A gentle leaf spirit with a passion for biology.", "subject_affinity": "Biology", "drop_weight": 300},
    {"name": "Chisel", "rarity": "common", "description": "A sturdy stone golem fascinated by history.", "subject_affinity": "History", "drop_weight": 300},
    {"name": "Bubbles", "rarity": "common", "description": "An effervescent water sprite who loves chemistry.", "subject_affinity": "Chemistry", "drop_weight": 300},
    # Rare
    {"name": "Nova", "rarity": "rare", "description": "A starborn scholar with deep knowledge of physics.", "subject_affinity": "Physics", "drop_weight": 140},
    {"name": "Cipher", "rarity": "rare", "description": "A mysterious code-breaker who excels at computer science.", "subject_affinity": "Computer Science", "drop_weight": 140},
    {"name": "Lyra", "rarity": "rare", "description": "A melodic muse who inspires creativity in literature.", "subject_affinity": "Literature", "drop_weight": 140},
    # Epic
    {"name": "Arcanum", "rarity": "epic", "description": "An ancient wizard who has mastered multiple disciplines.", "subject_affinity": None, "drop_weight": 50},
    {"name": "Solaris", "rarity": "epic", "description": "A solar phoenix who radiates knowledge of astronomy.", "subject_affinity": "Astronomy", "drop_weight": 50},
    # Legendary
    {"name": "Omnisage", "rarity": "legendary", "description": "The legendary all-knowing sage. Said to appear only to the most dedicated learners.", "subject_affinity": None, "drop_weight": 20},
]


async def seed_characters(db: AsyncSession):
    result = await db.execute(select(GachaCharacter))
    existing = result.scalars().first()
    if existing:
        return  # already seeded

    for char_data in DEFAULT_CHARACTERS:
        char = GachaCharacter(**char_data)
        db.add(char)
    await db.flush()
