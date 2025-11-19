from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
import asyncio
from datetime import datetime
from config import settings
from services import PaymentProcessor, SubscriptionManager, UserManager
from models import User, Subscription
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Инициализация бота
bot = Bot(token=settings.telegram_bot_token)
dp = Dispatcher(storage=MemoryStorage())

# Сервисы
payment_processor = PaymentProcessor()
subscription_manager = SubscriptionManager()
user_manager = UserManager()

# Состояния для FSM
class PaymentStates(StatesGroup):
    waiting_for_tx_hash = State()

# Клавиатуры
def get_main_keyboard():
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🛒 Купить VPN", callback_data="buy_vpn")],
        [InlineKeyboardButton(text="📋 Мои подписки", callback_data="my_subscriptions")],
        [InlineKeyboardButton(text="📞 Поддержка", callback_data="support")],
    ])
    return keyboard

def get_subscription_plans_keyboard():
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="1 день - $5", callback_data="plan_1_day")],
        [InlineKeyboardButton(text="1 неделя - $15", callback_data="plan_1_week")],
        [InlineKeyboardButton(text="1 месяц - $25", callback_data="plan_1_month")],
        [InlineKeyboardButton(text="6 месяцев - $120", callback_data="plan_6_months")],
        [InlineKeyboardButton(text="1 год - $200", callback_data="plan_1_year")],
        [InlineKeyboardButton(text="🔙 Назад", callback_data="back_to_main")],
    ])
    return keyboard

def get_payment_methods_keyboard():
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Bitcoin (BTC)", callback_data="pay_btc")],
        [InlineKeyboardButton(text="USDT (TRC20)", callback_data="pay_usdt")],
        [InlineKeyboardButton(text="🔙 Назад", callback_data="buy_vpn")],
    ])
    return keyboard

def get_admin_keyboard():
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📊 Статистика", callback_data="admin_stats")],
        [InlineKeyboardButton(text="👥 Пользователи", callback_data="admin_users")],
        [InlineKeyboardButton(text="💳 Платежи", callback_data="admin_payments")],
        [InlineKeyboardButton(text="🔙 Главное меню", callback_data="back_to_main")],
    ])
    return keyboard

# Обработчики команд
@dp.message(Command("start"))
async def cmd_start(message: Message):
    """Обработчик команды /start"""
    user = await user_manager.get_or_create_user(
        telegram_id=message.from_user.id,
        username=message.from_user.username,
        first_name=message.from_user.first_name
    )
    
    welcome_text = f"""
🌟 Добро пожаловать в VPN Service Bot!

🔐 Безопасный и быстрый VPN доступ
🌍 Обход блокировок и ограничений
⚡ Высокая скорость соединения
📱 Поддержка всех устройств

Выберите действие ниже:
    """
    
    await message.answer(
        text=welcome_text,
        reply_markup=get_main_keyboard()
    )

@dp.message(Command("admin"))
async def cmd_admin(message: Message):
    """Обработчик команды /admin"""
    if message.from_user.id == settings.admin_telegram_id:
        await message.answer(
            text="🛠️ Админ панель:",
            reply_markup=get_admin_keyboard()
        )
    else:
        await message.answer("❌ У вас нет доступа к админ панели")

# Обработчики кнопок
@dp.callback_query(F.data == "buy_vpn")
async def callback_buy_vpn(callback: CallbackQuery):
    """Обработчик кнопки Купить VPN"""
    text = """
💰 Выберите тарифный план:

📅 **1 день** - $5
📅 **1 неделя** - $15  
📅 **1 месяц** - $25
📅 **6 месяцев** - $120
📅 **1 год** - $200

Все тарифы включают:
✅ Безлимитный трафик
✅ Высокая скорость
✅ Поддержка всех устройств
✅ 24/7 техподдержка
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_subscription_plans_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data.startswith("plan_"))
async def callback_select_plan(callback: CallbackQuery):
    """Обработчик выбора тарифного плана"""
    plan_data = {
        "plan_1_day": {"days": 1, "price": settings.price_1_day, "name": "1 день"},
        "plan_1_week": {"days": 7, "price": settings.price_1_week, "name": "1 неделя"},
        "plan_1_month": {"days": 30, "price": settings.price_1_month, "name": "1 месяц"},
        "plan_6_months": {"days": 180, "price": settings.price_6_months, "name": "6 месяцев"},
        "plan_1_year": {"days": 365, "price": settings.price_1_year, "name": "1 год"},
    }
    
    plan_info = plan_data.get(callback.data)
    if not plan_info:
        await callback.answer("❌ Неверный тарифный план")
        return
    
    # Создаем подписку
    user = await user_manager.get_user(callback.from_user.id)
    subscription = await subscription_manager.create_subscription(
        user_id=user.id,
        duration_days=plan_info["days"],
        price=plan_info["price"]
    )
    
    # Сохраняем ID подписки в состоянии
    state = dp.fsm.get_context(user=callback.from_user.id, chat=callback.message.chat.id)
    await state.set_data({"subscription_id": subscription.id})
    
    text = f"""
