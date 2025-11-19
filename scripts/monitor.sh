#!/bin/bash

# =============================================================================
# VPN Server Monitoring Script
# =============================================================================
# Скрипт мониторинга безопасности и производительности VPN сервера
# Использование: ./monitor.sh [check|report|alert]
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
LOG_FILE="/var/log/vpn-server/monitoring.log"
ALERT_EMAIL="admin@your-domain.com"
DISK_WARNING=80
MEMORY_WARNING=85
CPU_WARNING=90
CONNECTION_WARNING=1000

# Функции для вывода
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка дискового пространства
check_disk_space() {
    log "Проверка дискового пространства..."
    
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt "$DISK_WARNING" ]; then
        log_warning "Дисковое пространство критически: ${disk_usage}%"
        send_alert "Критическое дисковое пространство: ${disk_usage}%"
        return 1
    elif [ "$disk_usage" -gt $((DISK_WARNING - 10)) ]; then
        log_warning "Дисковое пространство высокое: ${disk_usage}%"
        return 1
    else
        log_success "Дисковое пространство в норме: ${disk_usage}%"
        return 0
    fi
}

# Проверка использования памяти
check_memory() {
    log "Проверка использования памяти..."
    
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$memory_usage" -gt "$MEMORY_WARNING" ]; then
        log_warning "Использование памяти критическое: ${memory_usage}%"
        send_alert "Критическое использование памяти: ${memory_usage}%"
        return 1
    elif [ "$memory_usage" -gt $((MEMORY_WARNING - 10)) ]; then
        log_warning "Использование памяти высокое: ${memory_usage}%"
        return 1
    else
        log_success "Использование памяти в норме: ${memory_usage}%"
        return 0
    fi
}

# Проверка загрузки CPU
check_cpu() {
    log "Проверка загрузки CPU..."
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    
    # Преобразуем в целое число
    cpu_usage=${cpu_usage%.*}
    
    if [ "$cpu_usage" -gt "$CPU_WARNING" ]; then
        log_warning "Загрузка CPU критическая: ${cpu_usage}%"
        send_alert "Критическая загрузка CPU: ${cpu_usage}%"
        return 1
    elif [ "$cpu_usage" -gt $((CPU_WARNING - 20)) ]; then
        log_warning "Загрузка CPU высокая: ${cpu_usage}%"
        return 1
    else
        log_success "Загрузка CPU в норме: ${cpu_usage}%"
        return 0
    fi
}

# Проверка сетевых соединений
check_connections() {
    log "Проверка сетевых соединений..."
    
    local connections=$(netstat -an | grep :443 | grep ESTABLISHED | wc -l)
    
    if [ "$connections" -gt "$CONNECTION_WARNING" ]; then
        log_warning "Много сетевых соединений: $connections"
        send_alert "Много сетевых соединений: $connections"
        return 1
    else
        log_success "Сетевые соединения в норме: $connections"
        return 0
    fi
}

# Проверка статуса сервисов
check_services() {
    log "Проверка статуса сервисов..."
    
    local failed_services=()
    
    # Проверка Docker контейнеров
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "vpn_bot.*Up"; then
        failed_services+=("VPN Bot")
    fi
    
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "vpn_bot_db.*Up"; then
        failed_services+=("PostgreSQL")
    fi
    
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "nginx.*Up"; then
        failed_services+=("Nginx")
    fi
    
    # Проверка 3x-ui сервиса
    if ! systemctl is-active --quiet x-ui; then
        failed_services+=("3x-ui")
    fi
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "Все сервисы работают нормально"
        return 0
    else
        log_warning "Проблемы с сервисами: ${failed_services[*]}"
        send_alert "Проблемы с сервисами: ${failed_services[*]}"
        return 1
    fi
}

