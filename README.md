# VPN Server - Интеграция 3x-ui и Telegram бота

## 📋 Обзор проекта

Полнофункциональный VPN сервис с автоматизацией продаж через Telegram бота и управлением через 3x-ui панель.

## 🚀 Возможности

- 🤖 **Telegram бот** для автоматизации продаж
- 🔐 **3x-ui интеграция** для управления VPN
- 💰 **Крипто платежи** BTC/USDT
- 📊 **Мониторинг** и аналитика
- 🛡️ **Безопасность** и маскировка
- 🔄 **Автоматизация** подписок

## 📁 Структура проекта

```
Fozzy-wpn/
├── main.py              # Основной код бота
├── models.py            # SQLAlchemy модели
├── services.py          # Бизнес-логика
├── xui_client.py        # 3x-ui API клиент
├── config.py            # Конфигурация
├── docker-compose.yml   # Docker конфигурация
├── scripts/             # Скрипты автоматизации
│   ├── setup_security.sh
│   ├── quick_setup.sh
│   ├── monitor.sh
│   └── backup.sh
├── configs/             # Конфигурации безопасности
│   ├── nginx-stub.conf
│   ├── stub-page.html
│   └── 3x-ui-security.md
├── SECURITY.md          # Руководство по безопасности
└── SECURITY_README.md   # Краткое руководство
```

## 🛡️ Настройки безопасности

### 1. Первоначальная настройка

```bash
# Клонирование репозитория
git clone https://github.com/fegerV/Fozzy-vpn
cd Fozzy-wpn

# Быстрая настройка безопасности
sudo chmod +x scripts/quick_setup.sh
sudo ./scripts/quick_setup.sh

# Или полная настройка
sudo chmod +x scripts/setup_security.sh
sudo ./scripts/setup_security.sh
```

### 2. Настройка 3x-ui протоколов

**Рекомендуемые настройки:**

- **VLESS + Reality**: Основной протокол
- **VMess + WebSocket**: Резервный протокол  
- **Trojan**: Дополнительный протокол
- **Shadowsocks**: Для совместимости

```bash
# Вход в 3x-ui панель
x-ui

# Создание Reality inbound
# Протокол: VLESS
# Сеть: TCP
- TLS: Включен
- Reality: Включен
- Destination: www.google.com:443
```

### 3. Маскировка сервера

Сервер автоматически маскируется под сайт технического обслуживания:

- **Порт 80/443**: Страница техработ
- **Порт 443 (VLESS)**: Обычный HTTPS трафик
- **Порт 2053**: Панель 3x-ui

## 🐳 Развертывание

### 1. Настройка переменных окружения

```bash
# Копирование шаблона
cp .env.example .env
nano .env

# Основные настройки:
TELEGRAM_BOT_TOKEN=your_bot_token
ADMIN_TELEGRAM_ID=your_admin_id
XUI_PANEL_URL=https://your-server.com:2053
XUI_USERNAME=admin
XUI_PASSWORD=your_secure_password
CRYPTO_WALLET_BTC=your_btc_wallet
CRYPTO_WALLET_USDT=your_usdt_wallet
```

### 2. Запуск с Docker

```bash
# Стандартный запуск
docker-compose up -d

# С улучшенной безопасностью
docker-compose -f docker-compose.security.yml up -d

# С мониторингом
docker-compose -f docker-compose.security.yml --profile monitoring up -d

# С бэкапами
docker-compose -f docker-compose.security.yml --profile backup up -d
```

### 3. Настройка SSL

```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx

# Получение сертификата
sudo certbot --nginx -d your-domain.com

# Автообновление
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

## 📊 Мониторинг

### 1. Настройка мониторинга

```bash
# Сделайте скрипты исполняемыми
chmod +x scripts/monitor.sh scripts/backup.sh

