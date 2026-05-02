"""Tests for the shopping list API endpoints."""

import pytest
from unittest.mock import AsyncMock, patch

from cookidoo_api.types import (
    CookidooAdditionalItem,
    CookidooIngredient,
    CookidooIngredientItem,
    CookidooShoppingRecipe,
)

from tests.conftest import AUTH_HEADER


# --- Test Data ---

SAMPLE_INGREDIENTS = [
    CookidooIngredientItem(
        id="ing-1",
        name="Butter",
        description="40g Butter",
        is_owned=False,
    ),
    CookidooIngredientItem(
        id="ing-2",
        name="Zucker",
        description="200g Zucker",
        is_owned=True,
    ),
]

SAMPLE_ADDITIONAL_ITEMS = [
    CookidooAdditionalItem(id="add-1", name="Milch", is_owned=False),
    CookidooAdditionalItem(id="add-2", name="Brot", is_owned=True),
]

SAMPLE_RECIPES = [
    CookidooShoppingRecipe(
        id="r59322",
        name="Kokos Pralinen",
        ingredients=[
            CookidooIngredient(id="ing-1", name="Butter", description="40g Butter"),
        ],
        thumbnail=None,
        image=None,
        url="https://cookidoo.de/recipes/r59322",
    ),
]


# --- GET /shopping-list ---

@pytest.mark.anyio
async def test_get_shopping_list_success(client, mock_cookidoo):
    """Should return the complete shopping list."""
    with (
        patch.object(mock_cookidoo, "get_ingredient_items", new_callable=AsyncMock, return_value=SAMPLE_INGREDIENTS),
        patch.object(mock_cookidoo, "get_additional_items", new_callable=AsyncMock, return_value=SAMPLE_ADDITIONAL_ITEMS),
        patch.object(mock_cookidoo, "get_shopping_list_recipes", new_callable=AsyncMock, return_value=SAMPLE_RECIPES),
    ):
        response = await client.get("/api/v1/shopping-list", headers=AUTH_HEADER)

    assert response.status_code == 200
    data = response.json()
    assert len(data["ingredients"]) == 2
    assert len(data["additional_items"]) == 2
    assert len(data["recipes"]) == 1
    assert data["ingredients"][0]["name"] == "Butter"
    assert data["ingredients"][0]["is_owned"] is False
    assert data["additional_items"][1]["name"] == "Brot"
    assert data["recipes"][0]["name"] == "Kokos Pralinen"


@pytest.mark.anyio
async def test_get_shopping_list_no_auth(client):
    """Should return 401 without API key."""
    response = await client.get("/api/v1/shopping-list")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_get_shopping_list_wrong_key(client):
    """Should return 403 with invalid API key."""
    response = await client.get(
        "/api/v1/shopping-list",
        headers={"X-API-Key": "wrong-key"},
    )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_get_shopping_list_cookidoo_error(client, mock_cookidoo):
    """Should return 502 when Cookidoo fails."""
    with patch.object(
        mock_cookidoo, "get_ingredient_items",
        new_callable=AsyncMock,
        side_effect=Exception("Connection failed"),
    ), patch.object(
        mock_cookidoo, "get_additional_items",
        new_callable=AsyncMock,
        side_effect=Exception("Connection failed"),
    ), patch.object(
        mock_cookidoo, "get_shopping_list_recipes",
        new_callable=AsyncMock,
        side_effect=Exception("Connection failed"),
    ):
        response = await client.get("/api/v1/shopping-list", headers=AUTH_HEADER)

    assert response.status_code == 502


# --- PATCH /shopping-list/ingredients ---

@pytest.mark.anyio
async def test_toggle_ingredient_ownership(client, mock_cookidoo):
    """Should toggle ingredient checked status."""
    toggled = [CookidooIngredientItem(id="ing-1", name="Butter", description="40g Butter", is_owned=True)]
    with patch.object(
        mock_cookidoo, "edit_ingredient_items_ownership",
        new_callable=AsyncMock,
        return_value=toggled,
    ):
        response = await client.patch(
            "/api/v1/shopping-list/ingredients",
            headers=AUTH_HEADER,
            json=[{"id": "ing-1", "is_owned": True}],
        )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["is_owned"] is True


# --- POST /shopping-list/additional-items ---

@pytest.mark.anyio
async def test_add_additional_items(client, mock_cookidoo):
    """Should add manually entered items."""
    new_items = [CookidooAdditionalItem(id="add-3", name="Eier", is_owned=False)]
    with patch.object(
        mock_cookidoo, "add_additional_items",
        new_callable=AsyncMock,
        return_value=new_items,
    ):
        response = await client.post(
            "/api/v1/shopping-list/additional-items",
            headers=AUTH_HEADER,
            json={"names": ["Eier"]},
        )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Eier"


# --- DELETE /shopping-list/additional-items/{id} ---

@pytest.mark.anyio
async def test_remove_additional_item(client, mock_cookidoo):
    """Should remove a manually added item."""
    with patch.object(
        mock_cookidoo, "remove_additional_items",
        new_callable=AsyncMock,
    ):
        response = await client.delete(
            "/api/v1/shopping-list/additional-items/add-1",
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


# --- DELETE /shopping-list/recipes/{recipe_id} ---

@pytest.mark.anyio
async def test_remove_recipe_ingredients(client, mock_cookidoo):
    """Should remove all ingredients of a recipe."""
    with patch.object(
        mock_cookidoo, "remove_ingredient_items_for_recipes",
        new_callable=AsyncMock,
    ):
        response = await client.delete(
            "/api/v1/shopping-list/recipes/r59322",
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


# --- PATCH /shopping-list/additional-items/ownership ---

@pytest.mark.anyio
async def test_toggle_additional_item_ownership(client, mock_cookidoo):
    """Should toggle additional item checked status."""
    toggled = [CookidooAdditionalItem(id="add-1", name="Milch", is_owned=True)]
    with patch.object(
        mock_cookidoo, "edit_additional_items_ownership",
        new_callable=AsyncMock,
        return_value=toggled,
    ):
        response = await client.patch(
            "/api/v1/shopping-list/additional-items/ownership",
            headers=AUTH_HEADER,
            json=[{"id": "add-1", "is_owned": True}],
        )

    assert response.status_code == 200
    assert response.json()[0]["is_owned"] is True