# Проверка безопасности
check_security() {
    log "Проверка безопасности..."
    
    local security_issues=()
    
    # Проверка неудачных попыток входа
    local failed_logins=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
    if [ "$failed_logins" -gt 10 ]; then
        security_issues+=("Много неудачных попыток входа: $failed_logins")
    fi
    
    # Проверка открытых портов
    local suspicious_ports=$(netstat -tuln | grep -E ":(666|1337|31337|12345)" | wc -l)
    if [ "$suspicious_ports" -gt 0 ]; then
        security_issues+=("Подозрительные порты открыты: $suspicious_ports")
    fi
    
    # Проверка статуса firewall
    if ! ufw status | grep -q "Status: active"; then
        security_issues+=("Firewall не активен")
    fi
    
    # Проверка статуса fail2ban
    if ! systemctl is-active --quiet fail2ban; then
        security_issues+=("Fail2Ban не активен")
    fi
    
    if [ ${#security_issues[@]} -eq 0 ]; then
        log_success "Проблемы безопасности не обнаружены"
        return 0
    else
        log_warning "Обнаружены проблемы безопасности:"
        for issue in "${security_issues[@]}"; do
            log_warning "  - $issue"
        done
        send_alert "Проблемы безопасности: ${security_issues[*]}"
        return 1
    fi
}

# Проверка 3x-ui статуса
check_3x_ui() {
    log "Проверка 3x-ui статуса..."
    
    # Проверка доступности API
    if curl -s -k https://localhost:2053/login > /dev/null; then
        log_success "3x-ui API доступен"
        return 0
    else
        log_warning "3x-ui API недоступен"
        send_alert "3x-ui API недоступен"
        return 1
    fi
}

# Отправка алертов
send_alert() {
    local message="$1"
    local subject="[VPN SERVER ALERT] $message"
    
    # Отправка email (настройте mailutils)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    fi
    
    # Отправка в Telegram (настройте bot)
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$subject: $message"
    fi
}

# Генерация отчета
generate_report() {
    log "Генерация отчета о состоянии сервера..."
    
    local report_file="/var/log/vpn-server/report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== VPN SERVER MONITORING REPORT ==="
        echo "Дата: $(date)"
        echo "Сервер: $(hostname)"
        echo "Uptime: $(uptime -p)"
        echo ""
        
        echo "=== СИСТЕМНЫЕ РЕСУРСЫ ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)")"
        echo "Память: $(free -h)"
        echo "Диск: $(df -h /)"
        echo "Сетевые соединения: $(netstat -an | grep ESTABLISHED | wc -l)"
        echo ""
        
        echo "=== СТАТУС СЕРВИСОВ ==="
        echo "Docker контейнеры:"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        echo ""
        echo "Системные сервисы:"
        systemctl list-units --type=service --state=running | grep -E "(nginx|fail2ban|ufw|x-ui)"
        echo ""
        
        echo "=== БЕЗОПАСНОСТЬ ==="
        echo "Firewall: $(ufw status | head -1)"
        echo "Fail2ban: $(systemctl is-active fail2ban)"
        echo "Неудачные входы сегодня: $(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)"
        echo ""
        
        echo "=== 3X-UI СТАТУС ==="
        if curl -s -k https://localhost:2053/login > /dev/null; then
            echo "3x-ui API: Доступен"
        else
            echo "3x-ui API: Недоступен"
        fi
        echo ""
        
        echo "=== ПОСЛЕДНИЕ ЛОГИ ==="
        echo "Последние 5 записей из monitoring.log:"
        tail -5 "$LOG_FILE"
    } > "$report_file"
    
    log_success "Отчет сохранен: $report_file"
    echo "$report_file"
}

# Основная проверка
run_checks() {
    log "Запуск комплексной проверки..."
    
    local issues=0
    
    check_disk_space || ((issues++))
    check_memory || ((issues++))
    check_cpu || ((issues++))
    check_connections || ((issues++))
    check_services || ((issues++))
    check_security || ((issues++))
    check_3x_ui || ((issues++))
    
    if [ "$issues" -eq 0 ]; then
        log_success "Все проверки пройдены успешно"
        return 0
    else
        log_warning "Обнаружено проблем: $issues"
        return 1
    fi
}

# Главное меню
main() {
    local action="${1:-check}"
    
    # Создаем директорию для логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "$action" in
        "check")
            run_checks
            ;;
        "report")
            generate_report
            ;;
        "alert")
            send_alert "Тестовый алерт"
            ;;
        "services")
            check_services
            ;;
        "security")
            check_security
            ;;
        *)
            echo "Использование: $0 [check|report|alert|services|security]"
            echo "  check     - Запустить все проверки"
            echo "  report    - Сгенерировать отчет"
            echo "  alert     - Отправить тестовый алерт"
            echo "  services  - Проверить статус сервисов"
            echo "  security  - Проверить безопасность"
            exit 1
            ;;
    esac
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi