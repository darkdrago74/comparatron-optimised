#!/bin/bash
# Comparatron Only Uninstallation Script
# Removes only Comparatron related installations and configurations
# PRESERVES shared resources if LaserWeb4 is still installed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Only Uninstallation ===${NC}"

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

# Check if LaserWeb4 is installed and running
LASERWEB_INSTALLED=false
if [ -d "$HOME/LaserWeb" ] || [ -d "$HOME/LaserWeb4" ] || [ -f "/etc/systemd/system/lw-comm-server.service" ] || [ -f "/etc/systemd/system/laserweb.service" ]; then
    LASERWEB_INSTALLED=true
    echo -e "${YELLOW}LaserWeb4 detected on system - will preserve shared resources${NC}"
else
    echo -e "${GREEN}LaserWeb4 not detected - safe to remove all resources${NC}"
fi

echo -e "${YELLOW}Removing Comparatron services only...${NC}"

# Remove Comparatron systemd service only
if [ -f "/etc/systemd/system/comparatron.service" ]; then
    if [ -n "$SUDO" ]; then
        $SUDO systemctl stop comparatron.service 2>/dev/null || true
        $SUDO systemctl disable comparatron.service 2>/dev/null || true
        $SUDO rm -f /etc/systemd/system/comparatron.service
        echo -e "${GREEN}Removed Comparatron systemd service${NC}"
    else
        systemctl stop comparatron.service 2>/dev/null || true
        systemctl disable comparatron.service 2>/dev/null || true
        rm -f /etc/systemd/system/comparatron.service
        echo -e "${GREEN}Removed Comparatron systemd service${NC}"
    fi
else
    echo -e "${YELLOW}Comparatron service not found${NC}"
fi

# Reload systemd to remove the service
if [ -n "$SUDO" ]; then
    $SUDO systemctl daemon-reload 2>/dev/null || true
else
    systemctl daemon-reload 2>/dev/null || true
fi

# Remove Python virtual environments for Comparatron only
echo -e "${YELLOW}Removing Comparatron Python virtual environment...${NC}"
if [ -d "./comparatron_env" ]; then
    rm -rf "./comparatron_env"
    echo -e "${GREEN}Removed Comparatron virtual environment from current directory${NC}"
elif [ -d "$HOME/Documents/comparatron-optimised/comparatron_env" ]; then
    rm -rf "$HOME/Documents/comparatron-optimised/comparatron_env"
    echo -e "${GREEN}Removed Comparatron virtual environment from project directory${NC}"
else
    echo -e "${YELLOW}Comparatron virtual environment not found${NC}"
fi

# Check if the virtual environment exists in the home directory (older installations)
if [ -d "$HOME/comparatron_env" ]; then
    rm -rf "$HOME/comparatron_env"
    echo -e "${GREEN}Removed Comparatron virtual environment from home directory${NC}"
fi

# Do NOT remove LaserWeb4 installation - that's separate
echo -e "${YELLOW}Skipping LaserWeb4 installation removal - leaving intact${NC}"

# Do NOT remove LaserWeb4 virtual environment - that's separate
echo -e "${YELLOW}Skipping LaserWeb4 virtual environment removal - leaving intact${NC}"

# Remove Comparatron configuration files only
echo -e "${YELLOW}Removing Comparatron configuration files...${NC}"

# Remove any comparatron config files
rm -f "$HOME/comparatron_config.json" 2>/dev/null || true
rm -f "$HOME/.comparatron_config" 2>/dev/null || true

# Remove Comparatron startup script only
rm -f "$HOME/start_comparatron.sh" 2>/dev/null || true

# Remove any Comparatron related files in home directory
rm -f "$HOME/comparatron.log" 2>/dev/null || true

# Handle dialout group membership carefully - only remove if LaserWeb4 is NOT installed
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}LaserWeb4 is installed - preserving dialout group access for serial communication${NC}"
    echo -e "${GREEN}User remains in dialout group (needed for both Comparatron and LaserWeb4)${NC}"
else
    # Only try to remove from dialout group if LaserWeb4 is not installed
    if [ -n "$SUDO" ]; then
        $SUDO deluser $USER dialout 2>/dev/null || echo -e "${YELLOW}Could not remove from dialout group (may not exist or not be removable)${NC}"
        echo -e "${GREEN}Removed user from dialout group${NC}"
    else
        echo -e "${YELLOW}Cannot remove from dialout group without sudo${NC}"
    fi
fi

# Handle video group membership carefully - only remove if LaserWeb4 is NOT installed
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}LaserWeb4 is installed - preserving video group access for camera functionality${NC}"
    echo -e "${GREEN}User remains in video group (needed for both Comparatron and LaserWeb4)${NC}"
else
    # Only try to remove from video group if LaserWeb4 is not installed
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
echo -e "${YELLOW}Note: Comparatron packages were installed in virtual environment, no system packages to remove${NC}"

# Clean up any temporary files from this script
rm -f requirements.txt 2>/dev/null || true

echo -e "${GREEN}=== Comparatron Only Uninstallation completed ===${NC}"
echo -e "${GREEN}Comparatron components have been removed.${NC}"
echo -e "${GREEN}Note: The source directory remains untouched (comparatron-optimised).${NC}"
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${GREEN}LaserWeb4 components have been preserved and should continue working.${NC}"
else
    echo -e "${GREEN}No LaserWeb4 components detected, all safe to remove.${NC}"
fi
echo -e "${GREEN}You may need to restart your system for all changes to take effect.${NC}"