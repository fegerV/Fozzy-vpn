import asyncio
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from models import User, Subscription, Payment
from database import get_async_session
from xui_client import XUIClient
from config import settings
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PaymentProcessor:
    def __init__(self):
        self.xui_client = XUIClient()
    
    async def check_payment_confirmation(self, tx_hash: str) -> bool:
        """Проверка подтверждения платежа (заглушка для реальной интеграции)"""
        # В реальном приложении здесь будет интеграция с API крипто биржи
        # или блокчейн нодой для проверки транзакций
        
        # Для демонстрации считаем платеж подтвержденным через 5 минут
        await asyncio.sleep(300)  # 5 минут
        return True
    
    async def create_payment(self, user_id: int, amount: float, currency: str, subscription_id: int = None) -> Payment:
        """Создать новый платеж"""
        async for session in get_async_session():
            async with session.begin():
                wallet_address = settings.crypto_wallet_btc if currency == "BTC" else settings.crypto_wallet_usdt
                
                payment = Payment(
                    user_id=user_id,
                    subscription_id=subscription_id,
                    amount=amount,
                    currency=currency,
                    wallet_address=wallet_address,
                    status="pending"
                )
                
                session.add(payment)
                await session.commit()
                await session.refresh(payment)
                
                return payment
    
    async def confirm_payment(self, payment_id: int, tx_hash: str) -> bool:
        """Подтвердить платеж и активировать подписку"""
        async for session in get_async_session():
            async with session.begin():
                # Получаем платеж
                result = await session.execute(
                    select(Payment).where(Payment.id == payment_id)
                )
                payment = result.scalar_one_or_none()
                
                if not payment or payment.status != "pending":
                    return False
                
                # Обновляем платеж
                payment.status = "confirmed"
                payment.tx_hash = tx_hash
                payment.confirmed_at = datetime.utcnow()
                
                # Активируем подписку
                if payment.subscription_id:
                    result = await session.execute(
                        select(Subscription).where(Subscription.id == payment.subscription_id)
                    )
                    subscription = result.scalar_one_or_none()
                    
                    if subscription:
                        # Создаем VPN клиента
                        email = f"vpn_user_{subscription.id}_{subscription.user_id}"
                        client_result = await self.xui_client.add_client(
                            email=email,
                            days=subscription.duration_days
                        )
                        
                        if client_result:
                            subscription.vpn_client_id = client_result["id"]
                            subscription.email = email
                            subscription.status = "active"
                            subscription.started_at = datetime.utcnow()
                            subscription.expires_at = datetime.utcnow() + timedelta(days=subscription.duration_days)
                            
                            logger.info(f"VPN client created for subscription {subscription.id}")
                        else:
                            logger.error(f"Failed to create VPN client for subscription {subscription.id}")
                            return False
                
                await session.commit()
                return True


class SubscriptionManager:
    def __init__(self):
        self.xui_client = XUIClient()
    
    async def create_subscription(self, user_id: int, duration_days: int, price: float) -> Subscription:
        """Создать новую подписку"""
        async for session in get_async_session():
            async with session.begin():
                subscription = Subscription(
                    user_id=user_id,
                    duration_days=duration_days,
                    price=price,
                    status="pending"
                )
                
                session.add(subscription)
                await session.commit()
                await session.refresh(subscription)
                
                return subscription
    
    async def get_user_active_subscriptions(self, user_id: int) -> list[Subscription]:
        """Получить активные подписки пользователя"""
        async for session in get_async_session():
            result = await session.execute(
                select(Subscription).where(
                    and_(
                        Subscription.user_id == user_id,
                        Subscription.status == "active"
                    )
                )
            )
            return result.scalars().all()
    
    async def get_user_subscriptions(self, user_id: int) -> list[Subscription]:
        """Получить все подписки пользователя"""
        async for session in get_async_session():
            result = await session.execute(
                select(Subscription).where(Subscription.user_id == user_id)
            )
            return result.scalars().all()
    
    async def cancel_subscription(self, subscription_id: int) -> bool:
        """Отменить подписку"""
        async for session in get_async_session():
            async with session.begin():
                result = await session.execute(
                    select(Subscription).where(Subscription.id == subscription_id)
                )
                subscription = result.scalar_one_or_none()
                
                if not subscription:
                    return False
                
                # Удаляем VPN клиента
                if subscription.vpn_client_id and subscription.email:
                    await self.xui_client.delete_client(subscription.email)
                
                # Обновляем статус
                subscription.status = "cancelled"
                await session.commit()
                
                return True
    
    async def check_expired_subscriptions(self):
        """Проверить и деактивировать истекшие подписки"""
        async for session in get_async_session():
            async with session.begin():
                result = await session.execute(
                    select(Subscription).where(
                        and_(
                            Subscription.status == "active",
                            Subscription.expires_at <= datetime.utcnow()
                        )
                    )
                )
                expired_subscriptions = result.scalars().all()
                
                for subscription in expired_subscriptions:
                    # Удаляем VPN клиента
                    if subscription.email:
                        await self.xui_client.delete_client(subscription.email)
                    
                    # Обновляем статус
                    subscription.status = "expired"
                    
                    logger.info(f"Subscription {subscription.id} expired and deactivated")
                
                await session.commit()
                
                return len(expired_subscriptions)


class UserManager:
    async def get_or_create_user(self, telegram_id: int, username: str = None, first_name: str = None) -> User:
        """Получить или создать пользователя"""
        async for session in get_async_session():
            async with session.begin():
                # Пытаемся найти пользователя
                result = await session.execute(
                    select(User).where(User.telegram_id == telegram_id)
                )
                user = result.scalar_one_or_none()
                
                if not user:
                    # Создаем нового пользователя
                    user = User(
                        telegram_id=telegram_id,
                        username=username,
                        first_name=first_name
                    )
                    session.add(user)
                    await session.commit()
                    await session.refresh(user)
                
                return user
    
    async def get_user(self, telegram_id: int) -> User:
        """Получить пользователя по telegram_id"""
        async for session in get_async_session():
            result = await session.execute(
                select(User).where(User.telegram_id == telegram_id)
            )
            return result.scalar_one_or_none()