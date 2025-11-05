#!/bin/bash

# Fedora Installation Script for Comparatron
# This script will install Python, pip, and all required dependencies for Comparatron

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Fedora Installation Script ===${NC}"
echo -e "${BLUE}This script will install Python, pip, and all required dependencies${NC}"

# Function to run command with error checking
run_command() {
    local command="$1"
    local description="$2"
    
    echo -e "${YELLOW}Running: $description${NC}"
    echo -e "${YELLOW}Command: $command${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✓ Success: $description${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed: $description${NC}"
        return 1
    fi
}

# Check if running as root or with sudo
check_privileges() {
    echo -e "${YELLOW}Checking for required privileges...${NC}"
    
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}Running as root${NC}"
        SUDO=""
    elif command -v sudo &> /dev/null; then
        echo -e "${GREEN}Sudo available${NC}"
        SUDO="sudo"
    else
        echo -e "${RED}Error: Neither root nor sudo is available.${NC}"
        echo -e "${RED}Please run this script as root or with sudo privileges.${NC}"
        exit 1
    fi
}

# Update system packages
update_system() {
    echo -e "${YELLOW}Updating system packages...${NC}"
    
    if ! run_command "$SUDO dnf update -y" "System update"; then
        echo -e "${YELLOW}Warning: System update failed, continuing anyway...${NC}"
    fi
}

# Install basic development tools
install_basic_tools() {
    echo -e "${YELLOW}Installing basic development tools...${NC}"
    
    packages=(
        "python3"
        "python3-pip"
        "python3-devel"
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        "wget"
        "curl"
        "git"
        "v4l-utils"  # For camera utilities
    )
    
    for package in "${packages[@]}"; do
        if ! run_command "$SUDO dnf install -y $package" "Install $package"; then
            echo -e "${YELLOW}Warning: Failed to install $package, continuing...${NC}"
        fi
    done
}

# Install Python packages
install_python_packages() {
    echo -e "${YELLOW}Installing Python packages...${NC}"
    
    # Upgrade pip first
    if run_command "python3 -m pip install --upgrade pip" "Upgrade pip"; then
        echo -e "${GREEN}Pip upgraded successfully${NC}"
    else
        echo -e "${YELLOW}Trying alternative pip upgrade method...${NC}"
        if run_command "pip3 install --upgrade pip" "Upgrade pip (pip3)"; then
            echo -e "${GREEN}Pip upgraded successfully${NC}"
        else
            echo -e "${YELLOW}Warning: Failed to upgrade pip${NC}"
        fi
    fi
    
    # Install required Python packages
    packages=(
        "numpy"
        "dearpygui"
        "pyserial"
        "opencv-python"
        "ezdxf"
        "pyinstaller"
    )
    
    for package in "${packages[@]}"; do
        if ! run_command "pip3 install $package --user" "Install Python package: $package"; then
            echo -e "${YELLOW}Trying alternative installation for $package...${NC}"
            if ! run_command "python3 -m pip install $package --user" "Install Python package: $package (alternative)"; then
                echo -e "${RED}Error installing $package${NC}"
                # Continue with other packages instead of exiting
            fi
        fi
    done
}

# Install additional system dependencies for OpenCV
install_opencv_deps() {
    echo -e "${YELLOW}Installing OpenCV system dependencies...${NC}"
    
    packages=(
        "gstreamer1-plugins-good"
        "gstreamer1-plugins-bad-free"
        "gstreamer1-plugins-ugly"
        "mesa-libGL"
        "mesa-libEGL"
        "libusb-devel"
        "vulkan-loader"
    )
    
    for package in "${packages[@]}"; do
        if ! run_command "$SUDO dnf install -y $package" "Install OpenCV dependency: $package"; then
            echo -e "${YELLOW}Warning: Failed to install $package, continuing...${NC}"
        fi
    done
}

# Create a Python virtual environment (optional but recommended)
create_venv() {
    echo -e "${YELLOW}Creating Python virtual environment (recommended)...${NC}"
    
    if run_command "python3 -m venv ~/comparatron_env" "Create virtual environment"; then
        echo -e "${GREEN}Virtual environment created at ~/comparatron_env${NC}"
        echo -e "${YELLOW}To activate: source ~/comparatron_env/bin/activate${NC}"
        
        # Activate venv and install packages in it
        echo -e "${YELLOW}Installing packages in virtual environment...${NC}"
        run_command "source ~/comparatron_env/bin/activate && python -m pip install --upgrade pip" "Upgrade pip in venv"
        
        packages=(
            "numpy"
            "dearpygui"
            "pyserial"
            "opencv-python"
            "ezdxf"
            "pyinstaller"
        )
        
        for package in "${packages[@]}"; do
            if ! run_command "source ~/comparatron_env/bin/activate && pip install $package" "Install $package in venv"; then
                echo -e "${YELLOW}Trying alternative for $package in venv...${NC}"
                if ! run_command "source ~/comparatron_env/bin/activate && python -m pip install $package" "Install $package in venv (alternative)"; then
                    echo -e "${RED}Error installing $package in venv${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}Virtual environment creation failed, continuing with user installation...${NC}"
    fi
}

