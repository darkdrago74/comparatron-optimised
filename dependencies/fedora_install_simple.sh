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

# Check if Python 3 is installed
echo -e "${YELLOW}Checking Python installation...${NC}"
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}Python 3 found$(python3 --version)${NC}"
    PYTHON_CMD="python3"
else
    echo -e "${RED}Error: Python 3 is not installed.${NC}"
    echo -e "${YELLOW}Installing Python 3...${NC}"
    # Install Python 3 and pip
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    $SUDO dnf install -y python3 python3-pip python3-devel &> /dev/null
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}Python 3 installed successfully${NC}"
        PYTHON_CMD="python3"
    else
        echo -e "${RED}Error: Could not install Python 3.${NC}"
        exit 1
    fi
fi

# Check if pip is available
echo -e "${YELLOW}Checking pip installation...${NC}"
if command -v python3 &> /dev/null && python3 -m pip --version &> /dev/null; then
    echo -e "${GREEN}Pip found$(python3 -m pip --version | cut -d' ' -f2)${NC}"
    PIP_CMD="python3 -m pip"
elif command -v pip3 &> /dev/null; then
    echo -e "${GREEN}Pip3 found${NC}"
    PIP_CMD="pip3"
else
    echo -e "${RED}Error: Pip is not installed.${NC}"
    echo -e "${YELLOW}Installing pip...${NC}"
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    $SUDO dnf install -y python3-pip &> /dev/null
    if python3 -m pip --version &> /dev/null; then
        echo -e "${GREEN}Pip installed successfully${NC}"
        PIP_CMD="python3 -m pip"
    else
        echo -e "${RED}Error: Could not install pip.${NC}"
        exit 1
    fi
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        echo -e "${YELLOW}Sudo not available, proceeding without elevated privileges where possible${NC}"
        SUDO=""
    fi
else
    SUDO=""
    echo -e "${GREEN}Running as root${NC}"
fi

# Update package list
echo -e "${YELLOW}Updating package list...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO dnf update -y &> /dev/null || echo -e "${YELLOW}Could not update package list, continuing anyway...${NC}"
fi

# Install system dependencies
echo -e "${YELLOW}Installing system dependencies...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO dnf install -y gcc gcc-c++ make wget curl git v4l-utils gstreamer1-plugins-good mesa-libGL &> /dev/null || echo -e "${YELLOW}Some system dependencies could not be installed${NC}"
else
    echo -e "${YELLOW}No sudo access, skipping system dependency installation${NC}"
fi

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO -H python3 -m pip install --upgrade pip || python3 -m pip install --upgrade pip --user
else
    python3 -m pip install --upgrade pip --user
fi

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
flask
pillow

# Install from requirements file to handle dependencies properly
if [ -n "$SUDO" ]; then
    $SUDO -H python3 -m pip install -r /tmp/requirements.txt || python3 -m pip install -r /tmp/requirements.txt --user
else
    python3 -m pip install -r /tmp/requirements.txt --user
fi

# Clean up
rm /tmp/requirements.txt

# Test the installation
echo -e "${YELLOW}Testing the installation...${NC}"

# Define arrays for packages and their import statements
packages=("numpy" "dearpygui" "pyserial" "opencv-python" "ezdxf" "flask" "pillow")
imports=("numpy" "dearpygui" "serial" "cv2" "ezdxf" "flask" "PIL")

# Test each package
for i in "${!packages[@]}"; do
    pkg="${packages[$i]}"
    imp="${imports[$i]}"
    
    if python3 -c "import ${imp}" &> /dev/null; then
        echo -e "${GREEN}✓ ${pkg} working${NC}"
    else
        echo -e "${RED}✗ ${pkg} not working${NC}"
    fi
done

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
if [ -n "$SUDO" ]; then
    $SUDO usermod -a -G video $USER 2>/dev/null && echo -e "${GREEN}✓ Added user to video group${NC}" || echo -e "${YELLOW}Note: Could not add user to video group (may require manual setup)${NC}"
else
    echo -e "${YELLOW}No sudo access, cannot add user to video group. You may need to run: sudo usermod -a -G video \$USER${NC}"
fi

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Clone the Comparatron repository${NC}"
echo -e "${GREEN}2. Navigate to the project directory${NC}"
echo -e "${GREEN}3. Run: python3 main_refactored.py${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}Note: After adding to video group, log out and log back in to access cameras.${NC}"