#!/bin/bash

# =============================================================================
# Quick Security Setup Script
# =============================================================================
# Быстрая настройка безопасности для VPN сервера
# Использование: ./quick_setup.sh
# =============================================================================

set -euo pipefail

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Запустите скрипт с sudo"
        exit 1
    fi
}

# Быстрая настройка
quick_setup() {
    log_info "Начало быстрой настройки безопасности VPN сервера..."
    
    # 1. Обновление системы
    log_info "Обновление системы..."
    apt update && apt upgrade -y
    
    # 2. Установка необходимых пакетов
    log_info "Установка пакетов..."
    apt install -y curl wget git ufw fail2ban docker.io docker-compose nginx certbot python3-certbot-nginx
    
    # 3. Настройка Firewall
    log_info "Настройка Firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw allow 2053/tcp
    ufw --force enable
    
    # 4. Настройка Fail2Ban
    log_info "Настройка Fail2Ban..."
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    # 5. Настройка SSH
    log_info "Настройка SSH безопасности..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
    
    # 6. Создание пользователя deploy
    log_info "Создание пользователя deploy..."
    if ! id "deploy" &>/dev/null; then
        useradd -m -s /bin/bash deploy
        usermod -aG sudo,docker deploy
        mkdir -p /home/deploy/.ssh
        chmod 700 /home/deploy/.ssh
        touch /home/deploy/.ssh/authorized_keys
        chmod 600 /home/deploy/.ssh/authorized_keys
        chown -R deploy:deploy /home/deploy/.ssh
    fi
    
    # 7. Настройка Nginx для страницы-заглушки
    log_info "Настройка Nginx..."
    mkdir -p /var/www/html
    
    # Создаем простую страницу заглушку
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>System Maintenance</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; background: #f5f5f5; }
        .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; line-height: 1.6; }
        .status { background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 System Maintenance</h1>
        <p>We're currently performing scheduled maintenance to improve our services.</p>
        <div class="status">
            <strong>Status:</strong> Maintenance Mode<br>
            <strong>Estimated Time:</strong> 2 hours<br>
            <strong>Progress:</strong> 75%
        </div>
        <p>We'll be back shortly. Thank you for your patience!</p>
    </div>
</body>
</html>
EOF
    
    # Конфигурация Nginx
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    server_name _;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    server_tokens off;
    
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    location ~ /\. {
        deny all;
    }
}
EOF
    
    nginx -t && systemctl restart nginx
    systemctl enable nginx
    
    # 8. Создание директорий для проекта
    log_info "Создание директорий..."
    mkdir -p /opt/vpn-server/{backups,configs,logs,scripts}
    chown -R deploy:deploy /opt/vpn-server
    
    # 9. Настройка системных параметров
    log_info "Настройка системных параметров..."
    cat >> /etc/sysctl.conf << 'EOF'

# Network security
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.tcp_max_syn_backlog = 2048
EOF
    sysctl -p
    
    # 10. Настройка логирования
    log_info "Настройка логирования..."
    mkdir -p /var/log/vpn-server
    chmod 755 /var/log/vpn-server
    
    log_success "Быстрая настройка безопасности завершена!"
    
    echo
    log_warning "ВАЖНЫЕ СЛЕДУЮЩИЕ ШАГИ:"
    echo "1. Добавьте ваш SSH ключ: sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/ && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys"
    echo "2. Переключитесь на пользователя deploy: su - deploy"
    echo "3. Клонируйте репозиторий проекта"
    echo "4. Настройте 3x-ui панель"
    echo "5. Настройте SSL сертификат: sudo certbot --nginx -d your-domain.com"
    echo
    log_info "Сервер будет перезагружен через 10 секунд..."
    sleep 10
    reboot
}

# Главное меню
main() {
    check_root
    quick_setup
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi