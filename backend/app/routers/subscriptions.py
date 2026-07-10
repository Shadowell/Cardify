from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Subscription, User
from ..schemas import SubscriptionOut, SubscriptionVerifyCreate

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.post("/verify", response_model=SubscriptionOut)
def verify_subscription(payload: SubscriptionVerifyCreate, db: Session = Depends(get_db)) -> Subscription:
    user = db.get(User, payload.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="user not found")

    now = datetime.now(timezone.utc)
    status = "active"
    if payload.expires_at is not None and payload.expires_at <= now:
        status = "expired"

    subscription = Subscription(
        user_id=payload.user_id,
        product_id=payload.product_id,
        transaction_id=payload.transaction_id,
        expires_at=payload.expires_at,
        status=status,
    )
    db.add(subscription)
    db.commit()
    db.refresh(subscription)
    return subscription