# Настройте cron
crontab -e
*/5 * * * * /home/deploy/Fozzy-wpn/scripts/monitor.sh check
0 */6 * * * /home/deploy/Fozzy-wpn/scripts/monitor.sh report
0 2 * * * /home/deploy/Fozzy-wpn/scripts/backup.sh full
```

### 2. Что проверяется

- 🖥️ Системные ресурсы (CPU, память, диск)
- 🔌 Сетевые соединения
- 🔐 Безопасность (Fail2ban, firewall)
- 🐳 Статус Docker контейнеров
- 🌐 Доступность 3x-ui API

## 💰 Настройка платежей

### Bitcoin (BTC)
```bash
# Настройка в .env
CRYPTO_WALLET_BTC=bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh
```

### USDT (TRC20)
```bash
# Настройка в .env  
CRYPTO_WALLET_USDT=TQn9Y2khEsLMJUiwh8i6D7nJ4WQJ6KzT3S
```

**Важно:** Интегрируйте проверку транзакций через блокчейн API для продакшена.

## 🎮 Использование

### Для пользователей

1. 🤖 Запустите бота командой `/start`
2. 💳 Выберите "Купить VPN"
3. 📦 Выберите тарифный план
4. 💰 Выберите способ оплаты
5. 📤 Отправьте платеж на указанный адрес
6. 📋 Пришлите хэш транзакции
7. 🎉 Получите VPN конфигурацию

### Для администратора

```bash
# Статистика
python manage.py stats

# Пользователи
python manage.py users

# Подписки
python manage.py subscriptions

# Тест 3x-ui
python manage.py test-xui

# Проверка истекших подписок
python manage.py check-expired
```

## 🔧 Управление

### Docker команды
```bash
# Логи бота
docker-compose logs -f bot

# Перезапуск
docker-compose restart

# Вход в контейнер
docker-compose exec bot bash

# Остановка
docker-compose down
```

### Бэкапы
```bash
# Полный бэкап
./scripts/backup.sh full

# Восстановление
./scripts/backup.sh restore backup_file.tar.gz

# Список бэкапов
./scripts/backup.sh list
```

## 🚨 Безопасность

### Ключевые настройки

- ✅ Firewall с необходимыми портами
- ✅ Fail2Ban для защиты от брутфорса
- ✅ SSH только по ключам
- ✅ SSL/TLS для всех сервисов
- ✅ Reality протокол для маскировки
- ✅ Регулярные бэкапы
- ✅ Мониторинг безопасности

### Порты
```bash
22/tcp   # SSH (только для админа)
80/tcp   # HTTP для страницы-заглушки
443/tcp  # HTTPS для VPN протоколов
443/udp  # QUIC для производительности
2053/tcp # 3x-ui панель
5432/tcp # PostgreSQL (только локально)
```

## 📋 Чеклист перед запуском

### Безопасность
- [ ] Запущен скрипт безопасности
- [ ] Настроен firewall
- [ ] Создан пользователь deploy
- [ ] Настроены SSH ключи
- [ ] Получены SSL сертификаты

### 3x-ui
- [ ] Созданы inbound правила
- [ ] Настроен Reality протокол
- [ ] Установлены лимиты клиентов
- [ ] Проверена работа API

### Проект
- [ ] Настроены переменные окружения
- [ ] Созданы Docker контейнеры
- [ ] Настроен мониторинг
- [ ] Созданы бэкапы

## 🔍 Поиск проблем

### Бот не запускается
```bash
# Проверка токена
docker-compose logs bot

# Проверка переменных
docker-compose exec bot printenv
```

### Проблемы с 3x-ui
```bash
# Тест API
python manage.py test-xui

# Проверка логов
docker-compose logs bot | grep xui
```

### Проблемы с базой данных
```bash
# Проверка подключения
docker-compose exec bot python -c "from database import engine; print(engine.execute('SELECT 1').scalar())"

# Миграции
docker-compose exec bot alembic upgrade head
```

## 📞 Поддержка

- 📖 Документация: `SECURITY.md`
- 📊 Мониторинг: Grafana (порт 3000)
- 🔧 Логи: `/var/log/vpn-server/`
- 💬 Telegram: @vpn_support

---

**Готово к продакшену!** Следуйте инструкциям для безопасного развертывания VPN сервиса.
