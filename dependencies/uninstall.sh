#!/bin/bash
# Comparatron Unified Uninstallation Script
# Removes Comparatron installation and configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Uninstallation ===${NC}"

# Check if LaserWeb4 is installed and running
LASERWEB_INSTALLED=false
if [ -d "$HOME/LaserWeb" ] || [ -d "$HOME/LaserWeb4" ] || [ -f "/etc/systemd/system/lw-comm-server.service" ] || [ -f "/etc/systemd/system/laserweb.service" ]; then
    LASERWEB_INSTALLED=true
    echo -e "${YELLOW}LaserWeb4 detected on system - will preserve shared resources${NC}"
else
    echo -e "${GREEN}LaserWeb4 not detected - safe to remove all resources${NC}"
fi

echo -e "${YELLOW}Removing Comparatron services...${NC}"

# Remove Comparatron systemd service
if [ -f "/etc/systemd/system/comparatron.service" ]; then
    if command -v sudo &> /dev/null; then
        sudo systemctl stop comparatron.service 2>/dev/null || true
        sudo systemctl disable comparatron.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/comparatron.service
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
if command -v sudo &> /dev/null; then
    sudo systemctl daemon-reload 2>/dev/null || true
else
    systemctl daemon-reload 2>/dev/null || true
fi

# Remove any old virtual environment if it exists (cleanup of old venv installations)
echo -e "${YELLOW}Removing old virtual environment if it exists (cleanup)...${NC}"
if [ -d "../comparatron_env" ]; then
    rm -rf "../comparatron_env"
    echo -e "${GREEN}Removed old Comparatron virtual environment from project directory${NC}"
else
    echo -e "${YELLOW}Old Comparatron virtual environment not found in project directory${NC}"
fi

# Check if the virtual environment exists in the home directory (older installations)
if [ -d "$HOME/comparatron_env" ]; then
    rm -rf "$HOME/comparatron_env"
    echo -e "${GREEN}Removed old Comparatron virtual environment from home directory${NC}"
else
    echo -e "${YELLOW}Old Comparatron virtual environment not found in home directory${NC}"
fi

# Get the original user who invoked sudo
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$USER"
fi

# Handle dialout group membership carefully - only remove if LaserWeb4 is NOT installed
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}LaserWeb4 is installed - preserving dialout group access for serial communication${NC}"
    echo -e "${GREEN}User remains in dialout group (needed for both Comparatron and LaserWeb4)${NC}"
else
    # Only try to remove from dialout group if LaserWeb4 is not installed
    if command -v sudo &> /dev/null; then
        sudo deluser $TARGET_USER dialout 2>/dev/null || echo -e "${YELLOW}Could not remove from dialout group (may not exist or not be removable)${NC}"
        echo -e "${GREEN}Removed user from dialout group${NC}"
    else
        echo -e "${YELLOW}No sudo available to remove from dialout group${NC}"
    fi
fi

# Handle video group membership carefully - only remove if LaserWeb4 is NOT installed
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}LaserWeb4 is installed - preserving video group access for camera functionality${NC}"
    echo -e "${GREEN}User remains in video group (needed for both Comparatron and LaserWeb4)${NC}"
else
    # Only try to remove from video group if LaserWeb4 is not installed
    if command -v sudo &> /dev/null; then
        sudo deluser $TARGET_USER video 2>/dev/null || echo -e "${YELLOW}Could not remove from video group (may not exist or not be removable)${NC}"
        echo -e "${GREEN}Removed user from video group${NC}"
    else
        echo -e "${YELLOW}No sudo available to remove from video group${NC}"
    fi
fi

# Uninstall python packages only if --remove-all or --complete flag is provided
if [ "$1" = "--remove-all" ] || [ "$1" = "--complete" ]; then
    echo -e "${YELLOW}Removing Comparatron Python packages from system (complete removal)...${NC}"
    
    # Get the requirements file to identify packages to remove
    REQUIREMENTS_FILE="../dependencies/requirements.txt"
    if [ -f "$REQUIREMENTS_FILE" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[^#].*== ]]; then
                # Extract package name (before the ==)
                PKG_NAME=$(echo "$line" | cut -d'=' -f1)
                
                if [ -n "$PKG_NAME" ]; then
                    echo -e "${YELLOW}Uninstalling $PKG_NAME...${NC}"
                    if command -v pip3 &> /dev/null; then
                        pip3 uninstall -y "$PKG_NAME" 2>/dev/null || true
                    elif command -v python3 &> /dev/null; then
                        python3 -m pip uninstall -y "$PKG_NAME" 2>/dev/null || true
                    fi
                fi
            fi
        done < "$REQUIREMENTS_FILE"
        echo -e "${GREEN}Python packages uninstalled${NC}"
    else
        echo -e "${YELLOW}Requirements file not found, skipping package removal${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Python package removal (use --remove-all to completely remove Python packages)${NC}"
fi

# Remove any comparatron config files
echo -e "${YELLOW}Removing Comparatron configuration files...${NC}"

# Remove any comparatron config files
rm -f "$HOME/comparatron_config.json" 2>/dev/null || true
rm -f "$HOME/.comparatron_config" 2>/dev/null || true

# Remove any leftover files
rm -f requirements.txt 2>/dev/null || true
rm -f ../troubleshoot_service.sh 2>/dev/null || true

# Remove any custom user groups assignments (just informational)
echo -e "${YELLOW}User groups information:${NC}"
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}Note: LaserWeb4 is installed, so user remains in video and dialout groups${NC}"
else
    echo -e "${YELLOW}To fully reverse group assignments, manually remove user from groups:${NC}"
    echo -e "${YELLOW}  sudo deluser $USER video${NC}"
    echo -e "${YELLOW}  sudo deluser $USER dialout${NC}"
fi

echo -e "${GREEN}=== Comparatron Uninstallation completed ===${NC}"
echo -e "${GREEN}Comparatron components have been removed.${NC}"
echo -e "${GREEN}Note: The source directory remains untouched (comparatron-optimised).${NC}"
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${GREEN}LaserWeb4 components have been preserved and should continue working.${NC}"
else
    echo -e "${GREEN}No LaserWeb4 components detected, all safe to remove.${NC}"
fi
echo -e "${GREEN}You may need to restart your system for all changes to take effect.${NC}"