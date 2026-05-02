"""Auth-related API endpoints."""

import logging

from fastapi import APIRouter, Depends, HTTPException

from app.middleware import verify_api_key
from app.services.cookidoo import cookidoo_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", dependencies=[Depends(verify_api_key)])


@router.post("/auth/refresh")
async def refresh_token():
    """Manually trigger a Cookidoo token refresh."""
    try:
        await cookidoo_service.refresh_token()
        return {"status": "ok"}
    except Exception as e:
        logger.exception("Failed to refresh token")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e
