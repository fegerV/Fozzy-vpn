import os
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Telegram
    telegram_bot_token: str
    admin_telegram_id: int
    
    # Database
    database_url: str
    postgres_password: str = "vpn_password"
    
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
    
    # Security Settings
    max_login_attempts: int = 3
    session_timeout_minutes: int = 30
    rate_limit_requests_per_minute: int = 10
    
    # Monitoring Settings
    enable_monitoring: bool = True
    monitoring_interval_seconds: int = 300
    alert_email: Optional[str] = None
    
    # Backup Settings
    enable_auto_backup: bool = True
    backup_retention_days: int = 30
    
    # SSL/TLS Settings
    ssl_cert_path: Optional[str] = None
    ssl_key_path: Optional[str] = None
    
    # Domain Settings
    domain_name: Optional[str] = None
    
    # Grafana Settings
    grafana_password: str = "admin123"
    
    class Config:
        env_file = ".env"


settings = Settings()