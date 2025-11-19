import asyncio
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from models import Subscription
from database import get_async_session
from xui_client import XUIClient
from config import settings

async def create_initial_migration():
    """Создать начальную миграцию"""
    import os
    os.system("alembic revision --autogenerate -m 'Initial migration'")

async def main():
    """Создаем начальную миграцию для базы данных"""
    print("🗄️ Создание начальной миграции...")
    
    # Проверяем наличие директории alembic/versions
    import os
    if not os.path.exists("alembic/versions"):
        os.makedirs("alembic/versions")
    
    # Создаем миграцию
    os.system("alembic revision --autogenerate -m 'Initial migration'")
    print("✅ Начальная миграция создана")
    print("📝 Для применения миграций используйте: alembic upgrade head")

if __name__ == "__main__":
    asyncio.run(main())