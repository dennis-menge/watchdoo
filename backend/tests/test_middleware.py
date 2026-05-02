"""Tests for the API key middleware."""

import pytest

from tests.conftest import AUTH_HEADER


@pytest.mark.anyio
async def test_valid_api_key(client):
    """Valid API key should be accepted."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200


@pytest.mark.anyio
async def test_missing_api_key(client):
    """Missing API key should return 401 on protected endpoints."""
    response = await client.get("/api/v1/shopping-list")
    assert response.status_code == 401
    assert "Missing" in response.json()["detail"]


@pytest.mark.anyio
async def test_invalid_api_key(client):
    """Wrong API key should return 403."""
    response = await client.get(
        "/api/v1/shopping-list",
        headers={"X-API-Key": "invalid-key"},
    )
    assert response.status_code == 403
    assert "Invalid" in response.json()["detail"]


@pytest.mark.anyio
async def test_empty_api_key(client):
    """Empty API key should be rejected (treated as missing)."""
    response = await client.get(
        "/api/v1/shopping-list",
        headers={"X-API-Key": ""},
    )
    assert response.status_code in (401, 403)
