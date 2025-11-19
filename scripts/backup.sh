#!/bin/bash

# =============================================================================
# VPN Server Backup Script
# =============================================================================
# Скрипт для создания бэкапов конфигурации и данных VPN сервера
# Использование: ./backup.sh [full|config|database|restore]
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
BACKUP_DIR="/opt/vpn-server/backups"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_LOG="/var/log/vpn-server/backup.log"

# Сервисы и пути
XUI_CONFIG_PATH="/etc/x-ui/config.json"
XUI_DB_PATH="/etc/x-ui/x-ui.db"
DOCKER_COMPOSE_FILE="/home/deploy/Fozzy-wpn/docker-compose.yml"
PROJECT_DIR="/home/deploy/Fozzy-wpn"

# Функции для вывода
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$BACKUP_LOG"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$BACKUP_LOG"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$BACKUP_LOG"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$BACKUP_LOG"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Создание директории для бэкапов
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR/configs"
    mkdir -p "$BACKUP_DIR/database"
    mkdir -p "$BACKUP_DIR/containers"
    mkdir -p "$(dirname "$BACKUP_LOG")"
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log "Очистка старых бэкапов (старше $RETENTION_DAYS дней)..."
    
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.json" -mtime +$RETENTION_DAYS -delete
    
    log_success "Очистка старых бэкапов завершена"
}

# Бэкап конфигурации 3x-ui
backup_xui_config() {
    log "Создание бэкапа конфигурации 3x-ui..."
    
    local backup_file="$BACKUP_DIR/configs/x-ui-config-$DATE.json"
    
    if [ -f "$XUI_CONFIG_PATH" ]; then
        cp "$XUI_CONFIG_PATH" "$backup_file"
        gzip "$backup_file"
        log_success "Конфигурация 3x-ui сохранена: ${backup_file}.gz"
    else
        log_warning "Файл конфигурации 3x-ui не найден: $XUI_CONFIG_PATH"
    fi
    
    # Бэкап базы данных 3x-ui
    if [ -f "$XUI_DB_PATH" ]; then
        local db_backup="$BACKUP_DIR/configs/x-ui-db-$DATE.db"
        cp "$XUI_DB_PATH" "$db_backup"
        gzip "$db_backup"
        log_success "База данных 3x-ui сохранена: ${db_backup}.gz"
    fi
}

# Бэкап PostgreSQL базы данных
backup_database() {
    log "Создание бэкапа PostgreSQL базы данных..."
    
    local backup_file="$BACKUP_DIR/database/vpn-bot-db-$DATE.sql"
    
    # Проверяем запущен ли контейнер
    if docker ps --format "table {{.Names}}" | grep -q "vpn_bot_db"; then
        docker exec vpn_bot_db pg_dump -U vpn_user vpn_bot > "$backup_file"
        
        if [ $? -eq 0 ]; then
            gzip "$backup_file"
            log_success "База данных сохранена: ${backup_file}.gz"
        else
            log_error "Ошибка при создании бэкапа базы данных"
        fi
    else
        log_warning "Контейнер базы данных не запущен"
    fi
}

# Бэкап Docker контейнеров
backup_containers() {
    log "Создание бэкапа Docker контейнеров..."
    
    local backup_file="$BACKUP_DIR/containers/docker-containers-$DATE.tar"
    
    # Сохраняем образы контейнеров
    docker save vpn_bot_bot:latest -o "$BACKUP_DIR/containers/vpn-bot-image-$DATE.tar"
    
    # Экспортируем volumes
    docker run --rm -v vpn_bot_data:/data -v "$BACKUP_DIR/containers":/backup alpine tar czf "/backup/bot-data-$DATE.tar.gz" -C /data .
    
    log_success "Docker контейнеры сохранены"
}

# Бэкап файлов проекта
backup_project() {
    log "Создание бэкапа файлов проекта..."
    
    local backup_file="$BACKUP_DIR/project-backup-$DATE.tar.gz"
    
    if [ -d "$PROJECT_DIR" ]; then
        tar -czf "$backup_file" -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")" \
            --exclude='.git' \
            --exclude='data' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.env'
        
        log_success "Файлы проекта сохранены: $backup_file"
    else
        log_warning "Директория проекта не найдена: $PROJECT_DIR"
    fi
}

# Бэкап системных конфигураций
backup_system_configs() {
    log "Создание бэкапа системных конфигураций..."
    
    local backup_file="$BACKUP_DIR/system-configs-$DATE.tar.gz"
    
    tar -czf "$backup_file" \
        /etc/nginx/ \
        /etc/ufw/ \
        /etc/fail2ban/ \
        /etc/ssh/sshd_config \
        /etc/systemd/system/x-ui.service \
        /etc/cron.d/ \
        --exclude='*.log' \
        --exclude='*.cache'
    
    log_success "Системные конфигурации сохранены: $backup_file"
}

