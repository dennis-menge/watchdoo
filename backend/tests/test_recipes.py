"""Tests for the recipe endpoints (adding whole dishes, search, details, collections)."""

import pytest
from unittest.mock import AsyncMock, patch

from cookidoo_api.types import (
    CookidooChapter,
    CookidooChapterRecipe,
    CookidooCollection,
    CookidooIngredient,
    CookidooIngredientItem,
    CookidooShoppingRecipe,
    CookidooShoppingRecipeDetails,
)

from tests.conftest import AUTH_HEADER


# --- Test Data ---

LASAGNE_INGREDIENT_ITEMS = [
    CookidooIngredientItem(
        id="item-1", name="Parmesan", description="130 g", is_owned=False
    ),
    CookidooIngredientItem(
        id="item-2", name="Möhren", description="200 g", is_owned=False
    ),
]

LASAGNE_ON_LIST = CookidooShoppingRecipe(
    id="r364443",
    name="Lasagne",
    ingredients=[
        CookidooIngredient(id="i-1", name="Parmesan", description="130 g"),
        CookidooIngredient(id="i-2", name="Möhren", description="200 g"),
    ],
    thumbnail=None,
    image=None,
    url="https://cookidoo.de/recipes/r364443",
)

SEARCH_HITS = [
    {
        "id": "r364443",
        "title": "Lasagne",
        "rating": 4.786682055399438,
        "numberOfRatings": 19928,
        "totalTime": 7200,
        "image": "https://assets.tmecosys.com/image/upload/{transformation}/img/a",
    },
    {
        "id": "r47865",
        "title": "Lasagne Bolognese",
        "rating": 4.25,
        "numberOfRatings": 2290,
        "totalTime": 9000,
        "image": None,
    },
]

RECIPE_DETAILS = CookidooShoppingRecipeDetails(
    id="r364443",
    name="Lasagne",
    ingredients=[CookidooIngredient(id="i-1", name="Parmesan", description="130 g")],
    thumbnail=None,
    image="https://example.invalid/lasagne.jpg",
    url="https://cookidoo.de/recipes/r364443",
    difficulty="medium",
    notes=[],
    categories=[],
    collections=[],
    utensils=[],
    serving_size=6,
    active_time=1800,
    total_time=7200,
    nutrition_groups=[],
)

CUSTOM_COLLECTIONS = [
    CookidooCollection(
        id="col-1",
        name="Mealprep",
        description="Wochenplanung",
        chapters=[
            CookidooChapter(
                name="Rezepte",
                recipes=[
                    CookidooChapterRecipe(
                        id="r364443", name="Lasagne", total_time=7200
                    ),
                    CookidooChapterRecipe(
                        id="r47865", name="Chili", total_time=1200
                    ),
                ],
            )
        ],
    )
]

MANAGED_COLLECTIONS = [
    CookidooCollection(
        id="col-2",
        name="Schnelle Küche",
        description=None,
        chapters=[
            CookidooChapter(
                name="Unter 20 Minuten",
                recipes=[
                    CookidooChapterRecipe(id="r99", name="Pesto", total_time=900)
                ],
            )
        ],
    )
]


# --- POST /shopping-list/recipes ---

@pytest.mark.anyio
async def test_add_recipes_success(client, mock_cookidoo):
    """Should add a recipe and enrich the ingredients with recipe info."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            side_effect=[[], [LASAGNE_ON_LIST]],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_recipes",
            new_callable=AsyncMock,
            return_value=LASAGNE_INGREDIENT_ITEMS,
        ) as add_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443"]},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    data = response.json()
    assert data["added_recipe_ids"] == ["r364443"]
    assert data["skipped_recipe_ids"] == []
    assert len(data["added_ingredients"]) == 2
    assert data["added_ingredients"][0]["name"] == "Parmesan"
    assert data["added_ingredients"][0]["recipe_id"] == "r364443"
    assert data["added_ingredients"][0]["recipe_name"] == "Lasagne"
    add_mock.assert_awaited_once_with(["r364443"])


@pytest.mark.anyio
async def test_add_recipes_skips_duplicates_by_default(client, mock_cookidoo):
    """Cookidoo does not deduplicate, so an already-present recipe is skipped."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            return_value=[LASAGNE_ON_LIST],
        ),
        patch.object(
            mock_cookidoo, "add_ingredient_items_for_recipes", new_callable=AsyncMock
        ) as add_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443"]},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    data = response.json()
    assert data["added_recipe_ids"] == []
    assert data["skipped_recipe_ids"] == ["r364443"]
    assert data["added_ingredients"] == []
    add_mock.assert_not_awaited()


