#!/bin/bash

# ===== COLORS =====
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
NC="\e[0m"

clear

banner() {
echo -e "${RED}"
echo "=================================================="
echo "             DarkXD Installer v3.0"
echo "   Panel | Wings | Blueprints | Themes | Addons"
echo "=================================================="
echo -e "${NC}"
}

check_root() {
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Please run this script as root.${NC}"
  exit 1
fi
}

detect_os() {
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo -e "${CYAN}Detected OS: $NAME${NC}"
else
  echo -e "${RED}Unsupported OS.${NC}"
  exit 1
fi
}

update_system() {
echo -e "${YELLOW}Updating system...${NC}"
apt update -y && apt upgrade -y
}

install_panel() {
echo -e "${GREEN}Installing Pterodactyl Panel...${NC}"
bash <(curl -s https://pterodactyl-installer.se)
}

install_wings() {
echo -e "${GREEN}Installing Wings...${NC}"
bash <(curl -s https://pterodactyl-installer.se)
}

install_blueprint() {
echo -e "${GREEN}Installing Blueprint Extension...${NC}"
cd /var/www/pterodactyl || { echo -e "${RED}Panel not found!${NC}"; return; }

php artisan down
curl -L https://github.com/BlueprintFramework/framework/releases/latest/download/blueprint.tar.gz -o blueprint.tar.gz
tar -xzf blueprint.tar.gz
chmod -R 755 storage/*
php artisan up

echo -e "${GREEN}Blueprint Installed.${NC}"
}

install_theme() {
echo -e "${GREEN}Installing Theme...${NC}"
echo "Enter theme GitHub release URL:"
read theme_url

cd /var/www/pterodactyl || { echo -e "${RED}Panel not found!${NC}"; return; }

php artisan down
curl -L $theme_url -o theme.zip
unzip -o theme.zip
php artisan view:clear
php artisan up

echo -e "${GREEN}Theme Installed.${NC}"
}

install_addon() {
echo -e "${GREEN}Installing Panel Addon...${NC}"
echo "Enter addon GitHub release URL:"
read addon_url

cd /var/www/pterodactyl || { echo -e "${RED}Panel not found!${NC}"; return; }

php artisan down
curl -L $addon_url -o addon.zip
unzip -o addon.zip
php artisan migrate --seed --force
php artisan up

echo -e "${GREEN}Addon Installed.${NC}"
}

menu() {
while true; do
echo ""
echo "1) Install Panel"
echo "2) Install Wings"
echo "3) Install Blueprint"
echo "4) Install Theme"
echo "5) Install Addon"
echo "6) Install Everything"
echo "7) Exit"
echo ""

read -p "Choose option: " option

case $option in
  1) install_panel ;;
  2) install_wings ;;
  3) install_blueprint ;;
  4) install_theme ;;
  5) install_addon ;;
  6) install_panel; install_wings ;;
  7) exit 0 ;;
  *) echo -e "${RED}Invalid option.${NC}" ;;
esac
done
}

# ===== RUN SCRIPT =====
banner
check_root
detect_os
update_system
menu
