from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models import User, Work
from ..schemas import ExportImageCreate, WorkCreate, WorkListOut, WorkOut, WorkUpdate
from ..services.session_auth import get_current_user
from ..services.storage import StorageError, StorageService

router = APIRouter(prefix="/works", tags=["works"])


def get_owned_work(work_id: str, current_user: User, db: Session) -> Work:
    work = db.get(Work, work_id)
    if work is None or work.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="work not found")
    return work


@router.post("", response_model=WorkOut, status_code=status.HTTP_201_CREATED)
def create_work(payload: WorkCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Work:
    work = Work(
        user_id=current_user.id,
        template_id=payload.template_id,
        title=payload.title,
        input_text=payload.input_text,
        render_params=payload.render_params,
    )
    db.add(work)
    db.commit()
    db.refresh(work)
    return work


@router.get("", response_model=WorkListOut)
def list_works(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> WorkListOut:
    statement = select(Work).where(Work.user_id == current_user.id).order_by(Work.created_at.desc())
    return WorkListOut(items=db.scalars(statement).all())


@router.patch("/{work_id}", response_model=WorkOut)
def update_work(work_id: str, payload: WorkUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Work:
    work = get_owned_work(work_id, current_user, db)

    work.template_id = payload.template_id
    work.title = payload.title
    work.input_text = payload.input_text
    work.render_params = payload.render_params
    db.commit()
    db.refresh(work)
    return work


@router.post("/{work_id}/export", response_model=WorkOut)
def save_work_export(work_id: str, payload: ExportImageCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Work:
    work = get_owned_work(work_id, current_user, db)

    storage = StorageService(get_settings().resolved_storage_root)
    try:
        work.export_path = storage.save_base64_image(f"works/{work.id}", payload.filename, payload.image_base64)
    except StorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    db.commit()
    db.refresh(work)
    return work


@router.delete("/{work_id}")
def delete_work(work_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, str]:
    work = get_owned_work(work_id, current_user, db)

    if work.export_path:
        StorageService(get_settings().resolved_storage_root).delete(work.export_path)

    db.delete(work)
    db.commit()
    return {"deleted": work_id}
