from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .database import SessionLocal, init_db
from .routers import auth, generations, subscriptions, templates, works
from .services.templates import seed_templates


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    db = SessionLocal()
    try:
        seed_templates(db)
    finally:
        db.close()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    settings.resolved_storage_root.mkdir(parents=True, exist_ok=True)
    app.mount("/storage", StaticFiles(directory=settings.resolved_storage_root), name="storage")

    app.include_router(auth.router)
    app.include_router(templates.router)
    app.include_router(generations.router)
    app.include_router(works.router)
    app.include_router(subscriptions.router)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
