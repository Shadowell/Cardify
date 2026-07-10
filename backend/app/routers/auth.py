from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models import User
from ..schemas import AppleLoginCreate, AuthSessionOut, UserOut
from ..services.apple_identity import AppleIdentityVerificationError, AppleIdentityVerifier
from ..services.session_auth import create_access_token

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
