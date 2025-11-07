#!/bin/bash

# Raspberry Pi Bookworm Installation Script for Comparatron
# This script installs the required dependencies for Comparatron on Raspberry Pi OS (Bookworm)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Raspberry Pi Bookworm Installation ===${NC}"

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

# Update package list
echo -e "${YELLOW}Updating package list...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO apt update -y
else
    apt update -y
fi

# Install system dependencies
echo -e "${YELLOW}Installing system dependencies...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO apt install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-serial-dev libhdf5-103 libqtgui4 libqtwebkit4 libqt4-test python3-pyqt5 python3-pyqt5.qtwebkit libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev libdc1394-22-dev
else
    apt install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-serial-dev libhdf5-103 libqtgui4 libqtwebkit4 libqt4-test python3-pyqt5 python3-pyqt5.qtwebkit libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev libdc1394-22-dev
fi

# Create and activate virtual environment
echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
python3 -m venv comparatron_env
source comparatron_env/bin/activate

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
python3 -m pip install --upgrade pip

# Install required Python packages
echo -e "${YELLOW}Installing required Python packages...${NC}"

# Install packages that have ARM-compatible versions first
pip3 install numpy

# Install OpenCV (may take a while on RPi)
echo -e "${YELLOW}Installing OpenCV (this may take a while on Raspberry Pi)...${NC}"
pip3 install opencv-python-headless  # Use headless version for RPi

# Install remaining packages
pip3 install flask pillow pyserial ezdxf dearpygui pyinstaller

# Create a temporary requirements file in case of issues
cat > requirements.txt << EOF
numpy
flask
pillow
pyserial
ezdxf
dearpygui
opencv-python-headless
pyinstaller
EOF

# Install from requirements to handle any dependency issues
pip3 install -r requirements.txt

# Clean up
rm requirements.txt

# Test the installation
echo -e "${YELLOW}Testing the installation...${NC}"

# Define arrays for packages and their import statements
packages=("numpy" "flask" "pyserial" "ezdxf" "dearpygui" "cv2" "PIL")
imports=("numpy" "flask" "serial" "ezdxf" "dearpygui" "cv2" "PIL")

# Test each package
for i in "${!packages[@]}"; do
    pkg="${packages[$i]}"
    imp="${imports[$i]}"
    if [ "$imp" = "cv2" ]; then
        imp_test="cv2 as cv"
    else
        imp_test="$imp"
    fi
    
    if python3 -c "import $imp_test" &> /dev/null; then
        echo -e "${GREEN}✓ ${pkg} working${NC}"
    else
        echo -e "${RED}✗ ${pkg} not working${NC}"
    fi
done

# Set up auto-start of Comparatron Flask GUI on boot
echo -e "${YELLOW}Setting up auto-start service...${NC}"

# Create a systemd service file
SERVICE_FILE="/etc/systemd/system/comparatron.service"
SERVICE_CONTENT="[Unit]
Description=Comparatron Flask GUI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/comparatron-optimised
Environment=PATH=/home/$USER/comparatron_env/bin
ExecStart=/home/$USER/comparatron_env/bin/python3 /home/$USER/comparatron-optimised/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

if [ -n "$SUDO" ]; then
    echo "$SERVICE_CONTENT" | $SUDO tee "$SERVICE_FILE"
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable comparatron.service
    echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"
else
    echo "$SERVICE_CONTENT" | tee "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable comparatron.service
    echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"
fi

# Add user to video group for camera access
if [ -n "$SUDO" ]; then
    $SUDO usermod -a -G video $USER
    echo -e "${GREEN}User added to video group for camera access${NC}"
fi

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Make sure the Comparatron folder is in your home directory as '/home/$USER/comparatron-optimised'${NC}"
echo -e "${GREEN}2. The web interface will automatically start on boot${NC}"
echo -e "${GREEN}3. Access the interface at: http://[RPI_IP_ADDRESS]:5001${NC}"
echo -e "${GREEN}4. To manually start: source ~/comparatron_env/bin/activate && python3 ~/comparatron-optimised/main.py${NC}"
echo -e "${GREEN}5. To restart the service manually: sudo systemctl restart comparatron${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}Note: After adding to video group, log out and log back in to access cameras.${NC}"