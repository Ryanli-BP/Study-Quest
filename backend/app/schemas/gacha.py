from datetime import datetime
from pydantic import BaseModel


class GachaCharacterOut(BaseModel):
    id: int
    name: str
    rarity: str
    description: str
    subject_affinity: str | None
    image_url: str | None

    model_config = {"from_attributes": True}


class PullResult(BaseModel):
    character: GachaCharacterOut
    is_new: bool        # False if user already owns this character (duplicate)
    is_duplicate: bool


class GachaPullResponse(BaseModel):
    pulls: list[PullResult]
    tokens_spent: int
    remaining_tokens: int


class UserCharacterOut(BaseModel):
    id: int
    character: GachaCharacterOut
    obtained_at: datetime
    is_duplicate: bool

    model_config = {"from_attributes": True}
