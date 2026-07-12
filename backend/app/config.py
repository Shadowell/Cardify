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
    app_store_bundle_id: str = Field(default="com.jiefeng.cardify", alias="APP_STORE_BUNDLE_ID")
    app_store_apple_id: int | None = Field(default=None, alias="APP_STORE_APPLE_ID")
    app_store_root_certificates_path: Path | None = Field(default=None, alias="APP_STORE_ROOT_CERTIFICATES_PATH")
    app_store_enable_online_checks: bool = Field(default=True, alias="APP_STORE_ENABLE_ONLINE_CHECKS")
    app_store_product_ids: str = Field(
        default="com.jiefeng.cardify.pro.monthly,com.jiefeng.cardify.pro.yearly",
        alias="APP_STORE_PRODUCT_IDS",
    )
    allow_local_storekit_testing: bool = Field(default=False, alias="ALLOW_LOCAL_STOREKIT_TESTING")
    legal_contact_email: str = Field(default="support@notenap.com", alias="LEGAL_CONTACT_EMAIL")
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

    @property
    def resolved_app_store_root_certificates_path(self) -> Path | None:
        if self.app_store_root_certificates_path is None:
            return None
        path = self.app_store_root_certificates_path
        return path if path.is_absolute() else Path(__file__).resolve().parents[1] / path

    @property
    def allowed_app_store_product_ids(self) -> set[str]:
        return {product_id.strip() for product_id in self.app_store_product_ids.split(",") if product_id.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()
