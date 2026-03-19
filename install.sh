#!/bin/bash

clear

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
echo "==========================================="
echo "        DarkXD Installer v1.0"
echo "   Installer Powered By VortexNode"
echo "==========================================="
echo -e "${NC}"

sleep 1

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

# Update system
echo -e "${CYAN}Updating system...${NC}"
apt update -y && apt upgrade -y

# Install dependencies
echo -e "${CYAN}Installing required packages...${NC}"
apt install -y curl wget sudo tar unzip

clear
echo -e "${GREEN}What would you like to install?${NC}"
echo "1) Install Pterodactyl Panel"
echo "2) Install Wings"
echo "3) Install Panel + Wings"
echo "4) Exit"
echo ""

read -p "Enter option number: " option

if [ "$option" = "1" ]; then
    echo -e "${CYAN}Installing Panel...${NC}"
    bash <(curl -s https://pterodactyl-installer.se)
elif [ "$option" = "2" ]; then
    echo -e "${CYAN}Installing Wings...${NC}"
    bash <(curl -s https://pterodactyl-installer.se)
elif [ "$option" = "3" ]; then
    echo -e "${CYAN}Installing Panel + Wings...${NC}"
    bash <(curl -s https://pterodactyl-installer.se)
elif [ "$option" = "4" ]; then
    echo "Exiting..."
    exit 0
else
    echo -e "${RED}Invalid option.${NC}"
fi

echo ""
echo -e "${GREEN}Installation process completed.${NC}"
