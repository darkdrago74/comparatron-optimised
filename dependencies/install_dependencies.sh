#!/bin/bash

# Comparatron Universal Installation Script
# Automatically detects system type and installs appropriate dependencies
# Works for both Linux systems and Raspberry Pi (Bookworm) with system-wide installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Universal Installation ===${NC}"

# Function to detect system
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        ID_LIKE=$ID_LIKE
    else
        OS=$(uname -s)
        VER=$(uname -r)
        ID_LIKE=""
    fi

    echo -e "${YELLOW}Detected OS: $OS${NC}"

    # Check if this is Raspbian/Debian-based system (especially RPi)
    if [[ "$OS" == *"Raspbian"* ]] || [[ "$OS" == *"Debian GNU/Linux"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        if grep -q "Raspberry\|raspberrypi\|rpi" /proc/cpuinfo 2>/dev/null ||
           [ -f "/opt/vc/bin/vcgencmd" ] ||
           grep -q "Raspberry\|BCM" /proc/cpuinfo 2>/dev/null; then
            DISTRO_TYPE="raspberry_pi"
            RPI_VERSION="bookworm"
        else
            DISTRO_TYPE="debian"
        fi
    elif [[ "$OS" == *"Fedora"* ]] || [[ -f /etc/fedora-release ]]; then
        DISTRO_TYPE="fedora"
    else
        # Try to determine based on package manager
        if command -v dnf &> /dev/null; then
            DISTRO_TYPE="fedora"
        elif command -v apt-get &> /dev/null; then
            DISTRO_TYPE="debian"
        else
            DISTRO_TYPE="generic"
        fi
    fi

    echo -e "${YELLOW}Detected system type: $DISTRO_TYPE${NC}"
}

# Install for Debian-based systems (including RPi)
install_debian() {
    echo -e "${YELLOW}Installing for Debian-based system...${NC}"

    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        SUDO=""
        echo -e "${RED}Sudo not available, some operations may fail${NC}"
    fi

    # Update package list
    echo -e "${YELLOW}Updating package list...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO apt update -y
    fi

    # Install system dependencies - avoid conflicting packages initially
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    if [ -n "$SUDO" ]; then
        # Try installing the full set first
        if ! $SUDO apt install -y python3 python3-pip python3-dev build-essential libatlas-base-dev libhdf5-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev; then
            echo -e "${YELLOW}Standard installation failed, trying minimal set...${NC}"
            # Try minimal set needed for basic functionality
            if ! $SUDO apt install -y python3 python3-pip python3-dev build-essential libatlas-base-dev libjpeg-dev libpng-dev libtiff5-dev; then
                echo -e "${RED}Critical system dependencies installation failed${NC}"
                exit 1
            fi
        fi
    else
        # Without sudo, check if the required python components exist
        if ! command -v python3 &> /dev/null; then
            echo -e "${RED}Error: python3 is not available and no sudo access${NC}"
            exit 1
        fi
    fi
}

# Install for Fedora-based systems
install_fedora() {
    echo -e "${YELLOW}Installing for Fedora system...${NC}"

    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        SUDO=""
        echo -e "${RED}Sudo not available, some operations may fail${NC}"
    fi

    # Update package list
    echo -e "${YELLOW}Updating package list...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO dnf update -y
    fi

    # Install RPM Fusion repository
    echo -e "${YELLOW}Installing RPM Fusion repository...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm 2>/dev/null || true
        $SUDO dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>/dev/null || true
    fi

    # Install system dependencies
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO dnf group install -y "C Development Tools and Libraries" 2>/dev/null || true
        $SUDO dnf install -y python3 python3-pip python3-devel atlas-devel hdf5-devel gstreamer1-devel ffmpeg-devel libv4l-devel xvidcore-devel x264-devel libjpeg-turbo-devel libpng-devel libtiff-devel 2>/dev/null || true
    fi
}

# Generic installation (for any system)
install_generic() {
    echo -e "${YELLOW}Installing for generic system...${NC}"

    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is not installed.${NC}"
        exit 1
    fi
    
    # Ensure pip is available
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}Error: pip3 is not installed.${NC}"
        exit 1
    fi
}

