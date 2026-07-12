import mimetypes
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models import User, Work
from ..schemas import ExportImageCreate, WorkAssetCreate, WorkCreate, WorkListOut, WorkOut, WorkUpdate
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
def list_works(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    query: Annotated[str | None, Query(max_length=160)] = None,
    template_id: Annotated[str | None, Query(max_length=80)] = None,
    exported: bool | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 24,
) -> WorkListOut:
    filters = [Work.user_id == current_user.id]
    search_text = query.strip() if query else ""
    if search_text:
        pattern = f"%{search_text}%"
        filters.append(or_(Work.title.ilike(pattern), Work.input_text.ilike(pattern)))
    if template_id:
        filters.append(Work.template_id == template_id)
    if exported is True:
        filters.append(Work.export_path.is_not(None))
    elif exported is False:
        filters.append(Work.export_path.is_(None))

    total = db.scalar(select(func.count()).select_from(Work).where(*filters)) or 0
    statement = (
        select(Work)
        .where(*filters)
        .order_by(Work.updated_at.desc(), Work.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return WorkListOut(items=db.scalars(statement).all(), total=total, page=page, page_size=page_size)


@router.patch("/{work_id}", response_model=WorkOut)
def update_work(work_id: str, payload: WorkUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Work:
    work = get_owned_work(work_id, current_user, db)

    work.template_id = payload.template_id
    work.title = payload.title
    work.input_text = payload.input_text
    render_params = dict(payload.render_params)
    existing_assets = work.render_params.get("assets")
    if isinstance(existing_assets, dict):
        render_params["assets"] = existing_assets
    work.render_params = render_params
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


def _asset_path(work: Work, asset_kind: str) -> str:
    assets = work.render_params.get("assets", {})
    relative_path = assets.get(asset_kind) if isinstance(assets, dict) else None
    expected_prefix = f"works-{work.id}/asset-{asset_kind}-"
    if not isinstance(relative_path, str) or not relative_path.startswith(expected_prefix):
        raise HTTPException(status_code=404, detail="work asset not found")
    return relative_path


@router.post("/{work_id}/assets", response_model=WorkOut)
def save_work_asset(
    work_id: str,
    payload: WorkAssetCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Work:
    work = get_owned_work(work_id, current_user, db)
    storage = StorageService(get_settings().resolved_storage_root)
    try:
        relative_path = storage.save_base64_image(
            f"works/{work.id}",
            f"asset-{payload.kind}-{payload.filename}",
            payload.image_base64,
        )
    except StorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    render_params = dict(work.render_params)
    existing_assets = render_params.get("assets")
    assets = dict(existing_assets) if isinstance(existing_assets, dict) else {}
    previous_path = assets.get(payload.kind)
    assets[payload.kind] = relative_path
    render_params["assets"] = assets
    work.render_params = render_params
    if isinstance(previous_path, str) and previous_path != relative_path:
        storage.delete(previous_path)
    db.commit()
    db.refresh(work)
    return work


@router.get("/{work_id}/assets/{asset_kind}")
def get_work_asset(
    work_id: str,
    asset_kind: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FileResponse:
    if asset_kind not in {"cover", "avatar"}:
        raise HTTPException(status_code=404, detail="work asset not found")
    work = get_owned_work(work_id, current_user, db)
    try:
        path = StorageService(get_settings().resolved_storage_root).resolve_file(_asset_path(work, asset_kind))
    except StorageError as exc:
        raise HTTPException(status_code=404, detail="work asset not found") from exc
    media_type, _ = mimetypes.guess_type(path.name)
    return FileResponse(path, media_type=media_type or "application/octet-stream")


@router.delete("/{work_id}/assets/{asset_kind}")
def delete_work_asset(
    work_id: str,
    asset_kind: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    if asset_kind not in {"cover", "avatar"}:
        raise HTTPException(status_code=404, detail="work asset not found")
    work = get_owned_work(work_id, current_user, db)
    try:
        relative_path = _asset_path(work, asset_kind)
    except HTTPException:
        return {"deleted": asset_kind}

    storage = StorageService(get_settings().resolved_storage_root)
    storage.delete(relative_path)
    render_params = dict(work.render_params)
    existing_assets = render_params.get("assets")
    assets = dict(existing_assets) if isinstance(existing_assets, dict) else {}
    assets.pop(asset_kind, None)
    render_params["assets"] = assets
    work.render_params = render_params
    db.commit()
    return {"deleted": asset_kind}


@router.delete("/{work_id}")
def delete_work(work_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, str]:
    work = get_owned_work(work_id, current_user, db)

    StorageService(get_settings().resolved_storage_root).delete_tree(f"works/{work.id}")

    db.delete(work)
    db.commit()
    return {"deleted": work_id}
