from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..models import GenerationTask


DEFAULT_TAGS = ["#知识卡片", "#小红书图文", "#Cardify"]


def build_card_copy(input_text: str) -> dict:
    normalized = " ".join(input_text.strip().split())
    title = normalized[:36] if len(normalized) <= 36 else f"{normalized[:34]}..."
    summary = normalized[:140] if len(normalized) <= 140 else f"{normalized[:137]}..."
    tags = DEFAULT_TAGS.copy()

    if any(word in normalized for word in ["孩子", "育儿", "启蒙", "宝宝"]):
        tags = ["#育儿经验", "#亲子成长", "#启蒙记录"]
    elif any(word in normalized for word in ["转化", "用户", "营销", "卖点"]):
        tags = ["#营销方法", "#种草文案", "#增长笔记"]
    elif any(word in normalized for word in ["旅行", "城市", "路线", "攻略"]):
        tags = ["#旅行攻略", "#城市漫游", "#实用清单"]

    return {
        "title": title or "给你的内容生成一张卡片",
        "summary": summary or "输入内容后，Cardify 会整理成适合分享的卡片文案。",
        "tags": tags,
        "author_name": "Cardify",
        "metrics": {"likes": 4263, "favorites": 791, "comments": 120},
        "provider": "local-rule",
    }


def run_generation_task(task_id: str) -> None:
    db: Session = SessionLocal()
    try:
        task = db.get(GenerationTask, task_id)
        if task is None:
            return
        task.status = "running"
        db.commit()

        task.output = build_card_copy(task.input_text)
        task.status = "succeeded"
        db.commit()
    except Exception as exc:  # pragma: no cover - defensive status capture
        db.rollback()
        task = db.get(GenerationTask, task_id)
        if task is not None:
            task.status = "failed"
            task.error = str(exc)
            db.commit()
    finally:
        db.close()