# Set up auto-start service for Raspberry Pi
setup_raspberry_pi_service() {
    echo -e "${YELLOW}Setting up auto-start service for Raspberry Pi...${NC}"

    if ! command -v sudo &> /dev/null; then
        echo -e "${YELLOW}Sudo not available, skipping systemd service setup${NC}"
        return
    fi

    # Create a systemd service file
    SERVICE_FILE="/etc/systemd/system/comparatron.service"
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    SERVICE_CONTENT="[Unit]
Description=Comparatron Flask GUI
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_ROOT
Environment=PATH=/usr/bin
Environment=PYTHONPATH=$PROJECT_ROOT
ExecStart=/usr/bin/python3 $PROJECT_ROOT/main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

    echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable comparatron.service
    echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"

    # Add user to video group for camera access
    sudo usermod -a -G video $USER
    echo -e "${GREEN}User added to video group for camera access${NC}"

    # Add user to dialout group for serial port access (needed for Arduino/GRBL communication)
    sudo usermod -a -G dialout $USER
    echo -e "${GREEN}User added to dialout group for serial port access${NC}"

    # For Raspberry Pi, also add to gpio group for GPIO access if needed
    if getent group gpio > /dev/null 2>&1; then
        sudo usermod -a -G gpio $USER
        echo -e "${GREEN}User added to gpio group for GPIO access${NC}"
    fi

    echo -e "${YELLOW}Note: You may need to log out and log back in, or reboot, for the group changes to take effect${NC}"
}

# Test the installation
test_installation() {
    echo -e "${YELLOW}Testing the installation...${NC}"

    for pkg in numpy flask pillow pyserial ezdxf cv2; do
        if [ "$pkg" = "cv2" ]; then
            IMP="cv2 as cv"
        elif [ "$pkg" = "pillow" ]; then
            IMP="PIL as Image"
        elif [ "$pkg" = "pyserial" ]; then
            IMP="serial"
        else
            IMP="$pkg"
        fi

        if python3 -c "import $IMP" &> /dev/null; then
            echo -e "${GREEN}✓ $pkg working${NC}"
        else
            # For OpenCV, it might take time to load on slower systems
            if [ "$pkg" = "cv2" ]; then
                echo -e "${YELLOW}? $pkg may not be available or taking time to load${NC}"
            else
                echo -e "${RED}✗ $pkg not working${NC}"
            fi
        fi
    done
}

# Main installation process
detect_system

# Call appropriate install function based on detected system
case "$DISTRO_TYPE" in
    "raspberry_pi"|"debian")
        install_debian
        ;;
    "fedora")
        install_fedora
        ;;
    *)
        install_generic
        ;;
esac

# Upgrade pip if needed
echo -e "${YELLOW}Ensuring pip is upgraded...${NC}"
if command -v pip3 &> /dev/null; then
    pip3 install --upgrade pip
else
    python3 -m pip install --upgrade pip
fi

# Get the project root directory to find requirements.txt
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIREMENTS_FILE="$PROJECT_ROOT/dependencies/requirements.txt"

# Install Python packages from requirements.txt
echo -e "${YELLOW}Installing required Python packages from requirements.txt (exact versions)...${NC}"
echo -e "${YELLOW}Requirements file path: $REQUIREMENTS_FILE${NC}"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: Requirements file not found at $REQUIREMENTS_FILE${NC}"
    exit 1
fi

# Install packages using the system Python, with specific versions from requirements
if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    # For RPi use piwheels specifically to speed up installation
    pip3 install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary -r "$REQUIREMENTS_FILE" || {
        echo -e "${YELLOW}Installing from piwheels failed, trying standard PyPI...${NC}"
        pip3 install --break-system-packages --prefer-binary -r "$REQUIREMENTS_FILE" || {
            echo -e "${RED}Error: Failed to install Python packages. Please check logs for details.${NC}"
            exit 1
        }
    }
