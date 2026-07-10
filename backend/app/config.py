from functools import lru_cache
from pathlib import Path

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Cardify API"
    environment: str = "local"
    database_url: str = Field(
        default="postgresql+psycopg://cardify:cardify@localhost:5432/cardify",
        alias="DATABASE_URL",
    )
    storage_root: Path = Field(default=Path("storage"), alias="CARDIFY_STORAGE_ROOT")
    apple_client_id: str = Field(default="com.jiefeng.cardify", alias="APPLE_CLIENT_ID")
    apple_jwks_url: str = Field(default="https://appleid.apple.com/auth/keys", alias="APPLE_JWKS_URL")
    session_jwt_secret: str = Field(default="cardify-local-development-secret-change-before-release", alias="SESSION_JWT_SECRET")
    session_jwt_issuer: str = Field(default="cardify-api", alias="SESSION_JWT_ISSUER")
    session_ttl_days: int = Field(default=30, alias="SESSION_TTL_DAYS")
    cors_origins: list[str] = Field(default_factory=lambda: ["http://127.0.0.1:5173"])

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    @model_validator(mode="after")
    def validate_session_secret(self) -> "Settings":
        default_secret = "cardify-local-development-secret-change-before-release"
        if self.environment not in {"local", "test"} and (
            self.session_jwt_secret == default_secret or len(self.session_jwt_secret) < 32
        ):
            raise ValueError("SESSION_JWT_SECRET must be a non-default secret with at least 32 characters")
        return self

    @property
    def resolved_storage_root(self) -> Path:
        return self.storage_root if self.storage_root.is_absolute() else Path(__file__).resolve().parents[1] / self.storage_root


@lru_cache
def get_settings() -> Settings:
    return Settings()
