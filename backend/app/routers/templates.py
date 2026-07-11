from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Template
from ..schemas import TemplateListOut, TemplateOut
from ..services.templates import SEED_TEMPLATES

router = APIRouter(prefix="/templates", tags=["templates"])

FEATURED_TEMPLATE_IDS = [
    "note-share-poster",
    "local-store",
    "travel-guide",
    "knowledge-note",
    "parenting-note",
    "marketing-note",
    "xhs-video-shot",
]


@router.get("", response_model=TemplateListOut)
def list_templates(db: Session = Depends(get_db)) -> TemplateListOut:
    templates = list(db.scalars(select(Template).where(Template.is_active.is_(True))).all())
    remaining_ids = [item["id"] for item in SEED_TEMPLATES if item["id"] not in FEATURED_TEMPLATE_IDS]
    template_order = {
        template_id: index for index, template_id in enumerate(FEATURED_TEMPLATE_IDS + remaining_ids)
    }
    templates.sort(key=lambda template: template_order.get(template.id, len(template_order)))
    return TemplateListOut(items=templates)


@router.get("/{template_id}", response_model=TemplateOut)
def get_template(template_id: str, db: Session = Depends(get_db)) -> Template:
    template = db.get(Template, template_id)
    if template is None or not template.is_active:
        raise HTTPException(status_code=404, detail="template not found")
    return template
