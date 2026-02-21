from datetime import datetime
from pydantic import BaseModel


class TokenBalance(BaseModel):
    user_id: int
    tokens: int


class TokenTransactionOut(BaseModel):
    id: int
    amount: int
    transaction_type: str
    description: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class LessonCompleteRequest(BaseModel):
    syllabus_id: int
    topic_number: int
