"""Shopping list API endpoints."""

import logging
from collections import defaultdict
from typing import Any

from cookidoo_api.types import CookidooAdditionalItem, CookidooIngredientItem
from fastapi import APIRouter, Depends, HTTPException, Query

from app.middleware import verify_api_key
from app.models import (
    AddAdditionalItemsRequest,
    AdditionalItemResponse,
    AddRecipesRequest,
    AddRecipesResponse,
    CollectionRecipeResponse,
    CollectionResponse,
    EditAdditionalItemRequest,
    EditItemOwnershipRequest,
    IngredientItemResponse,
    RecipeDetailsResponse,
    RecipeIngredientResponse,
    RecipeSearchResultResponse,
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


def _map_search_result(hit: dict[str, Any]) -> RecipeSearchResultResponse:
    return RecipeSearchResultResponse(
        id=hit["id"],
        name=hit.get("title", ""),
        rating=hit.get("rating"),
        number_of_ratings=hit.get("numberOfRatings"),
        total_time=hit.get("totalTime"),
        image=hit.get("image"),
    )


def _map_collection(collection, *, is_custom: bool) -> CollectionResponse:
    return CollectionResponse(
        id=collection.id,
        name=collection.name,
        description=collection.description,
        is_custom=is_custom,
        recipes=[
            CollectionRecipeResponse(
                id=recipe.id, name=recipe.name, total_time=recipe.total_time
            )
            for chapter in collection.chapters
            for recipe in chapter.recipes
        ],
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
    """Remove all ingredients for a recipe from the shopping list.

    If the same recipe was added more than once, this removes every copy.
    """
    try:
        await cookidoo_service.remove_ingredient_items_for_recipes([recipe_id])
        return {"status": "ok"}
    except Exception as e:
        logger.exception("Failed to remove recipe ingredients")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.post("/shopping-list/recipes", response_model=AddRecipesResponse)
async def add_recipes(request: AddRecipesRequest):
    """Put whole dishes on the shopping list.

    The counterpart to ``DELETE /shopping-list/recipes/{recipe_id}``. Cookidoo
    supplies ingredients, quantities and the recipe association itself, so the
    existing recipe grouping and removal work with this automatically.

    Cookidoo does **not** deduplicate: adding the same recipe twice puts every
    ingredient on the list twice (verified against the live API). That is the
    only way to shop for a double portion, so it stays available behind
    ``allow_duplicates`` — which is the single, deliberate way to ask for it.
    Otherwise a recipe is skipped when it is already on the list *or* repeated
    within the same request, and reported in ``skipped_recipe_ids``.
    """
    try:
        recipe_ids = request.recipe_ids
        skipped: list[str] = []

        if not request.allow_duplicates:
            # Seed with what is already on the list, then keep adding as we go so
            # a repeat *within* the same batch is caught too. Otherwise
            # {"recipe_ids": ["rA", "rA"]} would be a second, accidental way to
            # double a portion.
            seen = {r.id for r in await cookidoo_service.get_shopping_list_recipes()}
            unique_ids: list[str] = []
            for recipe_id in recipe_ids:
                if recipe_id in seen:
                    skipped.append(recipe_id)
                else:
                    seen.add(recipe_id)
                    unique_ids.append(recipe_id)
            recipe_ids = unique_ids

        if not recipe_ids:
            return AddRecipesResponse(
                added_recipe_ids=[], skipped_recipe_ids=skipped, added_ingredients=[]
            )

        if request.custom:
            added = await cookidoo_service.add_ingredient_items_for_custom_recipes(
                recipe_ids
            )
        else:
            added = await cookidoo_service.add_ingredient_items_for_recipes(recipe_ids)

        # The library drops the recipe association while parsing the add
        # response, so re-read the list to attach recipe_id/recipe_name.
        #
        # Matching has to go through (name, description): the add response and
        # the recipe groups use different id namespaces (shopping-list item
        # ULIDs vs. catalogue ids like "com.vorwerk.ingredients.Ingredient-rpf-10"),
        # so there is nothing to join on directly.
        #
        # That key is not unique across recipes - two dishes can both call for
        # "Lasagneplatten"/"250 g". Collect every candidate and only enrich when
        # exactly one recipe claims the ingredient; otherwise leave the fields
        # unset rather than guessing a wrong recipe.
        recipe_candidates: dict[tuple[str, str], set[tuple[str, str]]] = defaultdict(
            set
        )
        try:
            for recipe in await cookidoo_service.get_shopping_list_recipes():
                if recipe.id not in recipe_ids:
                    continue
                for ingredient in recipe.ingredients:
                    recipe_candidates[(ingredient.name, ingredient.description)].add(
                        (recipe.id, recipe.name)
                    )
        except Exception:
            logger.warning(
                "Could not enrich added ingredients with recipe info", exc_info=True
            )

        added_ingredients = []
        for item in added:
            owners = recipe_candidates.get((item.name, item.description), set())
            recipe_id, recipe_name = (
                next(iter(owners)) if len(owners) == 1 else (None, None)
            )
            added_ingredients.append(
                IngredientItemResponse(
                    id=item.id,
                    name=item.name,
                    description=item.description,
                    is_owned=item.is_owned,
                    recipe_id=recipe_id,
                    recipe_name=recipe_name,
                )
            )

        return AddRecipesResponse(
            added_recipe_ids=recipe_ids,
            skipped_recipe_ids=skipped,
            added_ingredients=added_ingredients,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to add recipes to shopping list")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


# NOTE: /recipes/search and /recipes/collections must stay declared before
# /recipes/{recipe_id}, otherwise the path parameter swallows them.
@router.get("/recipes/search", response_model=list[RecipeSearchResultResponse])
async def search_recipes(
    q: str = Query(..., min_length=1, max_length=200, description="Search term"),
    limit: int = Query(20, ge=1, le=20, description="Max hits to return"),
    page: int = Query(0, ge=0, description="Result page, 20 hits per page"),
):
    """Search the public Cookidoo recipe catalogue.

    Needs no Cookidoo subscription – this is the public catalogue. See
    ``CookidooService.search_recipes`` for why this bypasses the library.

    ``image`` is returned raw and still contains Cookidoo's ``{transformation}``
    placeholder, which callers must substitute themselves.
    """
    try:
        results = await cookidoo_service.search_recipes(q, page=page)
        return [_map_search_result(r) for r in results[:limit]]
    except Exception as e:
        logger.exception("Recipe search failed")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.get("/recipes/collections", response_model=list[CollectionResponse])
async def get_collections(
    include_managed: bool = Query(
        True, description="Also return Cookidoo-curated collections"
    ),
):
    """Get the user's saved recipe collections as an alternative recipe source."""
    try:
        collections = [
            _map_collection(c, is_custom=True)
            for c in await cookidoo_service.get_custom_collections()
        ]
        if include_managed:
            collections += [
                _map_collection(c, is_custom=False)
                for c in await cookidoo_service.get_managed_collections()
            ]
        return collections
    except Exception as e:
        logger.exception("Failed to fetch collections")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.get("/recipes/{recipe_id}", response_model=RecipeDetailsResponse)
async def get_recipe_details(recipe_id: str):
    """Get a recipe's metadata – useful to confirm a search hit before adding it."""
    try:
        details = await cookidoo_service.get_recipe_details(recipe_id)
        return RecipeDetailsResponse(
            id=details.id,
            name=details.name,
            total_time=details.total_time,
            active_time=details.active_time,
            serving_size=details.serving_size,
            difficulty=details.difficulty,
            url=details.url,
            image=details.image,
            ingredients=[
                RecipeIngredientResponse(
                    id=i.id, name=i.name, description=i.description
                )
                for i in details.ingredients
            ],
        )
    except Exception as e:
        logger.exception("Failed to fetch recipe details")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e


@router.delete("/shopping-list")
async def clear_shopping_list():
    """Remove all additional items, ingredients, and recipes from the shopping list."""
    try:
        await cookidoo_service.clear_shopping_list()
        return {"status": "ok"}
    except Exception as e:
        logger.exception("Failed to clear shopping list")
        raise HTTPException(status_code=502, detail=f"Cookidoo error: {e}") from e
