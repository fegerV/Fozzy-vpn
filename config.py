import os
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Telegram
    telegram_bot_token: str
    admin_telegram_id: int
    
    # Database
    database_url: str
    
    # 3x-ui Panel
    xui_panel_url: str
    xui_username: str
    xui_password: str
    
    # Crypto Wallets
    crypto_wallet_btc: str
    crypto_wallet_usdt: str
    
    # Prices
    price_1_day: float = 5.0
    price_1_week: float = 15.0
    price_1_month: float = 25.0
    price_6_months: float = 120.0
    price_1_year: float = 200.0
    
    # VPN Settings
    vpn_inbound_id: int = 1
    default_data_limit_gb: int = 1000
    
    class Config:
        env_file = ".env"


settings = Settings()