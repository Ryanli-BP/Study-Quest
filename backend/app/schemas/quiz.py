from datetime import datetime
from pydantic import BaseModel


class QuizQuestion(BaseModel):
    question: str
    options: list[str]      # 4 options, A-D
    correct_index: int      # 0-3
    explanation: str


class QuizOut(BaseModel):
    id: int
    quiz_type: str
    topic: str | None
    # Questions returned WITHOUT correct_index (don't expose answers to client)
    questions: list[dict]
    created_at: datetime

    model_config = {"from_attributes": True}


class QuizSubmit(BaseModel):
    answers: list[int]  # list of chosen option indices (0-3), one per question


class QuizResult(BaseModel):
    quiz_id: int
    attempt_id: int
    score: float            # 0.0 to 1.0
    correct_count: int
    total_questions: int
    tokens_earned: int
    feedback: list[dict]    # per-question feedback with correct answer + explanation
    level_assessment: str | None = None  # only for assessment quizzes


class GenerateAssessmentRequest(BaseModel):
    syllabus_id: int
    num_questions: int = 10


class GenerateLessonQuizRequest(BaseModel):
    syllabus_id: int
    topic_number: int
    num_questions: int = 5
