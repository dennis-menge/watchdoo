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
    """Manage application lifecycle – cleanup on shutdown."""
    logger.info("Watchdoo backend starting up")
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
    """Health check endpoint (no auth required)."""
    connected = cookidoo_service._logged_in
    return HealthResponse(status="ok", cookidoo_connected=connected)