@pytest.mark.anyio
async def test_add_recipes_allow_duplicates(client, mock_cookidoo):
    """allow_duplicates should add the recipe a second time (double portion)."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            return_value=[LASAGNE_ON_LIST],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_recipes",
            new_callable=AsyncMock,
            return_value=LASAGNE_INGREDIENT_ITEMS,
        ) as add_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443"], "allow_duplicates": True},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert response.json()["added_recipe_ids"] == ["r364443"]
    add_mock.assert_awaited_once_with(["r364443"])


@pytest.mark.anyio
async def test_add_recipes_skips_repeats_within_one_batch(client, mock_cookidoo):
    """A repeat inside the same request must not become a second way to double up."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            side_effect=[[], [LASAGNE_ON_LIST]],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_recipes",
            new_callable=AsyncMock,
            return_value=LASAGNE_INGREDIENT_ITEMS,
        ) as add_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443", "r364443"]},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    data = response.json()
    assert data["added_recipe_ids"] == ["r364443"]
    assert data["skipped_recipe_ids"] == ["r364443"]
    add_mock.assert_awaited_once_with(["r364443"])


@pytest.mark.anyio
async def test_add_recipes_allow_duplicates_keeps_repeats(client, mock_cookidoo):
    """allow_duplicates should pass a repeated id straight through."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            return_value=[LASAGNE_ON_LIST],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_recipes",
            new_callable=AsyncMock,
            return_value=LASAGNE_INGREDIENT_ITEMS,
        ) as add_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443", "r364443"], "allow_duplicates": True},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert response.json()["added_recipe_ids"] == ["r364443", "r364443"]
    add_mock.assert_awaited_once_with(["r364443", "r364443"])


@pytest.mark.anyio
async def test_add_recipes_custom_uses_custom_endpoint(client, mock_cookidoo):
    """custom=True must route to the separate custom-recipe endpoint."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            return_value=[],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_custom_recipes",
            new_callable=AsyncMock,
            return_value=LASAGNE_INGREDIENT_ITEMS,
        ) as custom_mock,
        patch.object(
            mock_cookidoo, "add_ingredient_items_for_recipes", new_callable=AsyncMock
        ) as normal_mock,
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["c-1"], "custom": True},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    custom_mock.assert_awaited_once_with(["c-1"])
    normal_mock.assert_not_awaited()


