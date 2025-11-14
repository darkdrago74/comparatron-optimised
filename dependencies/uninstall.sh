#!/bin/bash

# Comparatron and LaserWeb4 Uninstallation Script
# Removes all Comparatron and LaserWeb4 related installations and configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron and LaserWeb4 Uninstallation ===${NC}"

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

echo -e "${YELLOW}Removing Comparatron and LaserWeb4 services...${NC}"

# Remove systemd services
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

if [ -f "/etc/systemd/system/laserweb.service" ]; then
    if [ -n "$SUDO" ]; then
        $SUDO systemctl stop laserweb.service 2>/dev/null || true
        $SUDO systemctl disable laserweb.service 2>/dev/null || true
        $SUDO rm -f /etc/systemd/system/laserweb.service
        echo -e "${GREEN}Removed LaserWeb4 systemd service${NC}"
    else
        systemctl stop laserweb.service 2>/dev/null || true
        systemctl disable laserweb.service 2>/dev/null || true
        rm -f /etc/systemd/system/laserweb.service
        echo -e "${GREEN}Removed LaserWeb4 systemd service${NC}"
    fi
else
    echo -e "${YELLOW}LaserWeb4 service not found${NC}"
fi

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

# Remove Python virtual environments
echo -e "${YELLOW}Removing Python virtual environments...${NC}"
if [ -d "$HOME/comparatron-optimised/dependencies/comparatron_env" ]; then
    rm -rf "$HOME/comparatron-optimised/dependencies/comparatron_env"
    echo -e "${GREEN}Removed comparatron_env virtual environment${NC}"
else
    echo -e "${YELLOW}Comparatron virtual environment not found${NC}"
fi

if [ -d "$HOME/laserweb_env" ]; then
    rm -rf "$HOME/laserweb_env"
    echo -e "${GREEN}Removed laserweb_env virtual environment${NC}"
elif [ -d "$HOME/LaserWeb4/venv" ]; then
    rm -rf "$HOME/LaserWeb4/venv"
    echo -e "${GREEN}Removed LaserWeb4 virtual environment${NC}"
else
    echo -e "${YELLOW}LaserWeb4 virtual environment not found${NC}"
fi

if [ -d "$HOME/LaserWeb" ]; then
    rm -rf "$HOME/LaserWeb"
    echo -e "${GREEN}Removed LaserWeb directory${NC}"
fi

# Remove any installed packages from user site-packages
echo -e "${YELLOW}Removing installed Python packages...${NC}"

# Remove user-installed packages that might conflict
# Also check for variations in package names
packages_to_remove="numpy flask pillow PIL pyserial ezdxf dearpygui opencv-python opencv-python-headless cv2 pyinstaller serial-tools laserweb"

for pkg in $packages_to_remove; do
    # For PIL, also check for Pillow as they might be installed under different names
    if [ "$pkg" = "PIL" ] || [ "$pkg" = "PIL" ]; then
        # Try both pillow and PIL/Pillow
        python3 -m pip uninstall -y pillow PIL Pillow 2>/dev/null
        python3 -m pip uninstall -y PIL 2>/dev/null
        echo -e "${GREEN}Attempted to remove pillow-related packages${NC}"
    elif [ "$pkg" = "cv2" ]; then
        # CV2 is usually installed as opencv-python packages
        python3 -m pip uninstall -y opencv-python opencv-python-headless opencv-contrib-python 2>/dev/null
        echo -e "${GREEN}Attempted to remove opencv-related packages${NC}"
    else
        if python3 -m pip show $pkg &> /dev/null; then
            python3 -m pip uninstall -y $pkg 2>/dev/null && echo -e "${GREEN}Uninstalled $pkg${NC}"
        else
            echo -e "${YELLOW}$pkg not found${NC}"
        fi
    fi
done

# Optional: Remove system packages installed via apt (only for RPI/Fedora)
echo -e "${YELLOW}Optionally removing system packages (may affect other programs)...${NC}"
echo -e "${YELLOW}This step is skipped by default. Uncomment next section if you want to remove system packages${NC}"

# Uncomment the following lines if you want to remove system packages too:
# if [ -n "$SUDO" ]; then
#     $SUDO apt remove -y python3-opencv python3-numpy python3-pip python3-dev python3-venv \
#         libatlas-base-dev libhdf5-dev libilmbase-dev libopenexr-dev \
#         libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev \
#         libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev \
#         libtiff5-dev libjasper-dev libdc1394-dev \
#         nodejs npm nginx git \
#         python3-pyqt5 python3-pyqt5.qtwebkit \
#         qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools
#     $SUDO apt autoremove -y
#     echo -e "${GREEN}System packages removed${NC}"
# fi

# Remove configuration files
echo -e "${YELLOW}Removing configuration files...${NC}"

# Remove any config.json files created for LaserWeb
rm -f "$HOME/LaserWeb/config.json" 2>/dev/null || true
rm -f "$HOME/LaserWeb4/config.json" 2>/dev/null || true
rm -f "$HOME/LaserWeb/config.default.json" 2>/dev/null || true

# Remove startup scripts
rm -f "$HOME/start_laserweb.sh" 2>/dev/null || true
rm -f "$HOME/start_comparatron.sh" 2>/dev/null || true

# Remove any custom user groups assignments (just informational)
echo -e "${YELLOW}User groups information:${NC}"
echo -e "${YELLOW}To fully reverse group assignments, manually remove user from groups:${NC}"
echo -e "${YELLOW}  sudo deluser $USER video${NC}"
echo -e "${YELLOW}  sudo deluser $USER dialout${NC}"

# Clean up any temporary files from this script
rm -f requirements.txt 2>/dev/null || true

echo -e "${GREEN}=== Uninstallation completed ===${NC}"
echo -e "${GREEN}All Comparatron and LaserWeb4 components have been removed.${NC}"
echo -e "${GREEN}Note: The source directories remain untouched (comparatron-optimised, laserweb4).${NC}"
echo -e "${GREEN}You may need to restart your system for all changes to take effect.${NC}"