# Полный бэкап
backup_full() {
    log "Начало полного бэкапа..."
    
    create_backup_dir
    
    backup_xui_config
    backup_database
    backup_containers
    backup_project
    backup_system_configs
    
    # Создаем архив полного бэкапа
    local full_backup="$BACKUP_DIR/vpn-server-full-backup-$DATE.tar.gz"
    tar -czf "$full_backup" -C "$BACKUP_DIR" \
        configs/ \
        database/ \
        containers/ \
        project-backup-$DATE.tar.gz \
        system-configs-$DATE.tar.gz
    
    log_success "Полный бэкап создан: $full_backup"
    
    # Очистка
    cleanup_old_backups
    
    # Проверка размера бэкапа
    local backup_size=$(du -h "$full_backup" | cut -f1)
    log_success "Размер полного бэкапа: $backup_size"
}

# Бэкап только конфигурации
backup_config() {
    log "Начало бэкапа конфигурации..."
    
    create_backup_dir
    backup_xui_config
    backup_system_configs
    
    log_success "Бэкап конфигурации завершен"
}

# Бэкап только базы данных
backup_database_only() {
    log "Начало бэкапа базы данных..."
    
    create_backup_dir
    backup_database
    
    log_success "Бэкап базы данных завершен"
}

# Восстановление из бэкапа
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Укажите файл бэкапа для восстановления"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    log "Начало восстановления из бэкапа: $backup_file"
    
    # Создаем временную директорию
    local temp_dir="/tmp/vpn-restore-$(date +%s)"
    mkdir -p "$temp_dir"
    
    # Распаковываем бэкап
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Восстановление базы данных
    if [ -f "$temp_dir/database/vpn-bot-db-"*".sql.gz" ]; then
        log "Восстановление базы данных..."
        gunzip -c "$temp_dir"/database/vpn-bot-db-*.sql.gz | docker exec -i vpn_bot_db psql -U vpn_user vpn_bot
        log_success "База данных восстановлена"
    fi
    
    # Восстановление конфигурации 3x-ui
    if [ -f "$temp_dir/configs/x-ui-config-"*".json.gz" ]; then
        log "Восстановление конфигурации 3x-ui..."
        gunzip -c "$temp_dir"/configs/x-ui-config-*.json.gz > "$XUI_CONFIG_PATH"
        systemctl restart x-ui
        log_success "Конфигурация 3x-ui восстановлена"
    fi
    
    # Очистка
    rm -rf "$temp_dir"
    
    log_success "Восстановление завершено"
}

# Список доступных бэкапов
list_backups() {
    log "Список доступных бэкапов:"
    
    echo "Полные бэкапы:"
    ls -la "$BACKUP_DIR"/vpn-server-full-backup-*.tar.gz 2>/dev/null || echo "  Нет полных бэкапов"
    
    echo "Бэкапы конфигурации:"
    ls -la "$BACKUP_DIR"/configs/x-ui-config-*.json.gz 2>/dev/null || echo "  Нет бэкапов конфигурации"
    
    echo "Бэкапы базы данных:"
    ls -la "$BACKUP_DIR"/database/vpn-bot-db-*.sql.gz 2>/dev/null || echo "  Нет бэкапов базы данных"
}

# Проверка бэкапа
verify_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Укажите файл бэкапа для проверки"
        return 1
    fi
    
    log "Проверка бэкапа: $backup_file"
    
    if [ ! -f "$backup_file" ]; then
        log_error "Файл бэкапа не найден"
        return 1
    fi
    
    # Проверяем архив
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_success "Бэкап прошел проверку целостности"
        
        # Показываем содержимое
        echo "Содержимое бэкапа:"
        tar -tzf "$backup_file" | head -20
        if [ $(tar -tzf "$backup_file" | wc -l) -gt 20 ]; then
            echo "... и еще $(($(tar -tzf "$backup_file" | wc -l) - 20)) файлов"
        fi
    else
        log_error "Бэкап поврежден"
        return 1
    fi
}

# Главное меню
main() {
    local action="${1:-full}"
    local backup_file="${2:-}"
    
    case "$action" in
        "full")
            backup_full
            ;;
        "config")
            backup_config
            ;;
        "database")
            backup_database_only
            ;;
        "restore")
            restore_backup "$backup_file"
            ;;
        "list")
            list_backups
            ;;
        "verify")
            verify_backup "$backup_file"
            ;;
        *)
            echo "Использование: $0 [full|config|database|restore|list|verify] [backup_file]"
            echo "  full     - Полный бэкап всех данных"
            echo "  config   - Бэкап только конфигурации"
            echo "  database - Бэкап только базы данных"
            echo "  restore  - Восстановление из бэкапа"
            echo "  list     - Список доступных бэкапов"
            echo "  verify   - Проверка целостности бэкапа"
            exit 1
            ;;
    esac
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi