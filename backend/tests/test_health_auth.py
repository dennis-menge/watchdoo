"""Tests for health and auth endpoints."""

import pytest
from unittest.mock import AsyncMock, patch

from tests.conftest import AUTH_HEADER


@pytest.mark.anyio
async def test_health_check(client):
    """Health endpoint should work without auth."""
    with patch("app.main.cookidoo_service.login", new_callable=AsyncMock):
        response = await client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["cookidoo_connected"] is True


@pytest.mark.anyio
async def test_health_reports_upstream_failure_without_real_login(client):
    with patch("app.main.cookidoo_service.login", new_callable=AsyncMock,
               side_effect=RuntimeError("upstream unavailable")):
        response = await client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "cookidoo_connected": False}


@pytest.mark.anyio
async def test_auth_refresh(client, mock_cookidoo):
    """Should trigger a token refresh."""
    with patch.object(mock_cookidoo, "refresh_token", new_callable=AsyncMock):
        response = await client.post("/api/v1/auth/refresh", headers=AUTH_HEADER)

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.anyio
async def test_auth_refresh_no_key(client):
    """Token refresh should require auth."""
    response = await client.post("/api/v1/auth/refresh")
    assert response.status_code == 401
