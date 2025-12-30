#!/bin/bash
# Comparatron Unified Uninstallation Script
# Removes Comparatron installation and configurations, with LaserWeb4 compatibility

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Uninstallation ===${NC}"

# Check if LaserWeb4 is installed and running
LASERWEB_INSTALLED=false
LASERWEB_SERVICES=()

# Check for various LaserWeb4 installation locations and services
if [ -d "$HOME/LaserWeb" ] || [ -d "$HOME/LaserWeb4" ] || [ -d "/opt/LaserWeb" ] || [ -d "/opt/LaserWeb4" ]; then
    LASERWEB_INSTALLED=true
    echo -e "${YELLOW}LaserWeb4 detected on system - will preserve shared resources${NC}"
else
    # Check for LaserWeb systemd services
    for service in "lw-comm-server.service" "laserweb.service" "lw-bridge.service" "laserweb4.service"; do
        if [ -f "/etc/systemd/system/$service" ] || [ -f "/lib/systemd/system/$service" ] || [ -f "/usr/lib/systemd/system/$service" ]; then
            LASERWEB_INSTALLED=true
            LASERWEB_SERVICES+=("$service")
        fi
    done

    if [ "$LASERWEB_INSTALLED" = true ]; then
        echo -e "${YELLOW}LaserWeb4 services detected: ${LASERWEB_SERVICES[*]} - will preserve shared resources${NC}"
    else
        echo -e "${GREEN}LaserWeb4 not detected - safe to remove all resources${NC}"
    fi
fi

echo -e "${YELLOW}This will remove Comparatron configurations, automation, and system changes.${NC}"

# Ask for confirmation
if [ "$LASERWEB_INSTALLED" = true ]; then
    read -p "Are you sure you want to uninstall Comparatron while preserving LaserWeb4? (y/N): " -n 1 -r
else
    read -p "Are you sure you want to uninstall Comparatron? (y/N): " -n 1 -r
fi
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
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
    echo -e "${YELLOW}Removing user from dialout group (serial access)...${NC}"
    if command -v sudo &> /dev/null; then
        # Check if the user is in the dialout group and remove them
        if groups $TARGET_USER | grep -q "\bdialout\b"; then
            sudo deluser $TARGET_USER dialout 2>/dev/null
            echo -e "${GREEN}User removed from dialout group${NC}"
        else
            echo -e "${YELLOW}User was not in dialout group${NC}"
        fi
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
    echo -e "${YELLOW}Removing user from video group (camera access)...${NC}"
    if command -v sudo &> /dev/null; then
        # Check if the user is in the video group and remove them
        if groups $TARGET_USER | grep -q "\bvideo\b"; then
            sudo deluser $TARGET_USER video 2>/dev/null
            echo -e "${GREEN}User removed from video group${NC}"
        else
            echo -e "${YELLOW}User was not in video group${NC}"
        fi
    else
        echo -e "${YELLOW}No sudo available to remove from video group${NC}"
    fi
fi

# Handle gpio group membership carefully - only remove if LaserWeb4 is NOT installed
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${YELLOW}LaserWeb4 is installed - preserving gpio group access for GPIO functionality${NC}"
    echo -e "${GREEN}User remains in gpio group (if on Raspberry Pi)${NC}"
else
    # Only try to remove from gpio group if LaserWeb4 is not installed
    echo -e "${YELLOW}Removing user from gpio group (if on Raspberry Pi)...${NC}"
    if command -v sudo &> /dev/null; then
        if getent group gpio > /dev/null 2>&1; then
            # Check if the user is in the gpio group and remove them
            if groups $TARGET_USER | grep -q "\bgpio\b"; then
                sudo deluser $TARGET_USER gpio 2>/dev/null
                echo -e "${GREEN}User removed from gpio group${NC}"
            else
                echo -e "${YELLOW}User was not in gpio group${NC}"
            fi
        else
            echo -e "${YELLOW}GPIO group not found (not on Raspberry Pi or no GPIO support)${NC}"
        fi
    else
        echo -e "${YELLOW}No sudo available to remove from gpio group${NC}"
    fi
fi

# Uninstall python packages only if --remove-all or --complete flag is provided
if [ "$1" = "--remove-all" ] || [ "$1" = "--complete" ]; then
    echo -e "${YELLOW}Removing Comparatron Python packages from system (complete removal)...${NC}"

    # Get the requirements file to identify packages to remove
    # Only requirements-simple.txt exists in the dependencies directory
    # The script runs from the dependencies subdirectory, so look in current directory
    REQUIREMENTS_FILE="./requirements-simple.txt"
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        echo -e "${YELLOW}Requirements file (requirements-simple.txt) not found, skipping package removal${NC}"
    else
        echo -e "${YELLOW}Using requirements-simple.txt for package uninstallation${NC}"
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi

            # Process lines that contain version specifiers (==, >=, etc.)
            if [[ "$line" == *"=="* ]] || [[ "$line" == *">="* ]]; then
                # Extract package name (before the == or >=)
                PKG_NAME=$(echo "$line" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 | cut -d'!' -f1 | xargs)

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

# Remove the system-wide comparatron command if it exists
echo -e "${YELLOW}Removing system-wide 'comparatron' command...${NC}"
if [ -L "/usr/local/bin/comparatron" ]; then
    if command -v sudo &> /dev/null; then
        sudo rm -f /usr/local/bin/comparatron
        echo -e "${GREEN}Removed 'comparatron' command from /usr/local/bin${NC}"
    else
        rm -f /usr/local/bin/comparatron
        echo -e "${GREEN}Removed 'comparatron' command from /usr/local/bin${NC}"
    fi
else
    echo -e "${YELLOW}'comparatron' command symlink not found in /usr/local/bin${NC}"
fi

# Final summary
echo -e "${GREEN}=== Comparatron Uninstallation completed ===${NC}"
echo -e "${GREEN}Comparatron components have been removed.${NC}"
echo -e "${GREEN}Note: The source directory remains untouched (comparatron-optimised).${NC}"
if [ "$LASERWEB_INSTALLED" = true ]; then
    echo -e "${GREEN}LaserWeb4 components have been preserved and should continue working.${NC}"
    echo -e "${GREEN}Shared resources (dialout, video, gpio groups) have been preserved for LaserWeb4.${NC}"
else
    echo -e "${GREEN}No LaserWeb4 components detected, all safe to remove.${NC}"
    echo -e "${GREEN}Removed resources included:${NC}"
    echo -e "${GREEN}- Systemd service${NC}"
    echo -e "${GREEN}- System-wide command${NC}"
    echo -e "${GREEN}- User group memberships (dialout, video, gpio)${NC}"
    echo -e "${GREEN}- Virtual environments${NC}"
    echo -e "${GREEN}- Configuration files${NC}"
fi
if [ "$1" = "--remove-all" ] || [ "$1" = "--complete" ]; then
    echo -e "${GREEN}- Python packages${NC}"
fi
echo -e "${GREEN}You may need to restart your system for all changes to take effect.${NC}"
echo -e "${GREEN}Log out and log back in to ensure all group membership changes take effect.${NC}"