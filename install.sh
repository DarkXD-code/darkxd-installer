#!/bin/bash

############################################################
#                 DARKXD INSTALLER                         #
#               ULTIMATE ENTERPRISE EDITION                #
############################################################

VERSION="4.0.0"
CONFIG_FILE="/etc/darkxd/config.json"
LOG_FILE="/var/log/darkxd.log"
PANEL_DIR="/var/www/darkxd"
SERVICE_FILE="/etc/systemd/system/darkxd.service"

RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"

###########################
# Logging System
###########################

log() {
    echo -e "$1"
    echo -e "$(date) - $1" >> $LOG_FILE
}

error_exit() {
    log "${RED}Error: $1${RESET}"
    exit 1
}

###########################
# System Validation
###########################

check_root() {
    [[ $EUID -ne 0 ]] && error_exit "Run as root."
}

check_os() {
    source /etc/os-release
    [[ "$ID" != "ubuntu" && "$ID" != "debian" ]] && error_exit "Unsupported OS."
}

check_ram() {
    RAM=$(free -m | awk '/Mem:/ {print $2}')
    if [[ $RAM -lt 1024 ]]; then
        log "${YELLOW}Low RAM detected. Creating swap...${RESET}"
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
    fi
}

check_disk() {
    DISK=$(df / | awk 'NR==2 {print $4}')
    [[ $DISK -lt 1048576 ]] && error_exit "Not enough disk space."
}

check_ports() {
    for PORT in 80 443; do
        lsof -i:$PORT &>/dev/null && error_exit "Port $PORT already in use."
    done
}

detect_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
}

###########################
# Base Install
###########################

install_packages() {
    apt update -y && apt upgrade -y
    apt install -y curl wget git unzip nginx ufw redis-server \
    mariadb-server fail2ban certbot python3-certbot-nginx \
    docker.io docker-compose nodejs npm
}

secure_mariadb() {
    DB_PASS=$(openssl rand -base64 16)
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';"
    echo "Database Root Password: $DB_PASS"
}

setup_firewall() {
    ufw allow 22
    ufw allow 80
    ufw allow 443
    ufw --force enable
}

###########################
# Panel Installation
###########################

install_panel() {
    mkdir -p $PANEL_DIR
    cd $PANEL_DIR || exit
    git clone https://github.com/yourname/darkxd.git .
    npm install
    npm run build
}

create_service() {
cat > $SERVICE_FILE <<EOF
[Unit]
Description=DarkXD Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PANEL_DIR
ExecStart=/usr/bin/node $PANEL_DIR/index.js
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable darkxd
systemctl start darkxd
}

###########################
# Nginx Reverse Proxy
###########################

setup_nginx() {
read -p "Enter your domain: " DOMAIN

cat > /etc/nginx/sites-available/darkxd <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/darkxd /etc/nginx/sites-enabled/
systemctl restart nginx
certbot --nginx -d $DOMAIN
}

###########################
# Backup & Restore
###########################

backup_panel() {
    tar -czf /root/darkxd-backup-$(date +%F).tar.gz $PANEL_DIR
}

restore_panel() {
    read -p "Enter backup file path: " FILE
    tar -xzf $FILE -C /
}

###########################
# Update System
###########################

auto_update() {
    (crontab -l 2>/dev/null; echo "0 3 * * * cd $PANEL_DIR && git pull && npm install && systemctl restart darkxd") | crontab -
}

###########################
# Uninstall
###########################

uninstall_all() {
    systemctl stop darkxd
    rm -rf $PANEL_DIR
    rm -f $SERVICE_FILE
    systemctl daemon-reload
}

###########################
# Menu
###########################

main_menu() {
clear
echo -e "${CYAN}"
echo "============================================="
echo "          DARKXD INSTALLER ULTIMATE"
echo "============================================="
echo -e "${RESET}"
echo "Server IP: $PUBLIC_IP"
echo ""
echo "1) Full Enterprise Install"
echo "2) Setup Nginx + SSL"
echo "3) Backup Panel"
echo "4) Restore Panel"
echo "5) Enable Auto Update"
echo "6) Uninstall Everything"
echo "0) Exit"
echo ""
read -p "Select option: " opt

case $opt in
1)
    install_packages
    secure_mariadb
    setup_firewall
    install_panel
    create_service
    ;;
2) setup_nginx ;;
3) backup_panel ;;
4) restore_panel ;;
5) auto_update ;;
6) uninstall_all ;;
0) exit ;;
*) echo "Invalid option" ;;
esac

read -p "Press Enter to continue..."
main_menu
}

###########################
# Boot
###########################

check_root
check_os
check_ram
check_disk
check_ports
detect_public_ip
main_menu
