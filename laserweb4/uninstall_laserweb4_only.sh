#!/bin/bash
# LaserWeb4 Only Uninstallation Script
# Removes only LaserWeb4 related installations and configurations
# PRESERVES shared resources if Comparatron is still installed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Only Uninstallation ===${NC}"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        echo -e "${RED}Error: sudo is required but not available.${NC}"
        exit 1
    fi
else
    SUDO=""
    echo -e "${GREEN}Running as root${NC}"
fi

# Check if Comparatron is installed and running
COMPARATRON_INSTALLED=false
if [ -f "/etc/systemd/system/comparatron.service" ] || [ -d "$HOME/Documents/comparatron-optimised" ]; then
    COMPARATRON_INSTALLED=true
    echo -e "${YELLOW}Comparatron detected on system - will preserve shared resources${NC}"
else
    echo -e "${GREEN}Comparatron not detected - safe to remove all resources${NC}"
fi

echo -e "${YELLOW}Removing LaserWeb4 services only...${NC}"

# Remove LaserWeb4 systemd services only
SERVICES_TO_REMOVE=("lw-comm-server.service" "laserweb-frontend.service" "laserweb.service")

for service in "${SERVICES_TO_REMOVE[@]}"; do
    if [ -f "/etc/systemd/system/$service" ]; then
        if [ -n "$SUDO" ]; then
            $SUDO systemctl stop $service 2>/dev/null || true
            $SUDO systemctl disable $service 2>/dev/null || true
            $SUDO rm -f "/etc/systemd/system/$service"
            echo -e "${GREEN}Removed LaserWeb4 service: $service${NC}"
        else
            systemctl stop $service 2>/dev/null || true
            systemctl disable $service 2>/dev/null || true
            rm -f "/etc/systemd/system/$service"
            echo -e "${GREEN}Removed LaserWeb4 service: $service${NC}"
        fi
    else
        echo -e "${YELLOW}LaserWeb4 service not found: $service${NC}"
    fi
done

# Reload systemd to remove the services
if [ -n "$SUDO" ]; then
    $SUDO systemctl daemon-reload 2>/dev/null || true
else
    systemctl daemon-reload 2>/dev/null || true
fi

# Remove nginx configuration for LaserWeb (if it exists)
if [ -n "$SUDO" ]; then
    $SUDO rm -f /etc/nginx/sites-available/laserweb 2>/dev/null || true
    $SUDO rm -f /etc/nginx/sites-enabled/laserweb 2>/dev/null || true
    $SUDO systemctl reload nginx 2>/dev/null || true
    echo -e "${GREEN}Removed LaserWeb4 nginx configuration${NC}"
fi

# Remove LaserWeb4 installation
echo -e "${YELLOW}Removing LaserWeb4 installation...${NC}"

# Remove LaserWeb4 directories
LW_DIRS=("$HOME/LaserWeb" "$HOME/LaserWeb4" "$HOME/laserweb")

for dir in "${LW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo -e "${GREEN}Removed LaserWeb4 installation directory: $dir${NC}"
    else
        echo -e "${YELLOW}LaserWeb4 directory not found: $dir${NC}"
    fi
done

# Remove LaserWeb4 virtual environment
LW_ENVS=("$HOME/laserweb_env" "$HOME/LaserWeb/venv" "$HOME/LaserWeb4/venv")

for env in "${LW_ENVS[@]}"; do
    if [ -d "$env" ]; then
        rm -rf "$env"
        echo -e "${GREEN}Removed LaserWeb4 virtual environment: $env${NC}"
    else
        echo -e "${YELLOW}LaserWeb4 virtual environment not found: $env${NC}"
    fi
done

# Do NOT remove Comparatron installation - that's separate
echo -e "${YELLOW}Skipping Comparatron installation - leaving intact${NC}"

# Do NOT remove Comparatron virtual environment - that's separate
echo -e "${YELLOW}Skipping Comparatron virtual environment - leaving intact${NC}"

# Remove only LaserWeb4 specific configuration files
echo -e "${YELLOW}Removing LaserWeb4 specific configuration files...${NC}"

# Remove LaserWeb4 config files
rm -f "$HOME/LaserWeb/config.json" 2>/dev/null || true
rm -f "$HOME/LaserWeb4/config.json" 2>/dev/null || true
rm -f "$HOME/LaserWeb/config.default.json" 2>/dev/null || true
rm -f "$HOME/LaserWeb4/default_config.json" 2>/dev/null || true

# Remove only LaserWeb4 startup script
rm -f "$HOME/start_laserweb.sh" 2>/dev/null || true

# Handle dialout group membership carefully - only remove if Comparatron is NOT installed
if [ "$COMPARATRON_INSTALLED" = true ]; then
    echo -e "${YELLOW}Comparatron is installed - preserving dialout group access for serial communication${NC}"
    echo -e "${GREEN}User remains in dialout group (needed for both LaserWeb4 and Comparatron)${NC}"
else
    # Only try to remove from dialout group if Comparatron is not installed
    if [ -n "$SUDO" ]; then
        $SUDO deluser $USER dialout 2>/dev/null || echo -e "${YELLOW}Could not remove from dialout group (may not exist or not be removable)${NC}"
        echo -e "${GREEN}Removed user from dialout group${NC}"
    else
        echo -e "${YELLOW}Cannot remove from dialout group without sudo${NC}"
    fi
fi

# Handle video group membership carefully - only remove if Comparatron is NOT installed
if [ "$COMPARATRON_INSTALLED" = true ]; then
    echo -e "${YELLOW}Comparatron is installed - preserving video group access for camera functionality${NC}"
    echo -e "${GREEN}User remains in video group (needed for both LaserWeb4 and Comparatron)${NC}"
else
    # Only try to remove from video group if Comparatron is not installed
    if [ -n "$SUDO" ]; then
        $SUDO deluser $USER video 2>/dev/null || echo -e "${YELLOW}Could not remove from video group (may not exist or not be removable)${NC}"
        echo -e "${GREEN}Removed user from video group${NC}"
    else
        echo -e "${YELLOW}Cannot remove from video group without sudo${NC}"
    fi
fi

# Note: The installation script creates a virtual environment which contains the packages,
# so we don't need to uninstall individual packages from system Python - that could affect other programs.
# The virtual environment contains all the required packages.
echo -e "${YELLOW}Note: LaserWeb4 packages were installed in virtual environment, no system packages to remove${NC}"

# Clean up any temporary files from this script
rm -f requirements.txt 2>/dev/null || true

echo -e "${GREEN}=== LaserWeb4 Only Uninstallation completed ===${NC}"
echo -e "${GREEN}LaserWeb4 components have been removed.${NC}"
echo -e "${GREEN}Note: The LaserWeb4 source directory remains untouched if it was separate.${NC}"
if [ "$COMPARATRON_INSTALLED" = true ]; then
    echo -e "${GREEN}Comparatron components have been preserved and should continue working.${NC}"
else
    echo -e "${GREEN}No Comparatron components detected, all safe to remove.${NC}"
fi
echo -e "${GREEN}You may need to restart your system for all changes to take effect.${NC}"