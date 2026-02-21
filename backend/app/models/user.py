from datetime import datetime
from sqlalchemy import String, Integer, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    tokens: Mapped[int] = mapped_column(Integer, default=100, nullable=False)  # start with 100 tokens
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    materials = relationship("UploadedMaterial", back_populates="user", lazy="select")
    quiz_attempts = relationship("QuizAttempt", back_populates="user", lazy="select")
    characters = relationship("UserCharacter", back_populates="user", lazy="select")
    token_transactions = relationship("TokenTransaction", back_populates="user", lazy="select")