# Test camera access
test_camera() {
    echo -e "${YELLOW}Testing camera access...${NC}"
    
    if command -v v4l2-ctl &> /dev/null; then
        echo -e "${GREEN}v4l2-ctl available, checking camera devices...${NC}"
        v4l2-ctl --list-devices
    else
        echo -e "${YELLOW}v4l2-ctl not available, installing...${NC}"
        if run_command "$SUDO dnf install -y v4l-utils" "Install v4l-utils"; then
            v4l2-ctl --list-devices
        else
            echo -e "${YELLOW}Could not install v4l-utils${NC}"
        fi
    fi
    
    # Check for video devices
    if [ -d "/dev" ]; then
        echo -e "${GREEN}Available video devices:${NC}"
        ls -la /dev/video*
    else
        echo -e "${YELLOW}No /dev directory found${NC}"
    fi
}

# Test installation
test_installation() {
    echo -e "${YELLOW}Testing Python packages installation...${NC}"
    
    packages_to_test=(
        "import cv2; print(f'OpenCV version: {cv2.__version__}')"
        "import dearpygui; print('DearPyGUI: OK')"
        "import numpy; print(f'NumPy version: {numpy.__version__}')"
        "import serial; print('PySerial: OK')"
        "import ezdxf; print('EzDxf: OK')"
        "import sys; print(f'Python version: {sys.version}')"
    )
    
    for test in "${packages_to_test[@]}"; do
        echo -e "${YELLOW}Testing: $test${NC}"
        if python3 -c "$test"; then
            echo -e "${GREEN}✓ Test passed${NC}"
        else
            echo -e "${RED}✗ Test failed${NC}"
        fi
        echo "---"
    done
}

# Create a startup script for Comparatron
create_startup_script() {
    echo -e "${YELLOW}Creating Comparatron startup script...${NC}"
    
    cat > ~/comparatron_start.sh << 'EOF'
#!/bin/bash

# Comparatron Startup Script
# This script sets up the environment and starts Comparatron

echo "Starting Comparatron..."

# Set up environment variables
export PYTHONPATH="$HOME/comparatron:$PYTHONPATH"

# Activate virtual environment if it exists
if [ -f "$HOME/comparatron_env/bin/activate" ]; then
    source "$HOME/comparatron_env/bin/activate"
    echo "Virtual environment activated"
fi

# Check if we're in the right directory
if [ -f "main_refactored.py" ]; then
    echo "Found main_refactored.py in current directory"
    python3 main_refactored.py
elif [ -f "$HOME/comparatron/main_refactored.py" ]; then
    cd "$HOME/comparatron"
    echo "Changed to Comparatron directory"
    python3 main_refactored.py
else
    echo "Please navigate to your Comparatron directory and run this script"
    echo "Or place this script in your Comparatron project directory"
fi
EOF

    run_command "chmod +x ~/comparatron_start.sh" "Make startup script executable"
    echo -e "${GREEN}Startup script created at ~/comparatron_start.sh${NC}"
    echo -e "${YELLOW}Usage: ~/comparatron_start.sh (after cloning Comparatron to $HOME/comparatron)${NC}"
}

# Main installation process
main() {
    echo -e "${BLUE}Starting Fedora installation process...${NC}"
    
    check_privileges
    update_system
    install_basic_tools
    install_opencv_deps
    install_python_packages
    create_venv
    test_camera
    test_installation
    create_startup_script
    
    echo -e "${GREEN}=== Installation completed successfully ===${NC}"
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "${GREEN}1. Clone the Comparatron repository${NC}"
    echo -e "${GREEN}2. Navigate to the project directory${NC}"
    echo -e "${GREEN}3. Run: ~/comparatron_start.sh${NC}"
    echo -e "${GREEN}   Or: python3 main_refactored.py${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}For camera access, you may need to add your user to the video group:${NC}"
    echo -e "${GREEN}$SUDO usermod -a -G video $USER${NC}"
    echo -e "${GREEN}Then log out and log back in, or run: newgrp video${NC}"
}

# Run the main function
main "$@"