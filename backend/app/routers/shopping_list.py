"""Shopping list API endpoints."""

import logging

from cookidoo_api.types import CookidooAdditionalItem, CookidooIngredientItem
from fastapi import APIRouter, Depends, HTTPException

from app.middleware import verify_api_key
from app.models import (
    AddAdditionalItemsRequest,
    AdditionalItemResponse,
    EditAdditionalItemRequest,
    EditItemOwnershipRequest,
    IngredientItemResponse,
    RemoveRecipeRequest,
    ShoppingListResponse,
    ShoppingRecipeResponse,
)
from app.services.cookidoo import cookidoo_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", dependencies=[Depends(verify_api_key)])


def _map_ingredient(item: CookidooIngredientItem) -> IngredientItemResponse:
    return IngredientItemResponse(
        id=item.id,
        name=item.name,
        description=item.description,
        is_owned=item.is_owned,
    )


def _map_additional(item: CookidooAdditionalItem) -> AdditionalItemResponse:
    return AdditionalItemResponse(
        id=item.id,
        name=item.name,
        is_owned=item.is_owned,
    )


@router.get("/shopping-list", response_model=ShoppingListResponse)
async def get_shopping_list():
    """Get the complete shopping list with ingredients, additional items, and recipes."""
    try:
        ingredients, additional_items, recipes = await _fetch_all()

        # Build lookup from flat ingredients (name+description) to get is_owned status
        ownership_lookup: dict[tuple[str, str], bool] = {}
        for i in ingredients:
            ownership_lookup[(i.name, i.description)] = i.is_owned

        return ShoppingListResponse(
            ingredients=[_map_ingredient(i) for i in ingredients],
            additional_items=[_map_additional(a) for a in additional_items],
            recipes=[
                ShoppingRecipeResponse(
                    id=r.id,
                    name=r.name,
                    ingredients=[
                        IngredientItemResponse(
                            id=ing.id,
                            name=ing.name,
                            description=ing.description,
                            is_owned=ownership_lookup.get(
                                (ing.name, ing.description), False
                            ),
                            recipe_id=r.id,
                            recipe_name=r.name,
                            shopping_category=None,
                        )
                        for ing in r.ingredients
                    ],
                )
                for r in recipes
            ],
        )
    except Exception as e:
        logger.exception("Failed to fetch shopping list")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


async def _fetch_all():
    """Fetch ingredients, additional items, and recipes concurrently."""
    import asyncio

    return await asyncio.gather(
        cookidoo_service.get_ingredient_items(),
        cookidoo_service.get_additional_items(),
        cookidoo_service.get_shopping_list_recipes(),
    )


@router.patch(
    "/shopping-list/ingredients",
    response_model=list[IngredientItemResponse],
)
async def edit_ingredient_ownership(items: list[EditItemOwnershipRequest]):
    """Toggle owned/checked status of ingredient items."""
    try:
        cookidoo_items = [
            CookidooIngredientItem(
                id=item.id,
                name="",
                description="",
                is_owned=item.is_owned,
            )
            for item in items
        ]
        result = await cookidoo_service.edit_ingredient_items_ownership(cookidoo_items)
        return [_map_ingredient(r) for r in result]
    except Exception as e:
        logger.exception("Failed to edit ingredient ownership")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.patch(
    "/shopping-list/additional-items/ownership",
    response_model=list[AdditionalItemResponse],
)
async def edit_additional_item_ownership(items: list[EditItemOwnershipRequest]):
    """Toggle owned/checked status of additional items."""
    try:
        cookidoo_items = [
            CookidooAdditionalItem(
                id=item.id,
                name="",
                is_owned=item.is_owned,
            )
            for item in items
        ]
        result = await cookidoo_service.edit_additional_items_ownership(cookidoo_items)
        return [_map_additional(r) for r in result]
    except Exception as e:
        logger.exception("Failed to edit additional item ownership")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.post(
    "/shopping-list/additional-items",
    response_model=list[AdditionalItemResponse],
)
async def add_additional_items(request: AddAdditionalItemsRequest):
    """Add manually entered items to the shopping list."""
    try:
        result = await cookidoo_service.add_additional_items(request.names)
        return [_map_additional(r) for r in result]
    except Exception as e:
        logger.exception("Failed to add additional items")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.put(
    "/shopping-list/additional-items",
    response_model=list[AdditionalItemResponse],
)
async def edit_additional_items(items: list[EditAdditionalItemRequest]):
    """Edit additional items (rename, toggle ownership)."""
    try:
        cookidoo_items = [
            CookidooAdditionalItem(
                id=item.id,
                name=item.name,
                is_owned=item.is_owned,
            )
            for item in items
        ]
        result = await cookidoo_service.edit_additional_items(cookidoo_items)
        return [_map_additional(r) for r in result]
    except Exception as e:
        logger.exception("Failed to edit additional items")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.delete("/shopping-list/additional-items/{item_id}")
async def remove_additional_item(item_id: str):
    """Remove a manually added item from the shopping list."""
    try:
        await cookidoo_service.remove_additional_items([item_id])
        return {"status": "ok"}
    except Exception as e:
        logger.exception("Failed to remove additional item")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.delete("/shopping-list/recipes/{recipe_id}")
async def remove_recipe_ingredients(recipe_id: str):
    """Remove all ingredients for a recipe from the shopping list."""
    try:
        await cookidoo_service.remove_ingredient_items_for_recipes([recipe_id])
        return {"status": "ok"}
    except Exception as e:
        logger.exception("Failed to remove recipe ingredients")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e
