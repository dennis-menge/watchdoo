"""Cookidoo API wrapper service – manages session and token lifecycle."""

import logging

import aiohttp
from cookidoo_api import Cookidoo
from cookidoo_api.helpers import get_localization_options
from cookidoo_api.types import (
    CookidooAdditionalItem,
    CookidooConfig,
    CookidooIngredientItem,
)

from app.config import settings

logger = logging.getLogger(__name__)


class CookidooService:
    """Singleton-style wrapper around the cookidoo-api library."""

    def __init__(self) -> None:
        self._session: aiohttp.ClientSession | None = None
        self._cookidoo: Cookidoo | None = None
        self._logged_in: bool = False

    async def _ensure_session(self) -> Cookidoo:
        """Ensure we have an active aiohttp session and logged-in Cookidoo client."""
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession()
            self._logged_in = False

        if self._cookidoo is None or not self._logged_in:
            localizations = await get_localization_options(
                country=settings.cookidoo_country,
                language=settings.cookidoo_language,
            )
            if not localizations:
                raise RuntimeError(
                    f"No localization found for country={settings.cookidoo_country}, "
                    f"language={settings.cookidoo_language}"
                )

            self._cookidoo = Cookidoo(
                self._session,
                cfg=CookidooConfig(
                    email=settings.cookidoo_email,
                    password=settings.cookidoo_password,
                    localization=localizations[0],
                ),
            )
            await self._cookidoo.login()
            self._logged_in = True
            logger.info("Cookidoo login successful")

        return self._cookidoo

    async def _with_retry(self, func, *args, **kwargs):
        """Execute a Cookidoo API call with one retry on auth failure."""
        try:
            return await func(*args, **kwargs)
        except Exception as e:
            logger.warning("Cookidoo call failed, retrying with fresh login: %s", e)
            self._logged_in = False
            cookidoo = await self._ensure_session()
            return await getattr(cookidoo, func.__name__)(*args, **kwargs)

    async def get_ingredient_items(self) -> list[CookidooIngredientItem]:
        """Get all ingredient items from the shopping list."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_ingredient_items)

    async def get_additional_items(self) -> list[CookidooAdditionalItem]:
        """Get all manually added items from the shopping list."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_additional_items)

    async def get_shopping_list_recipes(self):
        """Get all recipes contributing to the shopping list."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_shopping_list_recipes)

    async def edit_ingredient_items_ownership(
        self, items: list[CookidooIngredientItem]
    ) -> list[CookidooIngredientItem]:
        """Toggle owned/checked status of ingredient items."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(
            cookidoo.edit_ingredient_items_ownership, items
        )

    async def edit_additional_items_ownership(
        self, items: list[CookidooAdditionalItem]
    ) -> list[CookidooAdditionalItem]:
        """Toggle owned/checked status of additional items."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(
            cookidoo.edit_additional_items_ownership, items
        )

    async def add_additional_items(
        self, names: list[str]
    ) -> list[CookidooAdditionalItem]:
        """Add manually entered items to the shopping list."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.add_additional_items, names)

    async def edit_additional_items(
        self, items: list[CookidooAdditionalItem]
    ) -> list[CookidooAdditionalItem]:
        """Edit additional items (rename)."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.edit_additional_items, items)

    async def remove_additional_items(self, ids: list[str]) -> None:
        """Remove manually added items from the shopping list."""
        cookidoo = await self._ensure_session()
        await self._with_retry(cookidoo.remove_additional_items, ids)

    async def remove_ingredient_items_for_recipes(
        self, recipe_ids: list[str]
    ) -> None:
        """Remove all ingredients for given recipes from the shopping list."""
        cookidoo = await self._ensure_session()
        await self._with_retry(
            cookidoo.remove_ingredient_items_for_recipes, recipe_ids
        )

    async def refresh_token(self) -> None:
        """Manually refresh the Cookidoo auth token."""
        cookidoo = await self._ensure_session()
        await cookidoo.refresh_token()
        logger.info("Cookidoo token refreshed")

    async def close(self) -> None:
        """Close the aiohttp session."""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None
            self._cookidoo = None
            self._logged_in = False


# Global singleton
cookidoo_service = CookidooService()