💳 **Выбран тариф: {plan_info['name']}**
💰 **Сумма к оплате: ${plan_info['price']}**

Выберите способ оплаты:
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_payment_methods_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data.startswith("pay_"))
async def callback_select_payment(callback: CallbackQuery, state: FSMContext):
    """Обработчик выбора способа оплаты"""
    currency = "BTC" if callback.data == "pay_btc" else "USDT"
    wallet_address = settings.crypto_wallet_btc if currency == "BTC" else settings.crypto_wallet_usdt
    
    # Получаем ID подписки из состояния
    data = await state.get_data()
    subscription_id = data.get("subscription_id")
    
    if not subscription_id:
        await callback.answer("❌ Ошибка: подписка не найдена")
        return
    
    # Получаем информацию о подписке
    async for session in get_async_session():
        async with session.begin():
            result = await session.execute(
                select(Subscription).where(Subscription.id == subscription_id)
            )
            subscription = result.scalar_one_or_none()
    
    if not subscription:
        await callback.answer("❌ Ошибка: подписка не найдена")
        return
    
    # Создаем платеж
    payment = await payment_processor.create_payment(
        user_id=callback.from_user.id,
        amount=subscription.price,
        currency=currency,
        subscription_id=subscription_id
    )
    
    text = f"""
💳 **Оплата через {currency}**

📋 **Реквизиты для оплаты:**
```
{wallet_address}
```

💰 **Сумма к оплате:** {subscription.price} {currency}

📝 **Важная информация:**
• Отправьте точную сумму
• Минимальная комиссия сети
• Оплата будет обработана автоматически
• Среднее время ожидания: 5-30 минут

После отправки платежа, пришлите хэш транзакции в ответном сообщении.

**ID платежа:** #{payment.id}
    """
    
    await callback.message.edit_text(text=text)
    await callback.answer()
    
    # Устанавливаем состояние ожидания хэша транзакции
    await state.set_state(PaymentStates.waiting_for_tx_hash)
    await state.update_data({"payment_id": payment.id})

@dp.message(PaymentStates.waiting_for_tx_hash)
async def process_tx_hash(message: Message, state: FSMContext):
    """Обработка хэша транзакции"""
    tx_hash = message.text.strip()
    
    # Получаем ID платежа из состояния
    data = await state.get_data()
    payment_id = data.get("payment_id")
    
    if not payment_id:
        await message.answer("❌ Ошибка: платеж не найден")
        await state.clear()
        return
    
    # Проверяем и подтверждаем платеж
    success = await payment_processor.confirm_payment(payment_id, tx_hash)
    
    if success:
        await message.answer(
            "✅ **Платеж успешно подтвержден!**\n\n"
            "🔐 Ваш VPN аккаунт создан и активирован.\n"
            "📋 Конфигурация доступна в разделе 'Мои подписки'.\n\n"
            "Спасибо за покупку! 🎉",
            reply_markup=get_main_keyboard()
        )
    else:
        await message.answer(
            "❌ **Ошибка подтверждения платежа**\n\n"
            "Пожалуйста, проверьте правильность хэша транзакции и попробуйте снова."
        )
    
    await state.clear()

