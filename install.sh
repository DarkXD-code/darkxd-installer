#!/bin/bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
NC="\e[0m"

clear

banner() {
echo -e "${RED}"
echo "=========================================="
echo "        DarkXD Installer v2.0"
echo "=========================================="
echo -e "${NC}"
}

check_root() {
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi
}

detect_os() {
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo -e "${CYAN}Detected OS: $NAME${NC}"
else
  echo -e "${RED}Unsupported OS${NC}"
  exit 1
fi
}

install_panel() {
echo -e "${GREEN}Installing Pterodactyl Panel...${NC}"
bash <(curl -s https://pterodactyl-installer.se)
}

install_wings() {
echo -e "${GREEN}Installing Wings...${NC}"
bash <(curl -s https://pterodactyl-installer.se)
}

menu() {
while true; do
echo ""
echo "1) Install Panel"
echo "2) Install Wings"
echo "3) Install Both"
echo "4) Exit"
echo ""

read -p "Choose option: " option

case $option in
  1) install_panel ;;
  2) install_wings ;;
  3) install_panel; install_wings ;;
  4) exit 0 ;;
  *) echo -e "${RED}Invalid option.${NC}" ;;
esac
done
}

# Run script
banner
check_root
detect_os
menu