@pytest.mark.anyio
async def test_add_recipes_cookidoo_error(client, mock_cookidoo):
    """Should return 502 when Cookidoo fails."""
    with (
        patch.object(
            mock_cookidoo,
            "get_shopping_list_recipes",
            new_callable=AsyncMock,
            return_value=[],
        ),
        patch.object(
            mock_cookidoo,
            "add_ingredient_items_for_recipes",
            new_callable=AsyncMock,
            side_effect=Exception("Connection failed"),
        ),
    ):
        response = await client.post(
            "/api/v1/shopping-list/recipes",
            json={"recipe_ids": ["r364443"]},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 502


@pytest.mark.anyio
async def test_add_recipes_no_auth(client):
    """Should return 401 without API key."""
    response = await client.post(
        "/api/v1/shopping-list/recipes", json={"recipe_ids": ["r364443"]}
    )
    assert response.status_code == 401


# --- GET /recipes/search ---

@pytest.mark.anyio
async def test_search_recipes_success(client, mock_cookidoo):
    """Should map the raw Cookidoo search payload onto the API model."""
    with patch.object(
        mock_cookidoo, "search_recipes", new_callable=AsyncMock, return_value=SEARCH_HITS
    ) as search_mock:
        response = await client.get(
            "/api/v1/recipes/search", params={"q": "lasagne"}, headers=AUTH_HEADER
        )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["id"] == "r364443"
    assert data[0]["name"] == "Lasagne"
    assert data[0]["number_of_ratings"] == 19928
    assert data[0]["total_time"] == 7200
    search_mock.assert_awaited_once_with("lasagne", page=0)


@pytest.mark.anyio
async def test_search_recipes_respects_limit(client, mock_cookidoo):
    """limit should truncate the result set."""
    with patch.object(
        mock_cookidoo, "search_recipes", new_callable=AsyncMock, return_value=SEARCH_HITS
    ):
        response = await client.get(
            "/api/v1/recipes/search",
            params={"q": "lasagne", "limit": 1},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert len(response.json()) == 1


@pytest.mark.anyio
async def test_search_recipes_requires_query(client, mock_cookidoo):
    """Should reject a missing search term."""
    response = await client.get("/api/v1/recipes/search", headers=AUTH_HEADER)
    assert response.status_code == 422


@pytest.mark.anyio
async def test_search_recipes_cookidoo_error(client, mock_cookidoo):
    """Should return 502 when the undocumented search endpoint fails."""
    with patch.object(
        mock_cookidoo,
        "search_recipes",
        new_callable=AsyncMock,
        side_effect=Exception("Gone"),
    ):
        response = await client.get(
            "/api/v1/recipes/search", params={"q": "lasagne"}, headers=AUTH_HEADER
        )

    assert response.status_code == 502


# --- GET /recipes/{recipe_id} ---

@pytest.mark.anyio
async def test_get_recipe_details(client, mock_cookidoo):
    """Should return recipe metadata."""
    with patch.object(
        mock_cookidoo,
        "get_recipe_details",
        new_callable=AsyncMock,
        return_value=RECIPE_DETAILS,
    ):
        response = await client.get("/api/v1/recipes/r364443", headers=AUTH_HEADER)

    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Lasagne"
    assert data["total_time"] == 7200
    assert data["serving_size"] == 6
    assert data["difficulty"] == "medium"
    assert len(data["ingredients"]) == 1


@pytest.mark.anyio
async def test_get_recipe_details_cookidoo_error(client, mock_cookidoo):
    """Should return 502 when Cookidoo fails."""
    with patch.object(
        mock_cookidoo,
        "get_recipe_details",
        new_callable=AsyncMock,
        side_effect=Exception("Not found"),
    ):
        response = await client.get("/api/v1/recipes/r000", headers=AUTH_HEADER)

    assert response.status_code == 502


# --- GET /recipes/collections ---

@pytest.mark.anyio
async def test_get_collections_flattens_chapters(client, mock_cookidoo):
    """Should flatten chapter recipes and mark custom vs. managed collections."""
    with (
        patch.object(
            mock_cookidoo,
            "get_custom_collections",
            new_callable=AsyncMock,
            return_value=CUSTOM_COLLECTIONS,
        ),
        patch.object(
            mock_cookidoo,
            "get_managed_collections",
            new_callable=AsyncMock,
            return_value=MANAGED_COLLECTIONS,
        ),
    ):
        response = await client.get("/api/v1/recipes/collections", headers=AUTH_HEADER)

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["name"] == "Mealprep"
    assert data[0]["is_custom"] is True
    assert [r["id"] for r in data[0]["recipes"]] == ["r364443", "r47865"]
    assert data[1]["is_custom"] is False
    assert data[1]["recipes"][0]["total_time"] == 900


@pytest.mark.anyio
async def test_get_collections_custom_only(client, mock_cookidoo):
    """include_managed=false should skip the managed collections call."""
    with (
        patch.object(
            mock_cookidoo,
            "get_custom_collections",
            new_callable=AsyncMock,
            return_value=CUSTOM_COLLECTIONS,
        ),
        patch.object(
            mock_cookidoo, "get_managed_collections", new_callable=AsyncMock
        ) as managed_mock,
    ):
        response = await client.get(
            "/api/v1/recipes/collections",
            params={"include_managed": "false"},
            headers=AUTH_HEADER,
        )

    assert response.status_code == 200
    assert len(response.json()) == 1
    managed_mock.assert_not_awaited()
