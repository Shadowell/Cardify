from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Template
from ..schemas import TemplateListOut, TemplateOut

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get("", response_model=TemplateListOut)
def list_templates(db: Session = Depends(get_db)) -> TemplateListOut:
    templates = db.scalars(select(Template).where(Template.is_active.is_(True)).order_by(Template.category, Template.name)).all()
    return TemplateListOut(items=templates)


@router.get("/{template_id}", response_model=TemplateOut)
def get_template(template_id: str, db: Session = Depends(get_db)) -> Template:
    template = db.get(Template, template_id)
    if template is None or not template.is_active:
        raise HTTPException(status_code=404, detail="template not found")
    return template
