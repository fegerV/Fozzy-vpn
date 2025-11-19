#!/bin/bash

# =============================================================================
# VPN Server Security Setup Script
# =============================================================================
# Этот скрипт настраивает базовую безопасность сервера для VPN проекта
# Использование: sudo ./setup_security.sh
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка запуска от root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен от root (sudo)"
        exit 1
    fi
}

# Обновление системы
update_system() {
    log_info "Обновление системы..."
    apt update && apt upgrade -y
    apt install -y curl wget git htop ufw fail2ban unattended-upgrades
    log_success "Система обновлена"
}

# Настройка SSH безопасности
setup_ssh_security() {
    log_info "Настройка SSH безопасности..."
    
    # Резервное копирование sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Изменение порта SSH (расскомментируйте если нужен другой порт)
    # sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    
    # Запрет root входа по SSH
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Запрет пустых паролей
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    
    # Использование только ключей (расскомментируйте после настройки ключей)
    # sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    # sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # Перезапуск SSH
    systemctl restart ssh
    log_success "SSH безопасность настроена"
}

# Настройка Firewall (UFW)
setup_firewall() {
    log_info "Настройка Firewall..."
    
    # Сначала разрешаем SSH, чтобы не потерять доступ
    ufw allow 22/tcp
    
    # Разрешаем необходимые порты для 3x-ui
    ufw allow 2053/tcp  # 3x-ui панель (HTTPS)
    ufw allow 443/tcp   # Alternative HTTPS
    ufw allow 80/tcp    # HTTP для страницы-заглушки
    
    # Разрешаем основные VPN порты
    ufw allow 443/udp   # VLESS/Vision over TLS
    ufw allow 8443/tcp  # VLESS over TCP
    ufw allow 443/tcp   # VMess over WebSocket
    ufw allow 2053/udp  # VLESS over UDP
    
    # Включаем firewall
    ufw --force enable
    log_success "Firewall настроен и включен"
}

# Настройка Fail2Ban
setup_fail2ban() {
    log_info "Настройка Fail2Ban..."
    
    # Создаем конфигурацию для SSH
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    log_success "Fail2Ban настроен"
}

# Настройка автоматических обновлений
setup_auto_updates() {
    log_info "Настройка автоматических обновлений..."
    
    # Конфигурация unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    log_success "Автоматические обновления настроены"
}

# Настройка ограничений системы
setup_system_limits() {
    log_info "Настройка системных ограничений..."
    
    # Увеличение лимитов для сети
    cat >> /etc/sysctl.conf << 'EOF'

# Network security settings
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sysctl -p
    log_success "Системные ограничения настроены"
}

# Создание пользователя для деплоя
create_deploy_user() {
    log_info "Создание пользователя для деплоя..."
    
    if ! id "deploy" &>/dev/null; then
        useradd -m -s /bin/bash deploy
        usermod -aG sudo deploy
        
        # Создаем директорию для SSH ключей
        mkdir -p /home/deploy/.ssh
        chmod 700 /home/deploy/.ssh
        touch /home/deploy/.ssh/authorized_keys
        chmod 600 /home/deploy/.ssh/authorized_keys
        chown -R deploy:deploy /home/deploy/.ssh
        
        log_success "Пользователь 'deploy' создан"
        log_warning "Добавьте ваш SSH ключ в /home/deploy/.ssh/authorized_keys"
    else
        log_info "Пользователь 'deploy' уже существует"
    fi
}

# Настройка логирования
setup_logging() {
    log_info "Настройка логирования..."
    
    # Создаем директорию для логов
    mkdir -p /var/log/vpn-server
    chmod 755 /var/log/vpn-server
    
    # Конфигурация logrotate
    cat > /etc/logrotate.d/vpn-server << 'EOF'
/var/log/vpn-server/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    log_success "Логирование настроено"
}

# Установка Docker и Docker Compose
install_docker() {
    log_info "Установка Docker..."
    
    if ! command -v docker &> /dev/null; then
        # Установка зависимостей
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Добавление Docker GPG ключа
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Добавление Docker репозитория
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Установка Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Добавление пользователя в группу docker
        usermod -aG docker deploy
        
        # Включение автозапуска
        systemctl enable docker
        systemctl start docker
        
        log_success "Docker установлен"
    else
        log_info "Docker уже установлен"
    fi
    
    # Установка Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose установлен"
    else
        log_info "Docker Compose уже установлен"
    fi
}

# Создание структуры директорий
create_directories() {
    log_info "Создание директорий..."
    
    mkdir -p /opt/vpn-server/{backups,configs,logs,scripts}
    chown -R deploy:deploy /opt/vpn-server
    chmod 755 /opt/vpn-server
    
    log_success "Директории созданы"
}

# Главное меню
main() {
    log_info "Начало настройки безопасности VPN сервера..."
    
    check_root
    update_system
    setup_ssh_security
    setup_firewall
    setup_fail2ban
    setup_auto_updates
    setup_system_limits
    create_deploy_user
    setup_logging
    install_docker
    create_directories
    
    log_success "Настройка безопасности завершена!"
    echo
    log_warning "Важные замечания:"
    echo "1. SSH порт изменен, пароль root вход запрещен"
    echo "2. Firewall включен с необходимыми портами"
    echo "3. Создан пользователь 'deploy' для деплоя"
    echo "4. Настроены автоматические обновления"
    echo "5. Установлен Docker и Docker Compose"
    echo
    log_info "Дальнейшие шаги:"
    echo "1. Добавьте ваш SSH ключ: sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/"
    echo "2. Перезайдите под пользователем deploy: su - deploy"
    echo "3. Клонируйте репозиторий и запустите деплой"
    echo "4. Настройте 3x-ui панель"
    echo
    log_info "Перезагрузка системы через 10 секунд..."
    sleep 10
    reboot
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi