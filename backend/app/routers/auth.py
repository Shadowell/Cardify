from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models import Subscription, User, Work
from ..schemas import AppleLoginCreate, AuthSessionOut, UserOut
from ..services.apple_identity import AppleIdentityVerificationError, AppleIdentityVerifier
from ..services.session_auth import create_access_token, get_current_user
from ..services.storage import StorageService

router = APIRouter(prefix="/auth", tags=["auth"])


def get_apple_identity_verifier() -> AppleIdentityVerifier:
    return AppleIdentityVerifier(get_settings())


@router.post("/apple/login", response_model=AuthSessionOut)
def apple_login(
    payload: AppleLoginCreate,
    db: Session = Depends(get_db),
    verifier: AppleIdentityVerifier = Depends(get_apple_identity_verifier),
) -> AuthSessionOut:
    settings = get_settings()
    try:
        apple_identity = verifier.verify(payload.identity_token)
    except AppleIdentityVerificationError as exc:
        raise HTTPException(status_code=401, detail="Apple identity could not be verified") from exc

    user = db.scalar(select(User).where(User.apple_subject == apple_identity.subject))
    if user is None:
        user = User(apple_subject=apple_identity.subject, display_name=payload.display_name)
        db.add(user)
    elif payload.display_name:
        user.display_name = payload.display_name
    db.commit()
    db.refresh(user)
    return AuthSessionOut(
        user=UserOut.model_validate(user),
        access_token=create_access_token(user, settings),
    )


@router.delete("/me")
def delete_current_account(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, str]:
    """Permanently remove a signed-in user's cloud account and its stored creations."""
    user_id = current_user.id
    work_ids = list(db.scalars(select(Work.id).where(Work.user_id == user_id)))

    for subscription in db.scalars(select(Subscription).where(Subscription.user_id == user_id)):
        db.delete(subscription)
    for work in db.scalars(select(Work).where(Work.user_id == user_id)):
        db.delete(work)
    db.delete(current_user)
    db.commit()

    storage = StorageService(get_settings().resolved_storage_root)
    for work_id in work_ids:
        storage.delete_tree(f"works/{work_id}")

    return {"deleted": user_id}
