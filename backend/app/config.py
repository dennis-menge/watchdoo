"""Configuration settings for the backend."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    cookidoo_email: str
    cookidoo_password: str
    cookidoo_country: str = "de"
    cookidoo_language: str = "de-DE"
    api_key: str
    log_level: str = "INFO"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
