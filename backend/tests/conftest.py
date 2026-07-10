import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"
os.environ["CARDIFY_STORAGE_ROOT"] = "./test-storage"

import pytest
from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.routers.auth import get_apple_identity_verifier
from app.services.apple_identity import AppleIdentity


@pytest.fixture(autouse=True)
def reset_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("CARDIFY_STORAGE_ROOT", str(tmp_path / "storage"))
    with TestClient(app) as test_client:
        yield test_client


class StubAppleIdentityVerifier:
    def verify(self, identity_token: str) -> AppleIdentity:
        assert identity_token == "test-apple-identity-token"
        return AppleIdentity(subject="apple-test-subject")


@pytest.fixture()
def authenticated_session(client):
    app.dependency_overrides[get_apple_identity_verifier] = StubAppleIdentityVerifier
    response = client.post(
        "/auth/apple/login",
        json={"identity_token": "test-apple-identity-token", "display_name": "Jie"},
    )
    assert response.status_code == 200
    payload = response.json()
    try:
        yield {
            "headers": {"Authorization": f"Bearer {payload['access_token']}"},
            "user_id": payload["user"]["id"],
        }
    finally:
        app.dependency_overrides.pop(get_apple_identity_verifier, None)
