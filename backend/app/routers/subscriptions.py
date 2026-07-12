from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Subscription, User
from ..schemas import MembershipStatusOut, SubscriptionVerifyCreate
from ..services.session_auth import get_current_user
from ..services.storekit import (
    StoreKitTransactionVerifier,
    StoreKitVerificationError,
    StoreKitVerificationUnavailable,
)

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


def get_storekit_transaction_verifier() -> StoreKitTransactionVerifier:
    from ..config import get_settings

    return StoreKitTransactionVerifier(get_settings())


@router.get("/me", response_model=MembershipStatusOut)
def membership_status(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> MembershipStatusOut:
    subscriptions = list(
        db.scalars(
            select(Subscription)
            .where(Subscription.user_id == current_user.id)
            .order_by(Subscription.created_at.desc())
        )
    )
    return _membership_status(subscriptions)


@router.post("/verify", response_model=MembershipStatusOut)
def verify_subscription(
    payload: SubscriptionVerifyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    verifier: StoreKitTransactionVerifier = Depends(get_storekit_transaction_verifier),
) -> MembershipStatusOut:
    try:
        transaction = verifier.verify(payload.signed_transaction_info)
    except StoreKitVerificationUnavailable as exc:
        raise HTTPException(status_code=503, detail="会员校验服务尚未配置，请稍后再试") from exc
    except StoreKitVerificationError as exc:
        raise HTTPException(status_code=400, detail="无法验证 App Store 交易") from exc

    if transaction.app_account_token != current_user.id:
        raise HTTPException(status_code=403, detail="交易不属于当前 Cardify 账户")

    status = _transaction_status(transaction.expires_at, transaction.revoked_at)
    subscription = db.scalar(select(Subscription).where(Subscription.transaction_id == transaction.transaction_id))
    if subscription is not None and subscription.user_id != current_user.id:
        raise HTTPException(status_code=409, detail="该交易已绑定到其他 Cardify 账户")
    if subscription is None:
        subscription = Subscription(
            user_id=current_user.id,
            product_id=transaction.product_id,
            transaction_id=transaction.transaction_id,
        )
        db.add(subscription)

    subscription.product_id = transaction.product_id
    subscription.expires_at = transaction.expires_at
    subscription.status = status
    db.commit()

    subscriptions = list(
        db.scalars(
            select(Subscription)
            .where(Subscription.user_id == current_user.id)
            .order_by(Subscription.created_at.desc())
        )
    )
    return _membership_status(subscriptions)


def _membership_status(subscriptions: list[Subscription]) -> MembershipStatusOut:
    if not subscriptions:
        return MembershipStatusOut(is_pro=False, status="none")

    now = datetime.now(timezone.utc)
    active = [subscription for subscription in subscriptions if _is_active(subscription, now)]
    if active:
        selected = max(active, key=lambda subscription: _as_utc(subscription.expires_at) or datetime.max.replace(tzinfo=timezone.utc))
        return MembershipStatusOut(
            is_pro=True,
            status="active",
            product_id=selected.product_id,
            expires_at=selected.expires_at,
        )

    selected = subscriptions[0]
    status = "revoked" if selected.status == "revoked" else "expired"
    return MembershipStatusOut(
        is_pro=False,
        status=status,
        product_id=selected.product_id,
        expires_at=selected.expires_at,
    )


def _transaction_status(expires_at: datetime | None, revoked_at: datetime | None) -> str:
    if revoked_at is not None:
        return "revoked"
    if expires_at is not None and _as_utc(expires_at) <= datetime.now(timezone.utc):
        return "expired"
    return "active"


def _is_active(subscription: Subscription, now: datetime) -> bool:
    return subscription.status == "active" and (
        subscription.expires_at is None or _as_utc(subscription.expires_at) > now
    )


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
