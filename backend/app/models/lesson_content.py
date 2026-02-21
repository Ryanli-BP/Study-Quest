from datetime import datetime
from sqlalchemy import Integer, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class LessonContent(Base):
    __tablename__ = "lesson_contents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    syllabus_id: Mapped[int] = mapped_column(Integer, ForeignKey("syllabi.id"), nullable=False)
    topic_number: Mapped[int] = mapped_column(Integer, nullable=False)
    # JSON: list of {type, title, content} sections
    sections: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