else
    # For other systems, install with --break-system-packages if needed
    if command -v apt &> /dev/null; then
        # Debian/Ubuntu systems typically require --break-system-packages
        pip3 install --break-system-packages --prefer-binary -r "$REQUIREMENTS_FILE" || {
            echo -e "${RED}Error: Failed to install Python packages. Please check logs for details.${NC}"
            exit 1
        }
    else
        # Other systems might not require --break-system-packages
        pip3 install --prefer-binary -r "$REQUIREMENTS_FILE" || {
            echo -e "${RED}Error: Failed to install Python packages. Please check logs for details.${NC}"
            exit 1
        }
    fi
fi

# Test the installation
test_installation

# Setup auto-start service for Raspberry Pi if detected
if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    # Ask user if they want to enable auto-start service on Raspberry Pi
    read -p "Do you want to enable Comparatron to start automatically on Raspberry Pi boot? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_raspberry_pi_service
    else
        echo -e "${YELLOW}Auto-start service not enabled. You can start manually with: python3 main.py${NC}"
        # Still add user to groups for camera and serial access
        if command -v sudo &> /dev/null; then
            sudo usermod -a -G video $USER
            echo -e "${GREEN}User added to video group for camera access${NC}"
            sudo usermod -a -G dialout $USER
            echo -e "${GREEN}User added to dialout group for serial port access${NC}"
        fi
    fi
else
    # For non-Raspberry Pi systems, add both video and dialout groups
    if command -v sudo &> /dev/null; then
        sudo usermod -a -G video $USER
        echo -e "${GREEN}User added to video group for camera access${NC}"
        sudo usermod -a -G dialout $USER
        echo -e "${GREEN}User added to dialout group for serial port access${NC}"
        echo -e "${YELLOW}Note: You may need to log out and log back in, or reboot, for the group changes to take effect${NC}"
    fi
fi

# Create a simple diagnostic script for troubleshooting
cat > "$PROJECT_ROOT/troubleshoot_service.sh" << 'EOF'
#!/bin/bash
# Comparatron Service Troubleshooting Script

echo "=== Comparatron Service Troubleshooting ==="

if systemctl is-enabled comparatron &>/dev/null; then
    echo "✓ Comparatron service is enabled"
else
    echo "✗ Comparatron service is NOT enabled"
fi

if systemctl is-active comparatron &>/dev/null; then
    echo "✓ Comparatron service is running"
else
    echo "✗ Comparatron service is NOT running"
fi

if netstat -tuln | grep :5001 &>/dev/null; then
    echo "✓ Port 5001 is in use (service may be running)"
else
    echo "✗ Port 5001 is NOT in use"
fi

echo "To start the service: sudo systemctl start comparatron"
echo "To enable auto-start: sudo systemctl enable comparatron"
echo "To disable auto-start: sudo systemctl disable comparatron"
echo "To check detailed logs: sudo journalctl -u comparatron -f"
echo "To restart service: sudo systemctl restart comparatron"
EOF

chmod +x "$PROJECT_ROOT/troubleshoot_service.sh"

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. The web interface will be available at: http://localhost:5001${NC}"
echo -e "${GREEN}2. To manually start: cd && cd comparatron-optimised && python3 main.py${NC}"
echo -e "${GREEN}${NC}"

if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    echo -e "${GREEN}3. On Raspberry Pi, if auto-start was enabled, the web interface will automatically start on boot at: http://[RPI_IP]:5001${NC}"
    echo -e "${GREEN}4. To manually restart service: sudo systemctl restart comparatron${NC}"
    echo -e "${GREEN}5. To check service status: sudo systemctl status comparatron${NC}"
    echo -e "${GREEN}6. To view service logs: sudo journalctl -u comparatron -f${NC}"
fi

echo -e "${GREEN}${NC}"
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "${YELLOW}  - You have been added to the dialout group for serial port access${NC}"
echo -e "${YELLOW}  - You need to logout and login again for the group changes to take effect${NC}"
echo -e "${YELLOW}  - After logging in, the Arduino/GRBL shield will be accessible via serial${NC}"
echo -e "${YELLOW}  - The main Comparatron interface is Flask-based (web interface).${NC}"
if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    echo -e "${YELLOW}  - If boot service is enabled, check logs with: sudo journalctl -u comparatron -f${NC}"
fi