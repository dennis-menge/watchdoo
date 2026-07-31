"""Pydantic models for API request/response types."""

from pydantic import BaseModel


class IngredientItemResponse(BaseModel):
    """A single ingredient item on the shopping list."""

    id: str
    name: str
    description: str
    is_owned: bool
    recipe_id: str | None = None
    recipe_name: str | None = None
    shopping_category: str | None = None


class AdditionalItemResponse(BaseModel):
    """A manually added item on the shopping list."""

    id: str
    name: str
    is_owned: bool


class ShoppingRecipeResponse(BaseModel):
    """A recipe contributing items to the shopping list."""

    id: str
    name: str
    ingredients: list[IngredientItemResponse]


class ShoppingListResponse(BaseModel):
    """Complete shopping list response."""

    ingredients: list[IngredientItemResponse]
    additional_items: list[AdditionalItemResponse]
    recipes: list[ShoppingRecipeResponse]


class EditItemOwnershipRequest(BaseModel):
    """Request to toggle owned/checked status of items."""

    id: str
    is_owned: bool


class AddAdditionalItemsRequest(BaseModel):
    """Request to add manually entered items."""

    names: list[str]


class EditAdditionalItemRequest(BaseModel):
    """Request to edit a manually added item."""

    id: str
    name: str
    is_owned: bool


class RemoveRecipeRequest(BaseModel):
    """Request to remove a recipe's ingredients from the list."""

    recipe_id: str


class AddRecipesRequest(BaseModel):
    """Request to put whole dishes on the shopping list.

    Cookidoo supplies the ingredients, quantities and recipe association itself,
    which is why this is preferable to pushing loose ``additional_items``.
    """

    recipe_ids: list[str]
    custom: bool = False
    allow_duplicates: bool = False


class AddRecipesResponse(BaseModel):
    """Result of adding recipes to the shopping list."""

    added_recipe_ids: list[str]
    skipped_recipe_ids: list[str]
    added_ingredients: list[IngredientItemResponse]


class RecipeSearchResultResponse(BaseModel):
    """A hit from the public Cookidoo recipe catalogue search.

    ``rating``/``number_of_ratings`` and ``total_time`` are the selection signals
    a meal planner needs: pick well-rated dishes and honour "under 25 minutes"
    from data instead of guessing.
    """

    id: str
    name: str
    rating: float | None = None
    number_of_ratings: int | None = None
    total_time: int | None = None
    image: str | None = None


class RecipeIngredientResponse(BaseModel):
    """An ingredient as listed on a recipe (not on the shopping list)."""

    id: str
    name: str
    description: str


class RecipeDetailsResponse(BaseModel):
    """Metadata for a single recipe – used to confirm the right dish matched."""

    id: str
    name: str
    total_time: int
    active_time: int
    serving_size: int
    difficulty: str
    url: str
    image: str | None = None
    ingredients: list[RecipeIngredientResponse]


class CollectionRecipeResponse(BaseModel):
    """A recipe inside a collection."""

    id: str
    name: str
    total_time: int


class CollectionResponse(BaseModel):
    """A saved recipe collection, flattened across its chapters."""

    id: str
    name: str
    description: str | None = None
    is_custom: bool
    recipes: list[CollectionRecipeResponse]


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    cookidoo_connected: bool
