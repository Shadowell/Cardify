from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from ..config import Settings, get_settings
from ..database import get_db
from ..models import User


def create_access_token(user: User, settings: Settings) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": user.id,
            "iss": settings.session_jwt_issuer,
            "iat": now,
            "exp": now + timedelta(days=settings.session_ttl_days),
        },
        settings.session_jwt_secret,
        algorithm="HS256",
    )


def get_current_user(
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db),
) -> User:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="authentication required")

    token = authorization.removeprefix("Bearer ").strip()
    try:
        claims = jwt.decode(
            token,
            get_settings().session_jwt_secret,
            algorithms=["HS256"],
            issuer=get_settings().session_jwt_issuer,
            options={"require": ["exp", "iat", "sub"]},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid session") from exc

    user = db.get(User, claims["sub"])
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="user not found")
    return user
