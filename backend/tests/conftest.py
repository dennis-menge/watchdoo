"""Pytest configuration and shared fixtures."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

# Patch settings before importing the app
with patch.dict("os.environ", {
    "COOKIDOO_EMAIL": "test@example.com",
    "COOKIDOO_PASSWORD": "testpassword",
    "API_KEY": "test-api-key-12345",
    "COOKIDOO_COUNTRY": "de",
    "COOKIDOO_LANGUAGE": "de-DE",
}):
    from app.main import app
    from app.services.cookidoo import cookidoo_service


VALID_API_KEY = "test-api-key-12345"
AUTH_HEADER = {"X-API-Key": VALID_API_KEY}


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    """Async HTTP client for testing FastAPI endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def mock_cookidoo():
    """Mock the global cookidoo_service with pre-configured return values."""
    with patch.object(cookidoo_service, "_ensure_session", new_callable=AsyncMock):
        with patch.object(cookidoo_service, "_logged_in", True):
            yield cookidoo_service
