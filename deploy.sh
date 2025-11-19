#!/bin/bash

# VPN Bot Deployment Script

set -e

echo "🚀 Начинаем развертывание VPN Telegram бота..."

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Установите Docker и повторите попытку."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен. Установите Docker Compose и повторите попытку."
    exit 1
fi

# Создаем .env файл если он не существует
if [ ! -f .env ]; then
    echo "📝 Создаем .env файл из шаблона..."
    cp .env.example .env
    echo "⚠️  Пожалуйста, отредактируйте .env файл с вашими настройками"
    echo "   - TELEGRAM_BOT_TOKEN"
    echo "   - ADMIN_TELEGRAM_ID"
    echo "   - DATABASE_URL"
    echo "   - XUI_PANEL_URL"
    echo "   - XUI_USERNAME"
    echo "   - XUI_PASSWORD"
    echo "   - Кошельки для крипто платежей"
fi

# Создаем директории для данных
echo "📁 Создаем директории для данных..."
mkdir -p data/postgres
mkdir -p data/bot

# Устанавливаем права
chmod 755 data/postgres
chmod 755 data/bot

# Собираем и запускаем контейнеры
echo "🔨 Собираем Docker образы..."
docker-compose build

echo "🚀 Запускаем сервисы..."
docker-compose up -d

# Ждем запуска PostgreSQL
echo "⏳ Ожидаем запуска PostgreSQL..."
sleep 10

# Выполняем миграции базы данных
echo "🗄️ Выполняем миграции базы данных..."
docker-compose exec bot alembic upgrade head

# Проверяем статус
echo "🔍 Проверяем статус сервисов..."
docker-compose ps

echo ""
echo "✅ Развертывание завершено!"
echo ""
echo "📋 Полезные команды:"
echo "   docker-compose logs -f bot    - Просмотр логов бота"
echo "   docker-compose restart bot     - Перезапуск бота"
echo "   docker-compose down            - Остановка всех сервисов"
echo "   docker-compose exec bot bash   - Вход в контейнер бота"
echo ""
echo "🔧 Не забудьте:"
echo "   1. Настроить 3x-ui панель на вашем сервере"
echo "   2. Указать правильные URL и учетные данные в .env"
echo "   3. Создать Telegram бота и получить токен"
echo "   4. Настроить крипто кошельки для приема платежей"