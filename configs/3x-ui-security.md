# =============================================================================
# 3x-UI Security Configuration Guide
# =============================================================================

# Рекомендуемые настройки безопасности для 3x-ui панели
# Этот файл содержит оптимальные настройки протоколов и безопасности

# =============================================================================
# ОБЩИЕ НАСТРОЙКИ БЕЗОПАСНОСТИ
# =============================================================================

# 1. Изменение порта панели (рекомендуется)
PANEL_PORT=2053

# 2. Включение SSL/TLS для панели
PANEL_SSL=true

# 3. Ограничение попыток входа
MAX_LOGIN_ATTEMPTS=3
LOGIN_TIMEOUT=300

# 4. Сложный пароль администратора (минимум 16 символов)
ADMIN_PASSWORD_REGEX="^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{16,}$"

# =============================================================================
# НАСТРОЙКИ ПРОТОКОЛОВ
# =============================================================================

# VLESS (рекомендуемый протокол)
VLESS_CONFIG={
    "protocol": "vless",
    "network": "tcp",
    "tls": "tls",
    "flow": "xtls-rprx-vision",
    "reality": {
        "enabled": true,
        "dest": "www.google.com:443",
        "xver": 0,
        "serverNames": ["www.google.com"],
        "privateKey": "",
        "minClient": "",
        "maxClient": "",
        "maxTimeDiff": 0,
        "shortIds": ["", "6ba85179e30d4fc2"]
    }
}

# VMess (альтернативный протокол)
VMESS_CONFIG={
    "protocol": "vmess",
    "network": "ws",
    "tls": "tls",
    "path": "/vmess",
    "headers": {
        "Host": "your-domain.com"
    }
}

# Trojan (резервный протокол)
TROJAN_CONFIG={
    "protocol": "trojan",
    "network": "tcp",
    "tls": "tls",
    "fallbackAddr": "127.0.0.1",
    "fallbackPort": 80
}

# =============================================================================
# НАСТРОЙКИ БЕЗОПАСНОСТИ ДЛЯ INBOUND
# =============================================================================

# Основные настройки безопасности
INBOUND_SECURITY={
    "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": false,
        "metadataOnly": false
    },
    "allocate": {
        "strategy": "always",
        "refresh": 5,
        "concurrency": 3
    }
}

# Настройки клиентов
CLIENT_SECURITY={
    "limitIp": 0,  # 0 = без ограничений, 1 = один IP
    "totalGB": 107374182400,  # 100GB в байтах
    "expiryTime": 0,  # 0 = без ограничения по времени
    "enable": true,
    "tgId": "",  # Telegram ID для привязки
    "subId": ""  # ID подписки
}

# =============================================================================
# РЕАЛИТИ (REALITY) НАСТРОЙКИ - РЕКОМЕНДУЕТСЯ
# =============================================================================

# Reality обеспечивает максимальную маскировку трафика
REALITY_CONFIG={
    "enabled": true,
    "dest": "www.google.com:443",
    "xver": 0,
    "serverNames": [
        "www.google.com",
        "www.microsoft.com",
        "www.apple.com",
        "www.amazon.com"
    ],
    "privateKey": "YOUR_PRIVATE_KEY_HERE",
    "publicKey": "YOUR_PUBLIC_KEY_HERE",
    "minClient": "YOUR_MIN_CLIENT_HERE",
    "maxClient": "YOUR_MAX_CLIENT_HERE",
    "maxTimeDiff": 0,
    "shortIds": [
        "",
        "6ba85179e30d4fc2",
        "2b331a0a094e4e7a",
        "8c3a1f8b5d6e9c2f"
    ]
}

# =============================================================================
# ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ
# =============================================================================

NETWORK_SETTINGS={
    "bufferSize": 65536,
    "tcpFastOpen": true,
    "tcpFastOpenQueueLength": 4096,
    "tcpKeepAliveInterval": 300,
    "tcpKeepAliveIdle": 900,
    "tcpKeepAliveCount": 9
}

