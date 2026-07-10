import json
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from app.config import Settings
from app.services.apple_identity import AppleIdentityVerificationError, AppleIdentityVerifier


class LocalKeyCache:
    def __init__(self, key) -> None:
        self.key = key

    def get(self, key_id: str, url: str) -> dict:
        assert key_id == "local-key"
        return json.loads(RSAAlgorithm.to_jwk(self.key.public_key()))


def create_identity_token(private_key, audience: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": "apple-subject-123",
            "iss": "https://appleid.apple.com",
            "aud": audience,
            "iat": now,
            "exp": now + timedelta(minutes=5),
            "email": "person@example.com",
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "local-key"},
    )


def test_apple_identity_verifier_validates_signature_and_claims():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    settings = Settings(apple_client_id="com.jiefeng.cardify")
    verifier = AppleIdentityVerifier(settings, key_cache=LocalKeyCache(private_key))

    identity = verifier.verify(create_identity_token(private_key, settings.apple_client_id))

    assert identity.subject == "apple-subject-123"
    assert identity.email == "person@example.com"


def test_apple_identity_verifier_rejects_wrong_audience():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    verifier = AppleIdentityVerifier(Settings(apple_client_id="com.jiefeng.cardify"), key_cache=LocalKeyCache(private_key))

    with pytest.raises(AppleIdentityVerificationError):
        verifier.verify(create_identity_token(private_key, "another.bundle.id"))
