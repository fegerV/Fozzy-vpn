#!/usr/bin/env python3
"""
Скрипт для управления VPN ботом
"""

import asyncio
import argparse
import sys
import os

# Добавляем текущую директорию в путь
sys.path.append(os.path.dirname(__file__))

from database import get_async_session
from models import User, Subscription, Payment
from sqlalchemy import select, func
from services import SubscriptionManager, UserManager
from xui_client import XUIClient
from config import settings


async def show_stats():
    """Показать статистику"""
    async for session in get_async_session():
        # Статистика пользователей
        users_count = await session.scalar(select(func.count(User.id)))
        active_users_count = await session.scalar(
            select(func.count(User.id)).where(User.is_active == True)
        )
        
        # Статистика подписок
        total_subscriptions = await session.scalar(select(func.count(Subscription.id)))
        active_subscriptions = await session.scalar(
            select(func.count(Subscription.id)).where(Subscription.status == "active")
        )
        pending_subscriptions = await session.scalar(
            select(func.count(Subscription.id)).where(Subscription.status == "pending")
        )
        
        # Статистика платежей
        total_payments = await session.scalar(select(func.count(Payment.id)))
        confirmed_payments = await session.scalar(
            select(func.count(Payment.id)).where(Payment.status == "confirmed")
        )
        total_revenue = await session.scalar(
            select(func.sum(Payment.amount)).where(Payment.status == "confirmed")
        ) or 0
        
        print("📊 Статистика VPN бота")
        print("=" * 50)
        print(f"👥 Всего пользователей: {users_count}")
        print(f"✅ Активных пользователей: {active_users_count}")
        print(f"📋 Всего подписок: {total_subscriptions}")
        print(f"🟢 Активных подписок: {active_subscriptions}")
        print(f"⏳ Ожидают оплаты: {pending_subscriptions}")
        print(f"💳 Всего платежей: {total_payments}")
        print(f"✅ Подтвержденных платежей: {confirmed_payments}")
        print(f"💰 Общая выручка: ${total_revenue:.2f}")


async def list_users():
    """Список пользователей"""
    async for session in get_async_session():
        result = await session.execute(
            select(User).order_by(User.created_at.desc())
        )
        users = result.scalars().all()
        
        print("👥 Список пользователей")
        print("=" * 80)
        print(f"{'ID':<10} {'Telegram ID':<15} {'Username':<20} {'Имя':<20} {'Активен':<10}")
        print("-" * 80)
        
        for user in users:
            username = user.username or "-"
            first_name = user.first_name or "-"
            is_active = "Да" if user.is_active else "Нет"
            created_at = user.created_at.strftime("%d.%m.%Y")
            
            print(f"{user.id:<10} {user.telegram_id:<15} {username:<20} {first_name:<20} {is_active:<10}")


async def list_subscriptions():
    """Список подписок"""
    async for session in get_async_session():
        result = await session.execute(
            select(Subscription, User)
            .join(User)
            .order_by(Subscription.created_at.desc())
        )
        subscriptions = result.all()
        
        print("📋 Список подписок")
        print("=" * 100)
        print(f"{'ID':<5} {'Пользователь':<20} {'Дней':<6} {'Цена':<8} {'Статус':<12} {'Начало':<12} {'Окончание':<12}")
        print("-" * 100)
        
        for sub, user in subscriptions:
            username = user.username or user.first_name or f"ID:{user.telegram_id}"
            started = sub.started_at.strftime("%d.%m.%Y") if sub.started_at else "-"
            expires = sub.expires_at.strftime("%d.%m.%Y") if sub.expires_at else "-"
            
            print(f"{sub.id:<5} {username[:20]:<20} {sub.duration_days:<6} ${sub.price:<7.2f} {sub.status:<12} {started:<12} {expires:<12}")


async def test_xui_connection():
    """Тест подключения к 3x-ui"""
    print("🔧 Тест подключения к 3x-ui панели...")
    
    xui_client = XUIClient()
    
    # Тест логина
    login_success = await xui_client.login()
    if login_success:
        print("✅ Успешный вход в 3x-ui панель")
        
        # Тест получения inbound правил
        inbounds = await xui_client.get_inbounds()
        if inbounds:
            print(f"✅ Получено {len(inbounds)} inbound правил")
            for inbound in inbounds:
                print(f"   - {inbound.get('remark', 'No name')} (ID: {inbound.get('id')})")
        else:
            print("❌ Не удалось получить inbound правила")
    else:
        print("❌ Не удалось войти в 3x-ui панель")
        print(f"   URL: {settings.xui_panel_url}")
        print(f"   Username: {settings.xui_username}")


async def check_expired():
    """Проверка истекших подписок"""
    print("🔍 Проверка истекших подписок...")
    
    subscription_manager = SubscriptionManager()
    expired_count = await subscription_manager.check_expired_subscriptions()
    
    if expired_count > 0:
        print(f"✅ Деактивировано {expired_count} истекших подписок")
    else:
        print("✅ Истекших подписок не найдено")


async def main():
    parser = argparse.ArgumentParser(description="Управление VPN ботом")
    parser.add_argument("command", choices=[
        "stats", "users", "subscriptions", "test-xui", "check-expired"
    ], help="Команда для выполнения")
    
    args = parser.parse_args()
    
    if args.command == "stats":
        await show_stats()
    elif args.command == "users":
        await list_users()
    elif args.command == "subscriptions":
        await list_subscriptions()
    elif args.command == "test-xui":
        await test_xui_connection()
    elif args.command == "check-expired":
        await check_expired()


if __name__ == "__main__":
    asyncio.run(main())