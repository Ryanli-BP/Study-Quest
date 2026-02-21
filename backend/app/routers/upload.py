import json
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models.material import UploadedMaterial, Syllabus
from app.models.user import User
from app.schemas.material import MaterialOut, SyllabusOut, LessonTopic, LessonPlanDay
from app.services import claude as gemini_svc

router = APIRouter(prefix="/materials", tags=["materials"])

ALLOWED_TYPES = {
    "application/pdf": "pdf",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx",
    "application/vnd.ms-powerpoint": "ppt",
}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB


@router.post("/upload", status_code=status.HTTP_202_ACCEPTED)
async def upload_material(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a PDF or PPTX study material. Returns material ID; processing is synchronous."""
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{file.content_type}'. Upload a PDF or PPTX.",
        )

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large. Maximum size is 50 MB.")

    file_type = ALLOWED_TYPES[file.content_type]
    stored_name = f"{uuid.uuid4().hex}.{file_type}"
    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    file_path = upload_dir / stored_name

    with open(file_path, "wb") as f:
        f.write(content)

    material = UploadedMaterial(
        user_id=current_user.id,
        original_filename=file.filename,
        stored_filename=stored_name,
        file_path=str(file_path),
        file_type=file_type,
        processed=False,
    )
    db.add(material)
    await db.flush()
    await db.refresh(material)

    # Process synchronously (fast enough for hackathon; swap to background task if needed)
    try:
        syllabus_data = await gemini_svc.generate_syllabus(str(file_path), file_type)

        syllabus = Syllabus(
            material_id=material.id,
            user_id=current_user.id,
            summary=json.dumps(syllabus_data["summary"]),
            topics=json.dumps(syllabus_data["topics"]),
            lesson_plan=json.dumps(syllabus_data["lesson_plan"]),
        )
        db.add(syllabus)
        material.processed = True
        await db.flush()
        await db.refresh(syllabus)

        return {
            "material_id": material.id,
            "syllabus_id": syllabus.id,
            "message": "File processed successfully",
            "summary": syllabus_data["summary"],
        }
    except Exception as e:
        # Keep the material record but mark as unprocessed
        await db.flush()
        raise HTTPException(status_code=500, detail=f"AI processing failed: {str(e)}")


@router.get("/", response_model=list[MaterialOut])
async def list_materials(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(UploadedMaterial)
        .where(UploadedMaterial.user_id == current_user.id)
        .options(selectinload(UploadedMaterial.syllabus))
    )
    return result.scalars().all()


@router.get("/{material_id}/syllabus", response_model=SyllabusOut)
async def get_syllabus(
    material_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Syllabus).where(
            Syllabus.material_id == material_id,
            Syllabus.user_id == current_user.id,
        )
    )
    syllabus = result.scalar_one_or_none()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")

    return SyllabusOut(
        id=syllabus.id,
        material_id=syllabus.material_id,
        user_id=syllabus.user_id,
        summary=json.loads(syllabus.summary),
        topics=[LessonTopic(**t) for t in json.loads(syllabus.topics)],
        lesson_plan=[LessonPlanDay(**d) for d in json.loads(syllabus.lesson_plan)],
        created_at=syllabus.created_at,
    )
