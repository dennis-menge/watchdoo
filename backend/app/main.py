"""Watchdoo – FastAPI Backend."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import settings
from app.models import HealthResponse
from app.routers import auth, shopping_list
from app.services.cookidoo import cookidoo_service

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)8s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle – login on startup, cleanup on shutdown."""
    logger.info("Watchdoo backend starting up")
    try:
        await cookidoo_service.login()
        logger.info("Cookidoo session ready")
    except Exception:
        logger.exception("Cookidoo login failed at startup – will retry on first request")
    yield
    logger.info("Shutting down, closing Cookidoo session")
    await cookidoo_service.close()


app = FastAPI(
    title="Watchdoo API",
    description="Self-hosted backend bridging Apple Watch to Cookidoo",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(shopping_list.router)
app.include_router(auth.router)


@app.get("/api/v1/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint (no auth required).

    Attempts to ensure a valid Cookidoo session so the reported status
    reflects reality rather than a potentially stale in-memory flag.
    On cold-start (before any login), this will trigger the OAuth2 flow.
    If already logged in, this is a cheap no-op.
    """
    try:
        await cookidoo_service.login()
        connected = True
    except Exception:
        connected = False
    return HealthResponse(status="ok", cookidoo_connected=connected)
