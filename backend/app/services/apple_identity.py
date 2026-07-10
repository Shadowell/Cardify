import json
import threading
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.request import urlopen

import jwt

from ..config import Settings


APPLE_ISSUER = "https://appleid.apple.com"
ALLOWED_ALGORITHMS = {"RS256", "ES256"}


class AppleIdentityVerificationError(ValueError):
    pass


@dataclass(frozen=True)
class AppleIdentity:
    subject: str
    email: str | None = None


class AppleJWKSCache:
    def __init__(self) -> None:
        self._keys: dict[str, dict] = {}
        self._expires_at = datetime.min.replace(tzinfo=timezone.utc)
        self._lock = threading.Lock()

    def get(self, key_id: str, url: str) -> dict:
        with self._lock:
            now = datetime.now(timezone.utc)
            if now >= self._expires_at or key_id not in self._keys:
                self._refresh(url)
            key = self._keys.get(key_id)
            if key is None:
                raise AppleIdentityVerificationError("Apple signing key was not found")
            return key

    def _refresh(self, url: str) -> None:
        try:
            with urlopen(url, timeout=5) as response:  # noqa: S310 - URL comes from application configuration.
                payload = json.load(response)
        except OSError as exc:
            raise AppleIdentityVerificationError("Apple signing keys are unavailable") from exc

        keys = payload.get("keys", [])
        self._keys = {item["kid"]: item for item in keys if isinstance(item, dict) and item.get("kid")}
        self._expires_at = datetime.now(timezone.utc) + timedelta(hours=12)


APPLE_JWKS = AppleJWKSCache()


class AppleIdentityVerifier:
    def __init__(self, settings: Settings, key_cache: AppleJWKSCache = APPLE_JWKS) -> None:
        self.settings = settings
        self.key_cache = key_cache

    def verify(self, identity_token: str) -> AppleIdentity:
        try:
            header = jwt.get_unverified_header(identity_token)
            algorithm = header.get("alg")
            key_id = header.get("kid")
            if algorithm not in ALLOWED_ALGORITHMS or not isinstance(key_id, str):
                raise AppleIdentityVerificationError("Unsupported Apple identity token")

            signing_key = jwt.PyJWK.from_dict(self.key_cache.get(key_id, self.settings.apple_jwks_url)).key
            claims = jwt.decode(
                identity_token,
                signing_key,
                algorithms=[algorithm],
                audience=self.settings.apple_client_id,
                issuer=APPLE_ISSUER,
                options={"require": ["exp", "iat", "sub"]},
                leeway=60,
            )
        except (jwt.PyJWTError, AppleIdentityVerificationError, ValueError) as exc:
            if isinstance(exc, AppleIdentityVerificationError):
                raise
            raise AppleIdentityVerificationError("Invalid Apple identity token") from exc

        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject:
            raise AppleIdentityVerificationError("Apple identity token has no subject")
        email = claims.get("email")
        return AppleIdentity(subject=subject, email=email if isinstance(email, str) else None)
