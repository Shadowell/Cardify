from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from ..config import Settings


class StoreKitVerificationError(Exception):
    """Raised when a StoreKit transaction cannot establish an entitlement."""


class StoreKitVerificationUnavailable(StoreKitVerificationError):
    """Raised when server-side App Store verification has not been configured."""


@dataclass(frozen=True)
class VerifiedStoreKitTransaction:
    transaction_id: str
    product_id: str
    app_account_token: str | None
    expires_at: datetime | None
    revoked_at: datetime | None


class StoreKitTransactionVerifier:
    def __init__(self, settings: Settings):
        self.settings = settings

    def verify(self, signed_transaction_info: str) -> VerifiedStoreKitTransaction:
        verification_errors: list[Exception] = []
        for verifier in self._verifiers():
            try:
                transaction = verifier.verify_and_decode_signed_transaction(signed_transaction_info)
                if not transaction.transactionId or not transaction.productId:
                    raise StoreKitVerificationError("Apple transaction is missing a transaction or product identifier")
                if transaction.productId not in self.settings.allowed_app_store_product_ids:
                    raise StoreKitVerificationError("Apple transaction contains an unsupported product")
                return VerifiedStoreKitTransaction(
                    transaction_id=transaction.transactionId,
                    product_id=transaction.productId,
                    app_account_token=transaction.appAccountToken,
                    expires_at=_milliseconds_to_datetime(transaction.expiresDate),
                    revoked_at=_milliseconds_to_datetime(transaction.revocationDate),
                )
            except VerificationException as exc:
                verification_errors.append(exc)

        if verification_errors:
            raise StoreKitVerificationError("Apple could not verify this transaction") from verification_errors[-1]
        raise StoreKitVerificationUnavailable(
            "StoreKit server verification is not configured. Configure Apple root certificates before enabling purchases."
        )

    def _verifiers(self) -> list[SignedDataVerifier]:
        if self.settings.environment in {"local", "test"} and self.settings.allow_local_storekit_testing:
            return [
                SignedDataVerifier(
                    [],
                    False,
                    Environment.XCODE,
                    self.settings.app_store_bundle_id,
                )
            ]

        root_certificates = _load_root_certificates(self.settings.resolved_app_store_root_certificates_path)
        if not root_certificates:
            return []

        verifiers = [
            SignedDataVerifier(
                root_certificates,
                self.settings.app_store_enable_online_checks,
                Environment.SANDBOX,
                self.settings.app_store_bundle_id,
            )
        ]
        if self.settings.app_store_apple_id is not None:
            verifiers.insert(
                0,
                SignedDataVerifier(
                    root_certificates,
                    self.settings.app_store_enable_online_checks,
                    Environment.PRODUCTION,
                    self.settings.app_store_bundle_id,
                    self.settings.app_store_apple_id,
                ),
            )
        return verifiers


def _load_root_certificates(path: Path | None) -> list[bytes]:
    if path is None or not path.is_dir():
        return []
    return [certificate.read_bytes() for certificate in sorted(path.glob("*.cer")) if certificate.is_file()]


def _milliseconds_to_datetime(value: int | None) -> datetime | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000, tz=timezone.utc)
