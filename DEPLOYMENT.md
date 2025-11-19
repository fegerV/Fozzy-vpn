# VPN Telegram Bot - Инструкция по развертыванию

## 📋 Обзор

Это полноценный Telegram бот для продажи VPN подписок с интеграцией 3x-ui панелью. Бот поддерживает автоматическое создание VPN аккаунтов, прием крипто платежей и управление подписками.

## 🚀 Возможности

- ✅ Продажа VPN подписок на разные сроки (1 день, 1 неделя, 1 месяц, 6 месяцев, 1 год)
- ✅ Автоматическое создание VPN аккаунтов через 3x-ui API
- ✅ Прием платежей в Bitcoin (BTC) и USDT (TRC20)
- ✅ Управление пользователями и подписками
- ✅ Автоматическая деактивация истекших подписок
- ✅ Админ панель со статистикой
- ✅ Docker контейнеризация для легкого развертывания

## 📋 Требования

- Ubuntu сервер с установленным 3x-ui
- Docker и Docker Compose
- Telegram бот токен
- Крипто кошельки для приема платежей
- PostgreSQL база данных (включена в Docker)

## 🔧 Установка и настройка

### 1. Клонирование и настройка

```bash
# Клонируйте репозиторий
git clone <repository-url>
cd Fozzy-wpn

# Сделайте скрипты исполняемыми
chmod +x deploy.sh
chmod +x manage.py
```

### 2. Настройка переменных окружения

Скопируйте шаблон и отредактируйте его:

```bash
cp .env.example .env
nano .env
```

Обязательно настройте следующие параметры:

```bash
# Telegram Bot
TELEGRAM_BOT_TOKEN=your_bot_token_here
ADMIN_TELEGRAM_ID=your_admin_telegram_id

# 3x-ui Panel
XUI_PANEL_URL=https://your-server.com:2053
XUI_USERNAME=admin
XUI_PASSWORD=your_password

# Crypto Wallets
CRYPTO_WALLET_BTC=your_btc_wallet
CRYPTO_WALLET_USDT=your_usdt_wallet

# Database (будет создан автоматически)
DATABASE_URL=postgresql+asyncpg://vpn_user:vpn_password@postgres:5432/vpn_bot
```

### 3. Развертывание

```bash
# Запустите скрипт развертывания
./deploy.sh
```

Скрипт автоматически:
- Создаст .env файл из шаблона
- Соберет Docker образы
- Запустит PostgreSQL и бота
- Выполнит миграции базы данных

### 4. Настройка 3x-ui

Убедитесь, что 3x-ui панель настроена:

1. Войдите в вашу 3x-ui панель
2. Создайте inbound правило (или используйте существующее)
3. Запомните ID inbound правила
4. Укажите его в `.env` файле: `VPN_INBOUND_ID=1`

## 🎮 Использование

### Для пользователей

1. Запустите бота командой `/start`
2. Выберите "Купить VPN"
3. Выберите тарифный план
4. Выберите способ оплаты (BTC/USDT)
5. Отправьте платеж на указанный адрес
6. Пришлите хэш транзакции боту
7. Получите VPN конфигурацию

### Для администратора

1. Получите статистику: `python manage.py stats`
2. Посмотрите пользователей: `python manage.py users`
3. Проверьте подписки: `python manage.py subscriptions`
4. Тест подключения к 3x-ui: `python manage.py test-xui`
5. Проверка истекших подписок: `python manage.py check-expired`

## 🐳 Docker команды

```bash
# Просмотр логов бота
docker-compose logs -f bot

# Перезапуск бота
docker-compose restart bot

# Вход в контейнер бота
docker-compose exec bot bash

# Остановка всех сервисов
docker-compose down

# Обновление и перезапуск
git pull
docker-compose build
docker-compose up -d
```

## 💰 Настройка платежей

### Bitcoin (BTC)
- Укажите ваш BTC кошелек в `CRYPTO_WALLET_BTC`
- Бот покажет адрес для оплаты
- Пользователь отправляет BTC и присылает хэш транзакции

### USDT (TRC20)
- Укажите ваш USDT кошелек в `CRYPTO_WALLET_USDT`
- Бот покажет TRC20 адрес для оплаты
- Пользователь отправляет USDT и присылает хэш транзакции

**Важно:** В текущей версии подтверждение платежей происходит автоматически через 5 минут после получения хэша. Для реального использования необходимо интегрировать проверку транзакций через блокчейн API.

## 🔍 Мониторинг и отладка

### Логи
```bash
# Логи бота
docker-compose logs bot

# Логи PostgreSQL
docker-compose logs postgres
```

### Статистика
```bash
# Общая статистика
python manage.py stats

# Тест подключения к 3x-ui
python manage.py test-xui
```

## 🛠️ Кастомизация

### Изменение тарифов
Отредактируйте цены в `.env` файле:
```bash
PRICE_1_DAY=5
PRICE_1_WEEK=15
PRICE_1_MONTH=25
PRICE_6_MONTHS=120
PRICE_1_YEAR=200
```

### Настройка лимитов трафика
```bash
DEFAULT_DATA_LIMIT_GB=1000  # Лимит трафика по умолчанию
```

## 🔒 Безопасность

1. Используйте сложные пароли для 3x-ui панели
2. Ограничьте доступ к админ функциям бота
3. Регулярно обновляйте зависимости
4. Используйте HTTPS для 3x-ui панели
5. Настройте файрвол на сервере

## 🚨 Устранение проблем

### Бот не запускается
1. Проверьте токен бота в `.env`
2. Убедитесь что Docker запущен
3. Проверьте логи: `docker-compose logs bot`

### Не работает 3x-ui интеграция
1. Проверьте URL и учетные данные 3x-ui
2. Убедитесь что inbound ID правильный
3. Тест подключения: `python manage.py test-xui`

### Проблемы с базой данных
1. Проверьте что PostgreSQL контейнер запущен
2. Выполните миграции: `docker-compose exec bot alembic upgrade head`

## 📞 Поддержка

Если возникли вопросы или проблемы:
- Проверьте логи контейнеров
- Убедитесь что все переменные окружения настроены правильно
- Проверьте доступность 3x-ui панели

## 🔄 Обновление

```bash
# Получение обновлений
git pull

# Пересборка и перезапуск
docker-compose build
docker-compose up -d

# Применение миграций
docker-compose exec bot alembic upgrade head
```