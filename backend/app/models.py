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


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    cookidoo_connected: bool
