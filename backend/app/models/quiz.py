from datetime import datetime
from sqlalchemy import String, Integer, Float, Boolean, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Quiz(Base):
    __tablename__ = "quizzes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    syllabus_id: Mapped[int] = mapped_column(Integer, ForeignKey("syllabi.id"), nullable=True)
    quiz_type: Mapped[str] = mapped_column(String(20), nullable=False)  # "assessment" or "lesson"
    topic: Mapped[str] = mapped_column(String(255), nullable=True)  # specific topic if lesson quiz
    # JSON: list of question objects {question, options, correct_answer, explanation}
    questions: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    syllabus = relationship("Syllabus", back_populates="quizzes")
    attempts = relationship("QuizAttempt", back_populates="quiz", lazy="select")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    quiz_id: Mapped[int] = mapped_column(Integer, ForeignKey("quizzes.id"), nullable=False)
    # JSON: list of user's answers (indices)
    answers: Mapped[str] = mapped_column(Text, nullable=False)
    score: Mapped[float] = mapped_column(Float, nullable=False)  # 0.0 to 1.0
    tokens_earned: Mapped[int] = mapped_column(Integer, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="quiz_attempts")
    quiz = relationship("Quiz", back_populates="attempts")
