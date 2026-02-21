from datetime import datetime
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UploadedMaterial(Base):
    __tablename__ = "uploaded_materials"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(512), nullable=False)
    file_type: Mapped[str] = mapped_column(String(20), nullable=False)  # pdf or pptx
    processed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="materials")
    syllabus = relationship("Syllabus", back_populates="material", uselist=False)


class Syllabus(Base):
    __tablename__ = "syllabi"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    material_id: Mapped[int] = mapped_column(Integer, ForeignKey("uploaded_materials.id"), nullable=False)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    # JSON stored as text: list of topics with simplified content
    topics: Mapped[str] = mapped_column(Text, nullable=False)
    # JSON stored as text: lesson plan with timetable
    lesson_plan: Mapped[str] = mapped_column(Text, nullable=False)
    # JSON stored as text: subject title and overall summary
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    material = relationship("UploadedMaterial", back_populates="syllabus")
    quizzes = relationship("Quiz", back_populates="syllabus", lazy="select")