@dp.callback_query(F.data == "my_subscriptions")
async def callback_my_subscriptions(callback: CallbackQuery):
    """Обработчик кнопки Мои подписки"""
    subscriptions = await subscription_manager.get_user_subscriptions(callback.from_user.id)
    
    if not subscriptions:
        text = """
📋 **У вас пока нет подписок**

Хотите купить VPN? Нажмите кнопку "Купить VPN" ниже.
        """
        await callback.message.edit_text(
            text=text,
            reply_markup=get_main_keyboard()
        )
        await callback.answer()
        return
    
    text = "📋 **Ваши подписки:**\n\n"
    
    for sub in subscriptions:
        status_emoji = {
            "pending": "⏳",
            "active": "✅",
            "expired": "❌",
            "cancelled": "🚫"
        }.get(sub.status, "❓")
        
        text += f"{status_emoji} **{sub.duration_days} дней** - ${sub.price}\n"
        text += f"   Статус: {sub.status}\n"
        
        if sub.started_at:
            text += f"   Начало: {sub.started_at.strftime('%d.%m.%Y %H:%M')}\n"
        
        if sub.expires_at:
            text += f"   Окончание: {sub.expires_at.strftime('%d.%m.%Y %H:%M')}\n"
        
        if sub.status == "active" and sub.email:
            text += f"   Email: {sub.email}\n"
        
        text += "\n"
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_main_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data == "support")
async def callback_support(callback: CallbackQuery):
    """Обработчик кнопки Поддержка"""
    text = """
📞 **Техническая поддержка**

Если у вас возникли вопросы или проблемы, свяжитесь с нами:

🔹 **Email:** support@vpn-service.com
🔹 **Telegram:** @vpn_support
🔹 **Время работы:** 24/7

📝 **Частые вопросы:**
• Как подключить VPN?
• Какие устройства поддерживаются?
• Как продлить подписку?

Напишите нам и мы поможем решить любую проблему!
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_main_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data == "back_to_main")
async def callback_back_to_main(callback: CallbackQuery):
    """Возврат в главное меню"""
    await callback.message.edit_text(
        text="🌟 Добро пожаловать в VPN Service Bot!\n\nВыберите действие ниже:",
        reply_markup=get_main_keyboard()
    )
    await callback.answer()

# Админские обработчики
@dp.callback_query(F.data == "admin_stats")
async def callback_admin_stats(callback: CallbackQuery):
    """Админская статистика"""
    if callback.from_user.id != settings.admin_telegram_id:
        await callback.answer("❌ У вас нет доступа")
        return
    
    # Здесь будет логика получения статистики
    text = """
📊 **Статистика сервиса**

👥 Всего пользователей: 0
✅ Активных подписок: 0
💰 Заработано сегодня: $0
💰 Заработано за неделю: $0
💰 Заработано за месяц: $0
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_admin_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data == "admin_users")
async def callback_admin_users(callback: CallbackQuery):
    """Админская панель пользователей"""
    if callback.from_user.id != settings.admin_telegram_id:
        await callback.answer("❌ У вас нет доступа")
        return
    
    text = """
👥 **Управление пользователями**

Здесь будет список пользователей с возможностью управления.
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_admin_keyboard()
    )
    await callback.answer()

@dp.callback_query(F.data == "admin_payments")
async def callback_admin_payments(callback: CallbackQuery):
    """Админская панель платежей"""
    if callback.from_user.id != settings.admin_telegram_id:
        await callback.answer("❌ У вас нет доступа")
        return
    
    text = """
💳 **Управление платежами**

Здесь будет список платежей с возможностью управления.
    """
    
    await callback.message.edit_text(
        text=text,
        reply_markup=get_admin_keyboard()
    )
    await callback.answer()

# Фоновая задача для проверки истекших подписок
async def check_expired_subscriptions():
    """Фоновая задача проверки истекших подписок"""
    while True:
        try:
            expired_count = await subscription_manager.check_expired_subscriptions()
            if expired_count > 0:
                logger.info(f"Deactivated {expired_count} expired subscriptions")
        except Exception as e:
            logger.error(f"Error checking expired subscriptions: {e}")
        
        await asyncio.sleep(3600)  # Проверка каждый час

async def main():
    """Главная функция"""
    # Запускаем фоновую задачу
    asyncio.create_task(check_expired_subscriptions())
    
    # Запускаем бота
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())