# =============================================================================
# МОНИТОРИНГ И ЛОГИРОВАНИЕ
# =============================================================================

LOG_SETTINGS={
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "logAuth": true,
    "logDNS": true,
    "dnsLog": false
}

# =============================================================================
# РЕКОМЕНДУЕМЫЕ ПОРТЫ
# =============================================================================

RECOMMENDED_PORTS={
    "vless_tcp": 443,
    "vless_reality": 443,
    "vmess_ws": 443,
    "trojan_tcp": 443,
    "shadowsocks": 8388,
    "panel": 2053
}

# =============================================================================
# ПРАВИЛА FIREWALL
# =============================================================================

FIREWALL_RULES=[
    "ufw allow 22/tcp",      # SSH
    "ufw allow 80/tcp",       # HTTP для заглушки
    "ufw allow 443/tcp",      # HTTPS
    "ufw allow 443/udp",      # QUIC/UDP
    "ufw allow 2053/tcp",     # 3x-ui панель
    "ufw allow 8443/tcp",     # Альтернативный порт
    "ufw deny 2053/udp",      # Блокируем UDP для панели
    "ufw deny 8080/tcp",      # Блокируем стандартные порты
    "ufw deny 3000/tcp",
    "ufw deny 5000/tcp",
    "ufw deny 8000/tcp",
    "ufw deny 9000/tcp"
]

# =============================================================================
# ПРОВЕРКА БЕЗОПАСНОСТИ
# =============================================================================

SECURITY_CHECKLIST=[
    "✓ Изменен стандартный порт панели",
    "✓ Включен Reality для маскировки",
    "✓ Настроены ограничения клиентов",
    "✓ Включено логирование",
    "✓ Настроен firewall",
    "✓ Используются сложные пароли",
    "✓ Ограничены попытки входа",
    "✓ Включена двухфакторная аутентификация",
    "✓ Регулярные бэкапы конфигурации",
    "✓ Мониторинг активности"
]

# =============================================================================
# КОМАНДЫ ДЛЯ НАСТРОЙКИ
# =============================================================================

# Команды для настройки безопасности 3x-ui
SETUP_COMMANDS="""
# 1. Обновление 3x-ui
x-ui update

# 2. Изменение порта панели
x-ui settings

# 3. Создание Reality inbound
x-ui add

# 4. Проверка статуса
x-ui status

# 5. Просмотр логов
x-ui log

# 6. Перезапуск сервиса
x-ui restart
"""

# =============================================================================
# МОНИТОРИНГ И АЛЕРТЫ
# =============================================================================

MONITORING_SETTINGS={
    "check_interval": 60,  # секунд
    "max_connections": 1000,
    "bandwidth_alert": "1TB",
    "disk_usage_alert": "80%",
    "memory_usage_alert": "85%",
    "cpu_usage_alert": "90%"
}

ALERT_EMAIL="admin@your-domain.com"

# =============================================================================
# БЭКАПЫ
# =============================================================================

BACKUP_SETTINGS={
    "backup_interval": "daily",
    "backup_retention": 30,
    "backup_location": "/opt/vpn-server/backups",
    "include_configs": true,
    "include_database": true,
    "compress_backups": true
}

BACKUP_COMMANDS="""
# Создание бэкапа конфигурации 3x-ui
cp /etc/x-ui/config.json /opt/vpn-server/backups/config-\$(date +%Y%m%d-%H%M%S).json

# Бэкап базы данных
docker exec vpn_bot_db pg_dump -U vpn_user vpn_bot > /opt/vpn-server/backups/db-\$(date +%Y%m%d-%H%M%S).sql

# Очистка старых бэкапов
find /opt/vpn-server/backups -name "*.json" -mtime +30 -delete
find /opt/vpn-server/backups -name "*.sql" -mtime +30 -delete
"""