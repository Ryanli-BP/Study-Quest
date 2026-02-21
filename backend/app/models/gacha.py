from datetime import datetime
from sqlalchemy import String, Integer, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class GachaCharacter(Base):
    __tablename__ = "gacha_characters"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    rarity: Mapped[str] = mapped_column(String(20), nullable=False)  # common, rare, epic, legendary
    description: Mapped[str] = mapped_column(Text, nullable=False)
    subject_affinity: Mapped[str] = mapped_column(String(100), nullable=True)  # e.g. "Math", "Science"
    image_url: Mapped[str] = mapped_column(String(512), nullable=True)
    # Drop weight (higher = more common)
    drop_weight: Mapped[int] = mapped_column(Integer, default=100)

    owners = relationship("UserCharacter", back_populates="character", lazy="select")


class UserCharacter(Base):
    __tablename__ = "user_characters"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    character_id: Mapped[int] = mapped_column(Integer, ForeignKey("gacha_characters.id"), nullable=False)
    obtained_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    # Track duplicates — can be used for shard/upgrade system later
    is_duplicate: Mapped[bool] = mapped_column(default=False)

    user = relationship("User", back_populates="characters")
    character = relationship("GachaCharacter", back_populates="owners")
