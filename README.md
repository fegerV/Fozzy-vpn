# Telegram VPN Bot

Telegram бот для продажи VPN подписок с интеграцией 3x-ui панелью.

## Возможности

- Продажа VPN подписок на разные сроки: 1 день, 1 неделя, 1 месяц, 6 месяцев, 1 год
- Автоматическое создание VPN аккаунтов через 3x-ui API
- Прием платежей через крипто кошельки
- Управление пользователями и подписками
- Уведомления об окончании подписки

## Установка

1. Установите зависимости:
```bash
pip install -r requirements.txt
```

2. Настройте переменные окружения в `.env` файле

3. Запустите миграции базы данных:
```bash
python -m alembic upgrade head
```

4. Запустите бота:
```bash
python main.py
```

## Переменные окружения

- `TELEGRAM_BOT_TOKEN` - токен Telegram бота
- `ADMIN_TELEGRAM_ID` - ID администратора бота
- `DATABASE_URL` - URL подключения к PostgreSQL
- `XUI_PANEL_URL` - URL 3x-ui панели
- `XUI_USERNAME` - логин для 3x-ui API
- `XUI_PASSWORD` - пароль для 3x-ui API
- `CRYPTO_WALLET_BTC` - BTC кошелек для платежей
- `CRYPTO_WALLET_USDT` - USDT кошелек для платежей