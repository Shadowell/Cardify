import base64
import binascii
import re
from pathlib import Path


SAFE_NAME_RE = re.compile(r"[^a-zA-Z0-9._-]+")
ALLOWED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


class StorageError(ValueError):
    pass


class StorageService:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def save_base64_image(self, folder: str, filename: str, image_base64: str) -> str:
        safe_folder = self._safe_part(folder)
        safe_filename = self._safe_part(filename)
        if Path(safe_filename).suffix.lower() not in ALLOWED_EXTENSIONS:
            raise StorageError("unsupported image extension")

        payload = image_base64.split(",", 1)[1] if "," in image_base64 else image_base64
        try:
            image_bytes = base64.b64decode(payload, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise StorageError("invalid base64 image") from exc

        target_dir = (self.root / safe_folder).resolve()
        if not str(target_dir).startswith(str(self.root)):
            raise StorageError("invalid storage path")
        target_dir.mkdir(parents=True, exist_ok=True)

        target = (target_dir / safe_filename).resolve()
        if not str(target).startswith(str(self.root)):
            raise StorageError("invalid storage path")
        target.write_bytes(image_bytes)
        return str(target.relative_to(self.root))

    def delete(self, relative_path: str) -> None:
        target = (self.root / relative_path).resolve()
        if not str(target).startswith(str(self.root)):
            raise StorageError("invalid storage path")
        if target.exists() and target.is_file():
            target.unlink()

    def resolve_file(self, relative_path: str) -> Path:
        target = (self.root / relative_path).resolve()
        if not str(target).startswith(str(self.root)):
            raise StorageError("invalid storage path")
        if not target.is_file():
            raise StorageError("stored file was not found")
        return target

    def delete_tree(self, relative_folder: str) -> None:
        target = (self.root / self._safe_part(relative_folder)).resolve()
        if not str(target).startswith(str(self.root)):
            raise StorageError("invalid storage path")
        if target.exists() and target.is_dir():
            for child in sorted(target.rglob("*"), reverse=True):
                if child.is_file() or child.is_symlink():
                    child.unlink()
                elif child.is_dir():
                    child.rmdir()
            target.rmdir()

    @staticmethod
    def _safe_part(value: str) -> str:
        safe = SAFE_NAME_RE.sub("-", value.strip()).strip(".-/")
        if not safe or safe in {".", ".."}:
            raise StorageError("invalid file name")
        return safe
