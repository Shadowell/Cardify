from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import GenerationTask
from ..schemas import GenerationCreate, GenerationOut
from ..services.generation import run_generation_task

router = APIRouter(prefix="/generations", tags=["generations"])


@router.post("", response_model=GenerationOut, status_code=status.HTTP_202_ACCEPTED)
def create_generation(
    payload: GenerationCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> GenerationTask:
    task = GenerationTask(input_text=payload.input_text, template_id=payload.template_id)
    db.add(task)
    db.commit()
    db.refresh(task)
    background_tasks.add_task(run_generation_task, task.id)
    return task


@router.get("/{task_id}", response_model=GenerationOut)
def get_generation(task_id: str, db: Session = Depends(get_db)) -> GenerationTask:
    task = db.get(GenerationTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="generation not found")
    return task
