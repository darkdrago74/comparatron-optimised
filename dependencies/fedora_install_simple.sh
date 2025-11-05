#!/bin/bash

# Simplified Fedora Installation Script for Comparatron
# This script installs the minimal requirements for Comparatron to run on Fedora

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Simplified Comparatron Fedora Installation ===${NC}"

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
$SUDO dnf update -y &> /dev/null

# Install Python 3 and pip
echo -e "${YELLOW}Installing Python 3 and pip...${NC}"
$SUDO dnf install -y python3 python3-pip python3-devel &> /dev/null

# Install system dependencies
echo -e "${YELLOW}Installing system dependencies...${NC}"
$SUDO dnf install -y gcc gcc-c++ make wget curl git v4l-utils gstreamer1-plugins-good mesa-libGL &> /dev/null

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
python3 -m pip install --upgrade pip --user &> /dev/null

# Install required Python packages
echo -e "${YELLOW}Installing required Python packages...${NC}"

# Create a temporary requirements file
cat > /tmp/requirements.txt << EOF
numpy
dearpygui
pyserial
opencv-python
ezdxf
pyinstaller
EOF

# Install from requirements file to handle dependencies properly
python3 -m pip install -r /tmp/requirements.txt --user

# Clean up
rm /tmp/requirements.txt

# Test the installation
echo -e "${YELLOW}Testing the installation...${NC}"

# Test Python packages
python3 -c "import cv2; print('OpenCV: OK')" 2>/dev/null && echo -e "${GREEN}✓ OpenCV working${NC}" || echo -e "${RED}✗ OpenCV not working${NC}"
python3 -c "import dearpygui; print('DearPyGUI: OK')" 2>/dev/null && echo -e "${GREEN}✓ DearPyGUI working${NC}" || echo -e "${RED}✗ DearPyGUI not working${NC}"
python3 -c "import numpy; print('NumPy: OK')" 2>/dev/null && echo -e "${GREEN}✓ NumPy working${NC}" || echo -e "${RED}✗ NumPy not working${NC}"
python3 -c "import serial; print('PySerial: OK')" 2>/dev/null && echo -e "${GREEN}✓ PySerial working${NC}" || echo -e "${RED}✗ PySerial not working${NC}"
python3 -c "import ezdxf; print('EzDxf: OK')" 2>/dev/null && echo -e "${GREEN}✓ EzDxf working${NC}" || echo -e "${RED}✗ EzDxf not working${NC}"

# Show available cameras
echo -e "${YELLOW}Available camera devices:${NC}"
if command -v v4l2-ctl &> /dev/null; then
    v4l2-ctl --list-devices
elif [ -e /dev/video0 ]; then
    echo "/dev/video0 - Camera device detected"
else
    echo "No camera devices detected"
fi

# Add user to video group for camera access (optional)
echo -e "${YELLOW}Setting up camera access permissions...${NC}"
$SUDO usermod -a -G video $USER 2>/dev/null && echo -e "${GREEN}✓ Added user to video group${NC}" || echo -e "${YELLOW}Note: Could not add user to video group (may require manual setup)${NC}"

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Clone the Comparatron repository${NC}"
echo -e "${GREEN}2. Navigate to the project directory${NC}"
echo -e "${GREEN}3. Run: python3 main_refactored.py${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}Note: After adding to video group, log out and log back in to access cameras.${NC}"