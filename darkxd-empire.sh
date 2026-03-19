#!/bin/bash

############################################################
#                DARKXD EMPIRE INSTALLER                   #
#            FINAL ENTERPRISE IMPERIAL EDITION             #
############################################################

VERSION="5.0.0"
CONFIG="/etc/darkxd-empire.conf"
LOG="/var/log/darkxd-empire.log"
PANEL_DIR="/opt/darkxd"
SERVICE="/etc/systemd/system/darkxd.service"

RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
CYAN="\e[36m"; RESET="\e[0m"

log(){ echo -e "$1"; echo "$(date) - $1" >> $LOG; }
fail(){ log "${RED}✘ $1${RESET}"; exit 1; }

### SYSTEM CHECKS ###

root_check(){ [[ $EUID -ne 0 ]] && fail "Run as root."; }

os_check(){
    source /etc/os-release
    [[ "$ID" != "ubuntu" && "$ID" != "debian" ]] && fail "Unsupported OS."
}

resource_check(){
    RAM=$(free -m | awk '/Mem:/ {print $2}')
    DISK=$(df / | awk 'NR==2 {print $4}')
    [[ $DISK -lt 1048576 ]] && fail "Low disk space."

    if [[ $RAM -lt 1024 ]]; then
        log "${YELLOW}Low RAM detected → Creating swap${RESET}"
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
    fi
}

detect_ip(){
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
}

port_resolver(){
    if lsof -i:80 &>/dev/null; then
        log "${YELLOW}Port 80 in use.${RESET}"
        read -p "Stop conflicting service? (y/n): " ans
        if [[ $ans == "y" ]]; then
            fuser -k 80/tcp
        else
            read -p "Enter alternative port: " ALT_PORT
        fi
    fi
}

### BASE INSTALLATION ###

install_stack(){
    apt update -y && apt upgrade -y
    apt install -y curl wget git unzip nginx redis-server \
    mariadb-server fail2ban certbot python3-certbot-nginx \
    docker.io docker-compose nodejs npm ufw
}

secure_database(){
    DB_PASS=$(openssl rand -base64 16)
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';"
    echo "DB_ROOT_PASSWORD=$DB_PASS" >> $CONFIG
}

setup_firewall(){
    ufw allow 22
    ufw allow 80
    ufw allow 443
    ufw --force enable
}

### PANEL DEPLOYMENT ###

deploy_panel(){
    mkdir -p $PANEL_DIR
    cd $PANEL_DIR || exit
    git clone https://github.com/yourname/darkxd.git .
    npm install
    npm run build
}

create_service(){
cat > $SERVICE <<EOF
[Unit]
Description=DarkXD Empire Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PANEL_DIR
ExecStart=/usr/bin/node $PANEL_DIR/index.js
Restart=always
RestartSec=5
LimitNOFILE=65535
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable darkxd
systemctl start darkxd
}

### NGINX + SSL ###

setup_web(){
read -p "Enter domain: " DOMAIN

cat > /etc/nginx/sites-available/darkxd <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        limit_req zone=one burst=10 nodelay;
    }
}
EOF

ln -s /etc/nginx/sites-available/darkxd /etc/nginx/sites-enabled/
systemctl restart nginx
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
}

### BACKUP SYSTEM ###

backup(){
    FILE="/root/darkxd-backup-$(date +%F).tar.gz"
    tar -czf $FILE $PANEL_DIR
    log "${GREEN}Backup saved: $FILE${RESET}"
}

restore(){
    read -p "Backup file path: " FILE
    tar -xzf $FILE -C /
}

### AUTO UPDATE ###

enable_autoupdate(){
    (crontab -l 2>/dev/null; echo "0 4 * * * cd $PANEL_DIR && git pull && npm install && systemctl restart darkxd") | crontab -
}

### HEALTH CHECK ###

health_check(){
    systemctl status darkxd
    docker ps
    free -m
}

### UNINSTALL ###

uninstall(){
    systemctl stop darkxd
    rm -rf $PANEL_DIR
    rm -f $SERVICE
    systemctl daemon-reload
    log "${RED}Empire Removed.${RESET}"
}

### MENU ###

menu(){
clear
echo -e "${CYAN}"
echo "=============================================="
echo "          DARKXD EMPIRE INSTALLER"
echo "=============================================="
echo -e "${RESET}"
echo "IP: $PUBLIC_IP"
echo ""
echo "1) Full Empire Install"
echo "2) Setup Web + SSL"
echo "3) Backup"
echo "4) Restore"
echo "5) Enable Auto Update"
echo "6) Health Check"
echo "7) Uninstall Empire"
echo "0) Exit"
echo ""
read -p "Select: " opt

case $opt in
1)
    install_stack
    secure_database
    setup_firewall
    deploy_panel
    create_service
    ;;
2) setup_web ;;
3) backup ;;
4) restore ;;
5) enable_autoupdate ;;
6) health_check ;;
7) uninstall ;;
0) exit ;;
*) echo "Invalid option";;
esac

read -p "Press Enter..."
menu
}

### BOOT SEQUENCE ###

root_check
os_check
resource_check
detect_ip
port_resolver
menu
