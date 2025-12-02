#!/bin/bash

# LaserWeb4 Uninstallation Script
# Removes all LaserWeb4 related installations and configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Uninstallation ===${NC}"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        SUDO=""
        echo -e "${YELLOW}Sudo not available, some operations may be skipped${NC}"
    fi
else
    SUDO=""
    echo -e "${GREEN}Running as root${NC}"
fi

echo -e "${YELLOW}Removing LaserWeb4 services...${NC}"

# Stop and disable systemd service if it exists
if [ -n "$SUDO" ]; then
    if [ -f "/etc/systemd/system/laserweb.service" ]; then
        $SUDO systemctl stop laserweb.service 2>/dev/null || true
        $SUDO systemctl disable laserweb.service 2>/dev/null || true
        $SUDO rm -f /etc/systemd/system/laserweb.service
        echo -e "${GREEN}Removed LaserWeb4 systemd service${NC}"
    else
        echo -e "${YELLOW}LaserWeb4 service not found${NC}"
    fi
else
    if [ -f "/etc/systemd/system/laserweb.service" ]; then
        systemctl stop laserweb.service 2>/dev/null || true
        systemctl disable laserweb.service 2>/dev/null || true
        rm -f /etc/systemd/system/laserweb.service
        echo -e "${GREEN}Removed LaserWeb4 systemd service${NC}"
    else
        echo -e "${YELLOW}LaserWeb4 service not found${NC}"
    fi
fi

# Remove nginx configuration for LaserWeb if it exists
if [ -n "$SUDO" ]; then
    if [ -f "/etc/nginx/sites-available/laserweb" ]; then
        $SUDO rm -f /etc/nginx/sites-available/laserweb 2>/dev/null || true
        $SUDO rm -f /etc/nginx/sites-enabled/laserweb 2>/dev/null || true
        $SUDO systemctl reload nginx 2>/dev/null || true
        echo -e "${GREEN}Removed LaserWeb4 nginx configuration${NC}"
    else
        echo -e "${YELLOW}LaserWeb4 nginx configuration not found${NC}"
    fi
fi

# Remove LaserWeb installation directory
if [ -d "$HOME/LaserWeb" ]; then
    rm -rf "$HOME/LaserWeb"
    echo -e "${GREEN}Removed LaserWeb installation directory${NC}"
else
    echo -e "${YELLOW}LaserWeb installation directory not found${NC}"
fi

# Remove start script
if [ -f "$HOME/start_laserweb.sh" ]; then
    rm -f "$HOME/start_laserweb.sh"
    echo -e "${GREEN}Removed LaserWeb start script${NC}"
else
    echo -e "${YELLOW}LaserWeb start script not found${NC}"
fi

# Remove any remaining temporary files
rm -f requirements.txt 2>/dev/null || true

echo -e "${GREEN}=== LaserWeb4 Uninstallation completed ===${NC}"
echo -e "${GREEN}LaserWeb4 and related configurations have been removed.${NC}"
echo -e "${GREEN}Note: This script does not uninstall Node.js or other system dependencies.${NC}"