"""Cookidoo API wrapper service – manages session and token lifecycle."""

import logging
from typing import Any
from urllib.parse import urlparse

import aiohttp
from cookidoo_api import Cookidoo
from cookidoo_api.helpers import get_localization_options
from cookidoo_api.types import (
    CookidooAdditionalItem,
    CookidooCollection,
    CookidooConfig,
    CookidooIngredientItem,
    CookidooLocalizationConfig,
    CookidooShoppingRecipeDetails,
)

from app.config import settings

logger = logging.getLogger(__name__)


class CookidooService:
    """Singleton-style wrapper around the cookidoo-api library."""

    def __init__(self) -> None:
        self._session: aiohttp.ClientSession | None = None
        self._cookidoo: Cookidoo | None = None
        self._logged_in: bool = False
        self._localization: CookidooLocalizationConfig | None = None

    def _ensure_http_session(self) -> aiohttp.ClientSession:
        """Ensure an aiohttp session exists, without requiring a login."""
        if self._session is None or self._session.closed:
            # CookieJar(unsafe=True) is required by cookidoo-api 0.17.1+ so the
            # OAuth2 browser-login redirect chain can carry cookies across the
            # cookidoo.{tld}, ciam.prod.cookidoo... and eu.login.vorwerk.com
            # domains.
            self._session = aiohttp.ClientSession(
                cookie_jar=aiohttp.CookieJar(unsafe=True)
            )
            self._logged_in = False
            self._cookidoo = None
        return self._session

    async def _ensure_localization(self) -> CookidooLocalizationConfig:
        """Resolve and cache the localization for the configured country/language."""
        if self._localization is None:
            localizations = await get_localization_options(
                country=settings.cookidoo_country,
                language=settings.cookidoo_language,
            )
            if not localizations:
                raise RuntimeError(
                    f"No localization found for country={settings.cookidoo_country}, "
                    f"language={settings.cookidoo_language}"
                )
            self._localization = localizations[0]
        return self._localization

    async def _ensure_session(self) -> Cookidoo:
        """Ensure we have an active aiohttp session and logged-in Cookidoo client."""
        session = self._ensure_http_session()

        if self._cookidoo is None or not self._logged_in:
            localization = await self._ensure_localization()

            self._cookidoo = Cookidoo(
                session,
                cfg=CookidooConfig(
                    email=settings.cookidoo_email,
                    password=settings.cookidoo_password,
                    localization=localization,
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

    async def add_ingredient_items_for_recipes(
        self, recipe_ids: list[str]
    ) -> list[CookidooIngredientItem]:
        """Add all ingredients of the given catalogue recipes to the shopping list.

        Counterpart to ``remove_ingredient_items_for_recipes``. Cookidoo supplies
        the quantities and recipe association itself, so this is preferable to
        pushing loose ``additional_items`` text lines.

        Note: the library discards the recipe association when parsing the
        response, so the returned items carry no ``recipe_id``. Callers that need
        it must re-read the list via ``get_shopping_list_recipes``.
        """
        cookidoo = await self._ensure_session()
        return await self._with_retry(
            cookidoo.add_ingredient_items_for_recipes, recipe_ids
        )

    async def add_ingredient_items_for_custom_recipes(
        self, recipe_ids: list[str]
    ) -> list[CookidooIngredientItem]:
        """Add all ingredients of the given user-created recipes to the shopping list.

        Custom recipe ids look identical to catalogue ids but must go through
        this separate endpoint, hence the explicit ``custom`` flag on the API.
        """
        cookidoo = await self._ensure_session()
        return await self._with_retry(
            cookidoo.add_ingredient_items_for_custom_recipes, recipe_ids
        )

    async def get_recipe_details(self, recipe_id: str) -> CookidooShoppingRecipeDetails:
        """Get recipe metadata – used to confirm the right dish was matched."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_recipe_details, recipe_id)

    async def get_custom_collections(self, page: int = 0) -> list[CookidooCollection]:
        """Get user-created recipe collections (a source for meal planning)."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_custom_collections, page)

    async def get_managed_collections(self, page: int = 0) -> list[CookidooCollection]:
        """Get Cookidoo-curated collections the user has saved."""
        cookidoo = await self._ensure_session()
        return await self._with_retry(cookidoo.get_managed_collections, page)

    async def search_recipes(self, query: str, page: int = 0) -> list[dict[str, Any]]:
        """Search the public Cookidoo recipe catalogue.

        ⚠️ This deliberately bypasses the cookidoo-api library: it has no search
        capability at all (``const.py`` only defines paths for recipe-by-id,
        shopping list, collections and calendar). Cookidoo's own web search does
        return JSON when asked with ``Accept: application/json`` – without that
        header only a JavaScript shell comes back.

        The endpoint is undocumented and unauthenticated: it serves the public
        catalogue, so no login is required and a subscription does not change the
        results. Keeping it behind this one method means a Vorwerk-side change is
        fixed in a single place.

        Returns raw result dicts with ``id``, ``title``, ``rating``,
        ``numberOfRatings``, ``totalTime`` and ``image``. Returns 20 hits per
        page.
        """
        session = self._ensure_http_session()
        localization = await self._ensure_localization()
        parsed = urlparse(localization.url)
        url = f"{parsed.scheme}://{parsed.netloc}/search/{localization.language}"

        async with session.get(
            url,
            headers={"Accept": "application/json"},
            params={"context": "recipes", "query": query, "page": page},
        ) as response:
            response.raise_for_status()
            payload = await response.json()

        return payload.get("data", [])

    async def clear_shopping_list(self) -> None:
        """Remove all additional items, ingredients, and recipes from the shopping list."""
        cookidoo = await self._ensure_session()
        await self._with_retry(cookidoo.clear_shopping_list)
        logger.info("Shopping list cleared")

    async def login(self) -> None:
        """Ensure the service has a valid, logged-in Cookidoo session.

        Idempotent: if already logged in this is a no-op (just returns the
        existing client). Call this at startup or from the health endpoint to
        eagerly establish a session.
        """
        await self._ensure_session()

    async def refresh_token(self) -> None:
        """Force a fresh Cookidoo login.

        cookidoo-api 0.17.1+ uses an OAuth2 proxy that refreshes access tokens
        automatically, so an explicit refresh endpoint no longer exists on the
        library. We keep this method on the service so callers (e.g. the
        ``/auth/refresh`` endpoint) can force a fresh browser-login flow when
        something seems off — for example, after the user re-installs the
        Watch app or after the long-lived session cookie has expired.
        """
        self._logged_in = False
        await self._ensure_session()
        logger.info("Cookidoo session re-established")

    async def close(self) -> None:
        """Close the aiohttp session."""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None
            self._cookidoo = None
            self._logged_in = False


# Global singleton
cookidoo_service = CookidooService()
