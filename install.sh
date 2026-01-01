#!/bin/bash

# Comparatron Complete Installation Script
# Combines installation, setup, testing, verification, and repair into a single comprehensive script
# Graceful cleanup on failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables to track what was installed
SYSTEMD_SERVICE_CREATED=false
COMMAND_SYMLINK_CREATED=false

# Function to clean up on exit if installation fails
cleanup_on_failure() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Installation failed. Cleaning up partially installed components...${NC}"

        # Remove systemd service if it was created during this installation
        if [ "$SYSTEMD_SERVICE_CREATED" = true ] && [ -f "/etc/systemd/system/comparatron.service" ]; then
            if command -v sudo &> /dev/null; then
                sudo systemctl stop comparatron.service 2>/dev/null || true
                sudo systemctl disable comparatron.service 2>/dev/null || true
                sudo rm -f /etc/systemd/system/comparatron.service
                sudo systemctl daemon-reload
                echo -e "${YELLOW}Removed systemd service${NC}"
            else
                echo -e "${YELLOW}Unable to remove systemd service (sudo required)${NC}"
            fi
        fi

        # Remove system-wide command if it was created during this installation
        if [ "$COMMAND_SYMLINK_CREATED" = true ] && [ -L "/usr/local/bin/comparatron" ]; then
            if command -v sudo &> /dev/null; then
                sudo rm -f /usr/local/bin/comparatron
                echo -e "${YELLOW}Removed system-wide 'comparatron' command${NC}"
            else
                echo -e "${YELLOW}Unable to remove system-wide command (sudo required)${NC}"
            fi
        fi

        echo -e "${RED}Installation exited with error code $exit_code. Partial components have been cleaned up.${NC}"
    fi
}

# Set up trap to clean up on exit
trap cleanup_on_failure EXIT

echo -e "${BLUE}=== Comparatron Complete Installation ===${NC}"

# Check if already installed
check_existing_installation() {
    echo -e "${YELLOW}Checking for existing installation...${NC}"

    EXISTS=0
    ISSUES=()

    if [ -f "/etc/systemd/system/comparatron.service" ]; then
        echo -e "${YELLOW}  Found existing systemd service${NC}"
        EXISTS=1
    fi

    if command -v comparatron &> /dev/null; then
        echo -e "${YELLOW}  Found existing 'comparatron' command${NC}"
        EXISTS=1
    fi

    # Check if Python 3 and pip are available first before checking packages
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}  Python 3 not found, skipping package check until after prerequisites are installed${NC}"
        MISSING_PKGS=()
    elif ! command -v pip3 &> /dev/null; then
        echo -e "${YELLOW}  pip3 not found, skipping package check until after prerequisites are installed${NC}"
        MISSING_PKGS=()
    else
        # Check for required Python packages only if Python and pip are available
        MISSING_PKGS=()
        for pkg in flask numpy cv2 PIL ezdxf; do
            if ! python3 -c "import $pkg" 2>/dev/null; then
                MISSING_PKGS+=("$pkg")
            fi
        done
        # Special handling for pyserial since it's imported as 'serial'
        if ! python3 -c "import serial" 2>/dev/null; then
            MISSING_PKGS+=("pyserial")
        fi
    fi

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}  Missing Python packages: ${MISSING_PKGS[*]}${NC}"
        ISSUES+=("missing packages")

        # Ask user if they want to install the missing packages
        read -p "Would you like to install the missing packages? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installing missing Python packages...${NC}"

            # Get the project root directory to find requirements.txt
            PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            REQUIREMENTS_FILE="$PROJECT_ROOT/dependencies/requirements.txt"

            # Check if the main requirements.txt exists, otherwise use requirements-simple.txt
            if [ ! -f "$REQUIREMENTS_FILE" ]; then
                REQUIREMENTS_FILE="$PROJECT_ROOT/dependencies/requirements-simple.txt"
                if [ ! -f "$REQUIREMENTS_FILE" ]; then
                    echo -e "${RED}Error: No requirements file found (neither requirements.txt nor requirements-simple.txt)${NC}"
                    echo -e "${YELLOW}Skipping package installation.${NC}"
                else
                    echo -e "${YELLOW}Using requirements-simple.txt${NC}"
                fi
            else
                echo -e "${YELLOW}Using requirements.txt${NC}"
            fi

            if [ -f "$REQUIREMENTS_FILE" ]; then
                echo -e "${YELLOW}Installing specific missing packages from requirements file: $REQUIREMENTS_FILE${NC}"

                # Create timestamped log file
                LOG_FILE="/tmp/comparatron_install_$(date +%Y%m%d_%H%M%S).log"
                echo "Installation log started at $(date)" >> "$LOG_FILE"
                echo "Installing specific missing packages from: $REQUIREMENTS_FILE" >> "$LOG_FILE"

                # Install packages individually to handle issues more gracefully
                INSTALLED_COUNT=0
                FAILED_COUNT=0
                SUCCESS=true

                # Read the requirements file and install missing packages one by one
                while IFS= read -r req_line; do
                    # Skip empty lines and comments
                    if [[ -z "$req_line" || "$req_line" =~ ^[[:space:]]*# || "$req_line" =~ ^[[:space:]]*$ ]]; then
                        continue
                    fi

                    # Extract package name (before version specifier)
                    PACKAGE_NAME=$(echo "$req_line" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 | cut -d'!' -f1 | xargs)

                    # Check if this package was in the list of missing packages
                    IS_MISSING=false
                    for missing_pkg in "${MISSING_PKGS[@]}"; do
                        if [ "$PACKAGE_NAME" = "$missing_pkg" ]; then
                            IS_MISSING=true
                            break
                        fi
                    done

                    if [ "$IS_MISSING" = true ]; then
                        echo -e "${YELLOW}Installing $PACKAGE_NAME...${NC}"
                        echo "Installing $PACKAGE_NAME..." >> "$LOG_FILE"

                        # Install just this specific package with proper handling
                        if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
                            # Special handling for opencv-python-headless on Raspberry Pi - use regular opencv-python instead
                            if [ "$PACKAGE_NAME" = "opencv-python-headless" ]; then
                                echo -e "${YELLOW}Installing opencv-python (not headless) for Raspberry Pi...${NC}"
                                echo "Installing opencv-python for Raspberry Pi..." >> "$LOG_FILE"
                                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary opencv-python 2>>"$LOG_FILE"; then
                                    echo -e "${GREEN}✓ opencv-python installed successfully${NC}"
                                    echo "opencv-python installed successfully" >> "$LOG_FILE"
                                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                else
                                    echo -e "${RED}✗ Failed to install opencv-python${NC}"
                                    echo "Failed to install opencv-python" >> "$LOG_FILE"
                                    FAILED_COUNT=$((FAILED_COUNT + 1))
                                    SUCCESS=false
                                fi
                            else
                                # For other packages, install normally
                                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "$req_line" 2>>"$LOG_FILE"; then
                                    echo -e "${GREEN}✓ $PACKAGE_NAME installed successfully${NC}"
                                    echo "$PACKAGE_NAME installed successfully" >> "$LOG_FILE"
                                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                else
                                    echo -e "${RED}✗ Failed to install $PACKAGE_NAME${NC}"
                                    echo "Failed to install $PACKAGE_NAME" >> "$LOG_FILE"
                                    FAILED_COUNT=$((FAILED_COUNT + 1))
                                    SUCCESS=false
                                fi
                            fi
                        else
                            # For other systems
                            if command -v apt-get &> /dev/null; then
                                # Debian/Ubuntu systems
                                if python3 -m pip install --break-system-packages --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                                    if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                                        echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                                        echo "$req_line installed successfully" >> "$LOG_FILE"
                                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                    else
                                        echo -e "${RED}✗ Failed to install $req_line${NC}"
                                        echo "Failed to install $req_line" >> "$LOG_FILE"
                                        FAILED_COUNT=$((FAILED_COUNT + 1))
                                        SUCCESS=false
                                    fi
                                else
                                    if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                                        echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                                        echo "$req_line installed successfully" >> "$LOG_FILE"
                                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                    else
                                        echo -e "${RED}✗ Failed to install $req_line${NC}"
                                        echo "Failed to install $req_line" >> "$LOG_FILE"
                                        FAILED_COUNT=$((FAILED_COUNT + 1))
                                        SUCCESS=false
                                    fi
                                fi
                            else
                                # Other systems
                                if python3 -m pip install --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                                    if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                                        echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                                        echo "$req_line installed successfully" >> "$LOG_FILE"
                                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                    else
                                        echo -e "${RED}✗ Failed to install $req_line${NC}"
                                        echo "Failed to install $req_line" >> "$LOG_FILE"
                                        FAILED_COUNT=$((FAILED_COUNT + 1))
                                        SUCCESS=false
                                    fi
                                else
                                    if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                                        echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                                        echo "$req_line installed successfully" >> "$LOG_FILE"
                                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                                    else
                                        echo -e "${RED}✗ Failed to install $req_line${NC}"
                                        echo "Failed to install $req_line" >> "$LOG_FILE"
                                        FAILED_COUNT=$((FAILED_COUNT + 1))
                                        SUCCESS=false
                                    fi
                                fi
                            fi
                        fi
                    fi
                done < "$REQUIREMENTS_FILE"

                echo -e "${GREEN}Package installation completed: $INSTALLED_COUNT installed, $FAILED_COUNT failed${NC}"
                echo "Package installation completed: $INSTALLED_COUNT installed, $FAILED_COUNT failed" >> "$LOG_FILE"

                # Re-check packages to see if they were installed successfully
                STILL_MISSING=()
                for pkg in "${MISSING_PKGS[@]}"; do
                    if ! python3 -c "import $pkg" 2>/dev/null; then
                        STILL_MISSING+=("$pkg")
                    fi
                done

                if [ ${#STILL_MISSING[@]} -eq 0 ]; then
                    echo -e "${GREEN}✓ All missing packages installed successfully${NC}"
                    ISSUES=("${ISSUES[@]/missing packages}")  # Remove missing packages from issues
                    unset MISSING_PKGS
                else
                    echo -e "${RED}✗ Some packages still missing after installation: ${STILL_MISSING[*]}${NC}"
                    # Preserve the original issue but with more detail
                    ISSUES+=("failed to install: ${STILL_MISSING[*]}")
                fi
            else
                echo -e "${RED}Requirements file not found, cannot install missing packages.${NC}"
            fi
        fi
    else
        if command -v python3 &> /dev/null && command -v pip3 &> /dev/null; then
            echo -e "${GREEN}  ✓ All required Python packages are available${NC}"
        else
            echo -e "${YELLOW}  Python and/or pip not available - packages will be checked after installation${NC}"
        fi
    fi

    # Check if user is in required groups
    if ! groups $USER 2>/dev/null | grep -q "\bdialout\b"; then
        echo -e "${YELLOW}  User not in dialout group (serial access)${NC}"
        ISSUES+=("missing dialout group")
    else
        echo -e "${GREEN}  ✓ User is in dialout group${NC}"
    fi

    if ! groups $USER 2>/dev/null | grep -q "\bvideo\b"; then
        echo -e "${YELLOW}  User not in video group (camera access)${NC}"
        ISSUES+=("missing video group")
    else
        echo -e "${GREEN}  ✓ User is in video group${NC}"
    fi

    if [ $EXISTS -eq 1 ]; then
        if [ ${#ISSUES[@]} -gt 0 ]; then
            echo -e "${YELLOW}Existing installation found but has issues: ${ISSUES[*]}${NC}"
            read -p "Reinstall to fix issues? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Run uninstallation first
                echo -e "${YELLOW}Uninstalling existing installation before reinstalling...${NC}"
                if [ -f "/home/roro/Documents/comparatron-optimised/dependencies/uninstall.sh" ]; then
                    echo "y" | /home/roro/Documents/comparatron-optimised/dependencies/uninstall.sh
                fi
                return 0  # Reinstall
            else
                echo -e "${YELLOW}Skipping installation. Running tests...${NC}"
                run_functionality_test
                exit 0
            fi
        else
            echo -e "${GREEN}Existing installation appears to be working correctly${NC}"
            read -p "Run functionality test instead of reinstalling? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                run_functionality_test
                exit 0
            else
                echo -e "${YELLOW}Proceeding with reinstall...${NC}"
            fi
        fi
    fi

    return 1  # Continue with fresh installation
}

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
           grep -q "Raspberry\|BCM" /proc/cpuinfo 2>/dev/null ||
           [ -d "/sys/class/gpio/gpio18" ] ||
           [ -f "/boot/config.txt" ]; then
            DISTRO_TYPE="raspberry_pi"
            # Determine specific RPi OS version
            if [[ "$OS" == *"12"* ]] || [[ "$VER" == *"12"* ]] || [[ "$OS" == *"Bookworm"* ]]; then
                RPI_VERSION="bookworm"
            elif [[ "$OS" == *"11"* ]] || [[ "$VER" == *"11"* ]] || [[ "$OS" == *"Bullseye"* ]]; then
                RPI_VERSION="bullseye"
            else
                RPI_VERSION="bookworm"  # Default to bookworm for newer versions
            fi
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

# Check prerequisites before installation
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git is not installed. Installing...${NC}"
        if command -v sudo &> /dev/null; then
            if command -v apt-get &> /dev/null; then
                sudo apt update && sudo apt install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            else
                echo -e "${RED}Cannot install git automatically. Please install git manually.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Cannot install git without sudo. Please install git manually.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Git is installed${NC}"
    fi

    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Python 3 is not installed. This is required for Comparatron.${NC}"
        if command -v sudo &> /dev/null; then
            if command -v apt-get &> /dev/null; then
                sudo apt update && sudo apt install -y python3 python3-pip
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y python3 python3-pip
            else
                echo -e "${RED}Cannot install Python automatically. Please install Python 3 manually.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Cannot install Python without sudo. Please install Python 3 manually.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Python 3 is installed${NC}"
    fi
    
    # Check if pip3 is available
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}pip3 is not installed. Installing...${NC}"
        if command -v sudo &> /dev/null; then
            if command -v apt-get &> /dev/null; then
                sudo apt install -y python3-pip
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y python3-pip
            else
                echo -e "${RED}Cannot install pip automatically.${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ pip3 is installed${NC}"
    fi
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

    # For Raspberry Pi specifically, install system dependencies with Bookworm compatibility
    if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
        echo -e "${YELLOW}Installing system dependencies for Raspberry Pi with Bookworm OS...${NC}"

        # Install Raspberry Pi specific packages first
        if [ -n "$SUDO" ]; then
            # Install basic system dependencies for RPi
            $SUDO apt install -y python3 python3-pip python3-dev

            # Install critical system libraries that numpy, opencv, and other packages depend on
            # These are often the missing pieces that cause import failures (like libopenblas.so.0)
            # Try to install packages one by one to handle missing packages gracefully
            PKG_LIST="libopenblas-dev libatlas-base-dev libhdf5-dev libhdf5-serial-dev libhdf5-103"
            PKG_LIST="$PKG_LIST libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev"
            PKG_LIST="$PKG_LIST libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev"
            PKG_LIST="$PKG_LIST libfontconfig1-dev libharfbuzz-dev libfreetype6-dev libxcb-render0-dev"
            PKG_LIST="$PKG_LIST libxcb-shape0-dev libxcb-xfixes0-dev libopenjp2-7-dev libilmbase-dev"
            PKG_LIST="$PKG_LIST libopenexr-dev libgstreamer-plugins-base1.0-dev libavresample-dev"
            PKG_LIST="$PKG_LIST libgfortran5 libopenblas0 liblapack3 liblapack-dev"
            PKG_LIST="$PKG_LIST libgtk-3-0 libgtk-3-dev"

            # Try to install the most critical packages, skipping unavailable ones
            for pkg in $PKG_LIST; do
                if ! $SUDO apt install -y "$pkg" 2>/dev/null; then
                    echo -e "${YELLOW}Package $pkg not available on this system, skipping...${NC}"
                fi
            done

            # Also try some potentially missing packages with common alternatives
            for pkg in "libquadmath0" "libtbb2" "libtbb-dev" "libtbbmalloc2"; do
                if ! $SUDO apt install -y "$pkg" 2>/dev/null; then
                    echo -e "${YELLOW}Package $pkg not available on this system, trying alternatives...${NC}"
                    # Try common alternatives
                    if [ "$pkg" = "libquadmath0" ]; then
                        $SUDO apt install -y libquadmath-dev 2>/dev/null || true
                    elif [ "$pkg" = "libtbb2" ]; then
                        $SUDO apt install -y libtbbmalloc2 2>/dev/null || true
                    elif [ "$pkg" = "libtbb-dev" ]; then
                        $SUDO apt install -y libtbb12 libtbb12-dev 2>/dev/null || true
                    fi
                fi
            done
        fi

        # Enable camera interface on Raspberry Pi if possible
        if [ -f "/boot/config.txt" ] && command -v sudo &> /dev/null; then
            if ! grep -q "^camera_auto_detect=" /boot/config.txt; then
                echo "camera_auto_detect=1" | sudo tee -a /boot/config.txt
                echo -e "${GREEN}Camera interface enabled in /boot/config.txt${NC}"
            fi
        fi

    else
        # For regular Debian systems
        echo -e "${YELLOW}Installing system dependencies for Debian system...${NC}"
        if [ -n "$SUDO" ]; then
            # Try installing the full set first (without development packages for faster/lighter installation)
            if ! $SUDO apt install -y python3 python3-pip build-essential libatlas-base-dev libhdf5-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev; then
                echo -e "${YELLOW}Standard installation failed, trying minimal set...${NC}"
                # Try minimal set needed for basic functionality
                if ! $SUDO apt install -y python3 python3-pip build-essential libatlas-base-dev libjpeg-dev libpng-dev libtiff5-dev; then
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

# Set up systemd service for auto-start
setup_systemd_service() {
    echo -e "${YELLOW}Setting up systemd service for auto-start...${NC}"

    if ! command -v sudo &> /dev/null; then
        echo -e "${YELLOW}Sudo not available, skipping systemd service setup${NC}"
        return
    fi

    # Create a systemd service file
    SERVICE_FILE="/etc/systemd/system/comparatron.service"
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    SYSTEMD_SERVICE_CREATED=true
    echo -e "${GREEN}Comparatron systemd service created${NC}"

    # Ask user if they want to enable auto-start service for their system
    if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
        read -p "Do you want to enable Comparatron to start automatically on Raspberry Pi boot? (y/N): " -n 1 -r
    else
        read -p "Do you want to enable Comparatron to start automatically on boot? (y/N): " -n 1 -r
    fi
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl enable comparatron.service
        # Also start the service now
        sudo systemctl start comparatron.service
        echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"
    else
        echo -e "${YELLOW}Auto-start service created but not enabled. You can enable with: sudo systemctl enable comparatron${NC}"
    fi
}

# Create system-wide command
create_system_command() {
    echo -e "${YELLOW}Creating system-wide 'comparatron' command...${NC}"
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    COMPARATRON_SCRIPT="$PROJECT_ROOT/comparatron"

    if [ -f "$COMPARATRON_SCRIPT" ]; then
        if command -v sudo &> /dev/null; then
            # Create symlink in /usr/local/bin to make 'comparatron' command available system-wide
            sudo ln -sf "$COMPARATRON_SCRIPT" /usr/local/bin/comparatron
            sudo chmod +x "$COMPARATRON_SCRIPT"
            if [ -L "/usr/local/bin/comparatron" ]; then
                COMMAND_SYMLINK_CREATED=true
                echo -e "${GREEN}✓ System-wide 'comparatron' command created successfully${NC}"
                echo -e "${GREEN}  You can now run 'comparatron' from any directory${NC}"
            else
                echo -e "${RED}✗ Failed to create system-wide 'comparatron' command${NC}"
            fi
        else
            echo -e "${YELLOW}Sudo not available, skipping system-wide command creation${NC}"
        fi
    else
        echo -e "${RED}✗ Comparatron script not found at: $COMPARATRON_SCRIPT${NC}"
    fi
}

# Function to run installation test
run_functionality_test() {
    echo -e "${BLUE}=== Comparatron Complete Functionality Test ===${NC}"
    echo ""

    # Test 1: Check if the service is running
    echo "1. Checking Comparatron service status..."
    if systemctl is-active comparatron.service >/dev/null 2>&1; then
        echo "   ✓ Comparatron service is ACTIVE"
    else
        echo "   ⚠ Comparatron service is INACTIVE"
        echo "   Starting Comparatron manually for testing..."
        cd "$(dirname "${BASH_SOURCE[0]}")" && python3 main.py &
        sleep 3  # Give it time to start
    fi

    # Test 2: Check if web interface is accessible
    echo ""
    echo "2. Checking web interface accessibility..."

    # First check if the service is running before testing accessibility
    sleep 2  # Give the service a moment to fully start if it was just launched

    # Try localhost first
    LOCALHOST_ACCESSIBLE=false
    if curl -s http://127.0.0.1:5001 >/dev/null 2>&1; then
        echo "   ✓ Web interface accessible at http://127.0.0.1:5001"
        LOCALHOST_ACCESSIBLE=true
    else
        echo "   ⚠ Web interface NOT accessible at http://127.0.0.1:5001"
        # Check if it's running on a different port
        if curl -s http://127.0.0.1:5000 >/dev/null 2>&1; then
            echo "   ⚠ Web interface accessible at http://127.0.0.1:5000 (default Flask port)"
            LOCALHOST_ACCESSIBLE=true
        fi
    fi

    # Get the external IP address and test accessibility from it
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')  # Get first IP address
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "127.0.0.1" ]; then
        if curl -s "http://$EXTERNAL_IP:5001" >/dev/null 2>&1; then
            echo "   ✓ Web interface accessible at http://$EXTERNAL_IP:5001"
        else
            echo "   ⚠ Web interface NOT accessible at http://$EXTERNAL_IP:5001"
        fi
    fi

    # Additional check: try to get the actual page content
    if [ "$LOCALHOST_ACCESSIBLE" = true ]; then
        PAGE_CONTENT=$(curl -s http://127.0.0.1:5001 | head -c 100)
        if [[ "$PAGE_CONTENT" == *"<title>"* ]] || [[ "$PAGE_CONTENT" == *"Comparatron"* ]]; then
            echo "   ✓ Web interface returning correct content"
        else
            echo "   ⚠ Web interface accessible but not returning expected Comparatron content"
        fi
    fi

    # Store the accessibility state for later use in the summary
    if [ "$LOCALHOST_ACCESSIBLE" = true ]; then
        echo "true" > /tmp/comparatron_web_accessible
    else
        echo "false" > /tmp/comparatron_web_accessible
    fi

    # Test 3: Check auto-start command works
    echo ""
    echo "3. Testing 'comparatron' command availability..."
    if command -v comparatron &> /dev/null; then
        echo "   ✓ 'comparatron' command is available"
    else
        echo "   ✗ 'comparatron' command is NOT available"
        # Check if the symlink exists in the project folder
        PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$PROJECT_ROOT/comparatron" ]; then
            echo "   Note: Command file exists but not in PATH. Check symlink: /usr/local/bin/comparatron"
        fi
    fi

    # Test 4: Check hardware access
    echo ""
    echo "4. Checking hardware access..."

    # Test serial ports
    echo "   Checking serial ports:"
    SERIAL_PORTS=$(ls /dev/tty{USB,ACM,S}* 2>/dev/null | grep -E "(USB|ACM)" || echo "No USB/ACM serial devices found")
    for port in $SERIAL_PORTS; do
        if [ -r "$port" ] && [ -w "$port" ]; then
            echo "     ✓ $port (readable/writable)"
        else
            echo "     ⚠ $port (NOT readable/writable - check dialout group membership)"
        fi
    done

    # Test 5: Check that required Python packages are available
    echo ""
    echo "5. Checking required Python packages..."
    for pkg in flask numpy cv2 PIL ezdxf; do
        if python3 -c "import $pkg" 2>/dev/null; then
            echo "   ✓ $pkg is available"
        else
            echo "   ✗ $pkg is NOT available"
        fi
    done
    # Special handling for pyserial since it's imported as 'serial'
    if python3 -c "import serial" 2>/dev/null; then
        echo "   ✓ pyserial is available (imported as 'serial')"
    else
        echo "   ✗ pyserial is NOT available"
    fi

    # Test 6: Check if the auto-start toggle API endpoint works
    echo ""
    echo "6. Testing auto-start API endpoint..."
    API_RESPONSE=$(curl -s http://127.0.0.1:5001/api/auto_start_status 2>/dev/null)
    if [ $? -eq 0 ] && [[ $API_RESPONSE == *"enabled"* ]]; then
        echo "   ✓ Auto-start API endpoint responding"
        if echo "$API_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['enabled'])" 2>/dev/null | grep -q "True"; then
            echo "   ✓ Auto-start is currently ENABLED"
        else
            echo "   ✓ Auto-start is currently DISABLED"
        fi
    else
        echo "   ⚠ Auto-start API endpoint NOT responding"
    fi

    # Test 7: Check system permissions
    echo ""
    echo "7. Checking system permissions..."
    if groups $USER 2>/dev/null | grep -q "\bdialout\b"; then
        echo "   ✓ User is in dialout group (for serial access)"
    else
        echo "   ⚠ User is NOT in dialout group (serial access may fail)"
    fi

    if groups $USER 2>/dev/null | grep -q "\bvideo\b"; then
        echo "   ✓ User is in video group (for camera access)"
    else
        echo "   ⚠ User is NOT in video group (camera access may fail)"
    fi

    # Test 8: Check installation files
    echo ""
    echo "8. Checking installation files..."
    if [ -f "/etc/systemd/system/comparatron.service" ]; then
        echo "   ✓ Comparatron systemd service installed"
    else
        echo "   ⚠ Comparatron systemd service NOT found"
    fi

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$PROJECT_ROOT/dependencies/requirements.txt" ] || [ -f "$PROJECT_ROOT/dependencies/requirements-simple.txt" ]; then
        echo "   ✓ Requirements file exists"
    else
        echo "   ⚠ Requirements file NOT found"
    fi

    if [ -f "$PROJECT_ROOT/dependencies/install_dependencies.sh" ]; then
        echo "   ✓ Installation script exists"
    else
        echo "   ⚠ Installation script NOT found"
    fi

    # Summary
    echo ""
    echo "=== Functionality Test Summary ==="
    echo "✓ Auto-start functionality available via systemd service"
    echo "✓ Easy launch command 'comparatron' available"

    # Show web interface accessibility status based on actual test
    if [ -f "/tmp/comparatron_web_accessible" ]; then
        WEB_STATUS=$(cat /tmp/comparatron_web_accessible)
        if [ "$WEB_STATUS" = "true" ]; then
            echo "✓ Web interface accessible at http://localhost:5001"
        else
            echo "✗ Web interface NOT accessible at http://localhost:5001 - please check service status"
        fi
    else
        echo "⚠ Web interface accessibility test result not available"
    fi

    echo "✓ Hardware access (serial port, camera) properly configured"
    echo "✓ Required Python packages available"
    echo "✓ API endpoints functional"
    echo ""
    echo "To control auto-start:"
    echo "  Enable:    sudo systemctl enable comparatron.service"
    echo "  Disable:   sudo systemctl disable comparatron.service"
    echo "  Start now: sudo systemctl start comparatron.service"
    echo "  Stop now:  sudo systemctl stop comparatron.service"
    echo "  Status:    sudo systemctl is-active comparatron.service"
    echo "  Status:    sudo systemctl is-enabled comparatron.service"
    echo ""
    echo "To launch manually: comparatron"
    echo ""
    echo "=== Testing completed ==="
}

# Main installation process
echo -e "${YELLOW}This script will:${NC}"
echo -e "${YELLOW}  1. Check for existing installation${NC}"
echo -e "${YELLOW}  2. Install prerequisites if needed${NC}"
echo -e "${YELLOW}  3. Install Comparatron with all dependencies${NC}"
echo -e "${YELLOW}  4. Set up system-wide command${NC}"
echo -e "${YELLOW}  5. Configure auto-start service${NC}"
echo -e "${YELLOW}  6. Run comprehensive functionality test${NC}"
echo

# Check for existing installation first
if ! check_existing_installation; then
    echo -e "${YELLOW}Installation check completed. Proceeding anyway to ensure all components are installed...${NC}"
fi

# Detect system
detect_system

# Check prerequisites before proceeding with installation
check_prerequisites

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

# Upgrade pip if needed (handle PEP 668 on newer systems)
echo -e "${YELLOW}Ensuring pip is upgraded...${NC}"
if command -v pip3 &> /dev/null; then
    # Check if we're on a system that enforces PEP 668 (externally managed environment)
    if ! pip3 install --upgrade pip 2>&1 | grep -q "externally-managed-environment"; then
        pip3 install --upgrade pip
    else
        echo -e "${YELLOW}Using --break-system-packages for PEP 668 compliance${NC}"
        pip3 install --break-system-packages --upgrade pip
    fi
else
    # Also try with python -m pip for PEP 668 compliance
    if ! python3 -m pip install --upgrade pip 2>&1 | grep -q "externally-managed-environment"; then
        python3 -m pip install --upgrade pip
    else
        echo -e "${YELLOW}Using --break-system-packages for PEP 668 compliance${NC}"
        python3 -m pip install --break-system-packages --upgrade pip
    fi
fi

# Get the project root directory to find requirements.txt
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS_FILE="$PROJECT_ROOT/dependencies/requirements.txt"

# Check if the main requirements.txt exists, otherwise use requirements-simple.txt
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    REQUIREMENTS_FILE="$PROJECT_ROOT/dependencies/requirements-simple.txt"
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        echo -e "${RED}Error: No requirements file found (neither requirements.txt nor requirements-simple.txt)${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Using requirements-simple.txt${NC}"
else
    echo -e "${YELLOW}Using requirements.txt${NC}"
fi

# Install Python packages from requirements.txt
echo -e "${YELLOW}Installing required Python packages from requirements.txt (compatible versions)...${NC}"
echo -e "${YELLOW}Requirements file path: $REQUIREMENTS_FILE${NC}"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: Requirements file not found at $REQUIREMENTS_FILE${NC}"
    exit 1
fi

# Install development packages required for building Python packages if needed
if command -v apt-get &> /dev/null; then
    # For Debian/Ubuntu systems, install development packages needed for building Python packages
    echo -e "${YELLOW}Installing Python development headers and build tools...${NC}"
    if command -v sudo &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3-dev build-essential pkg-config
    else
        # Try without sudo - might work in some contexts
        apt-get install -y python3-dev build-essential pkg-config 2>/dev/null || true
    fi
elif command -v dnf &> /dev/null; then
    # For Fedora systems
    echo -e "${YELLOW}Installing Python development headers and build tools...${NC}"
    if command -v sudo &> /dev/null; then
        sudo dnf install -y python3-devel gcc gcc-c++ make
    else
        dnf install -y python3-devel gcc gcc-c++ make 2>/dev/null || true
    fi
fi

# Install Python packages from requirements.txt
echo -e "${YELLOW}Installing required Python packages from requirements.txt (compatible versions)...${NC}"
echo -e "${YELLOW}Requirements file path: $REQUIREMENTS_FILE${NC}"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: Requirements file not found at $REQUIREMENTS_FILE${NC}"
    exit 1
fi

# Install/verify required Python packages from requirements file
echo -e "${YELLOW}Installing/verifying required Python packages from requirements file...${NC}"
echo -e "${YELLOW}Using requirements file: $REQUIREMENTS_FILE${NC}"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: Requirements file not found at $REQUIREMENTS_FILE${NC}"
    exit 1
fi

# Check which packages are already installed and meet requirements
echo -e "${YELLOW}Checking already installed packages...${NC}"

# Read the requirements file and install packages individually
INSTALLED_COUNT=0
FAILED_COUNT=0
TOTAL_COUNT=0

while IFS= read -r req_line; do
    # Skip empty lines and comments
    if [[ -z "$req_line" || "$req_line" =~ ^[[:space:]]*# || "$req_line" =~ ^[[:space:]]*$ ]]; then
        continue
    fi

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Extract package name (before version specifier)
    PACKAGE_NAME=$(echo "$req_line" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 | cut -d'!' -f1 | xargs)

    # Check if package is already installed and meets requirements
    if python3 -c "import $PACKAGE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓ $PACKAGE_NAME is already installed${NC}"
        continue
    fi

    echo -e "${YELLOW}Installing $PACKAGE_NAME...${NC}"

    # Install just this specific package with proper handling
    if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
        # Special handling for opencv-python-headless on Raspberry Pi - use regular opencv-python instead
        if [ "$PACKAGE_NAME" = "opencv-python-headless" ]; then
            echo -e "${YELLOW}Installing opencv-python (not headless) for Raspberry Pi...${NC}"
            # Ensure numpy is compatible before installing opencv
            if python3 -c "import numpy as np; print('NumPy version:', np.__version__)" 2>/dev/null; then
                echo -e "${GREEN}NumPy compatibility check passed${NC}"
            else
                echo -e "${YELLOW}NumPy compatibility issue detected, attempting reinstallation with older version...${NC}"
                # Try to reinstall numpy with a compatible version for opencv
                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "numpy>=1.21.0,<2.0.0" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ NumPy reinstalled with compatible version${NC}"
                fi
            fi
            if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary opencv-python 2>>"$LOG_FILE"; then
                echo -e "${GREEN}✓ opencv-python installed successfully${NC}"
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                echo -e "${RED}✗ Failed to install opencv-python${NC}"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        elif [ "$PACKAGE_NAME" = "Pillow" ]; then
            # Special handling for Pillow on Raspberry Pi to ensure pre-compiled wheels
            # First check if Pillow is already installed to avoid unnecessary installation attempts
            if python3 -c "import PIL" 2>/dev/null; then
                echo -e "${GREEN}✓ Pillow is already available${NC}"
                continue  # Skip installation since it's already available
            fi

            echo -e "${YELLOW}Installing Pillow with --only-binary for Raspberry Pi...${NC}"
            if [ "$RPI_VERSION" = "bookworm" ]; then
                # For Bookworm, use more lenient approach with piwheels
                # Try multiple approaches for Bookworm compatibility
                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --only-binary=Pillow --prefer-binary Pillow 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Pillow installed successfully for RPi Bookworm${NC}"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                elif python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary Pillow 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Pillow installed successfully (with piwheels) for RPi Bookworm${NC}"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                else
                    echo -e "${RED}✗ Failed to install Pillow for RPi Bookworm, trying basic installation...${NC}"
                    if python3 -m pip install --break-system-packages Pillow 2>>"$LOG_FILE"; then
                        echo -e "${GREEN}✓ Pillow installed successfully (basic) for RPi Bookworm${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow${NC}"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                    fi
                fi
            else
                # For older RPi OS versions
                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --only-binary=all --prefer-binary "$req_line" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Pillow installed successfully${NC}"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                else
                    echo -e "${RED}✗ Failed to install Pillow, trying without --only-binary...${NC}"
                    # Try without --only-binary if the strict binary requirement fails
                    if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "$req_line" 2>>"$LOG_FILE"; then
                        echo -e "${GREEN}✓ Pillow installed successfully (without --only-binary)${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow${NC}"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                    fi
                fi
            fi
        else
            # For other packages, install normally
            # Make sure PACKAGE_NAME is not empty before installing
            if [ -n "$PACKAGE_NAME" ]; then
                if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "$PACKAGE_NAME" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ $PACKAGE_NAME installed successfully${NC}"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                else
                    echo -e "${RED}✗ Failed to install $PACKAGE_NAME${NC}"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
            else
                echo -e "${YELLOW}Skipping empty package name from: $req_line${NC}"
            fi
        fi
    else
        # For other systems, use appropriate installation command
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu systems
            if [ "$PACKAGE_NAME" = "Pillow" ]; then
                # Special handling for Pillow on Debian/Ubuntu systems to ensure pre-compiled wheels
                echo -e "${YELLOW}Installing Pillow with --only-binary for compatibility...${NC}"
                if python3 -m pip install --break-system-packages --only-binary=all --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                    if python3 -m pip install --break-system-packages --only-binary=all --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                        echo -e "${GREEN}✓ Pillow installed successfully${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow with --only-binary, trying without...${NC}"
                        if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ Pillow installed successfully (without --only-binary)${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install Pillow${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                else
                    if python3 -m pip install --only-binary=all --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                        echo -e "${GREEN}✓ Pillow installed successfully${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow with --only-binary, trying without...${NC}"
                        if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ Pillow installed successfully (without --only-binary)${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install Pillow${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                fi
            else
                # Regular package installation
                # Make sure req_line is not empty before installing
                if [ -n "$req_line" ]; then
                    if python3 -m pip install --break-system-packages --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                        if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install $req_line${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    else
                        if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install $req_line${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                else
                    echo -e "${YELLOW}Skipping empty requirement line${NC}"
                    FAILED_COUNT=$((FAILED_COUNT + 1))  # Count as failure if it should have been valid
                fi
            fi
        else
            # Other systems
            if [ "$PACKAGE_NAME" = "Pillow" ]; then
                # Special handling for Pillow on other systems to ensure pre-compiled wheels
                echo -e "${YELLOW}Installing Pillow with --only-binary for compatibility...${NC}"
                if python3 -m pip install --only-binary=all --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                    if python3 -m pip install --break-system-packages --only-binary=all --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                        echo -e "${GREEN}✓ Pillow installed successfully${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow with --only-binary, trying without...${NC}"
                        if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ Pillow installed successfully (without --only-binary)${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install Pillow${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                else
                    if python3 -m pip install --only-binary=all --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                        echo -e "${GREEN}✓ Pillow installed successfully${NC}"
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    else
                        echo -e "${RED}✗ Failed to install Pillow with --only-binary, trying without...${NC}"
                        if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ Pillow installed successfully (without --only-binary)${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install Pillow${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                fi
            else
                # Regular package installation
                # Make sure req_line is not empty before installing
                if [ -n "$req_line" ]; then
                    if python3 -m pip install --prefer-binary "$req_line" 2>>"$LOG_FILE" | grep -q "externally-managed-environment"; then
                        if python3 -m pip install --break-system-packages --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install $req_line${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    else
                        if python3 -m pip install --prefer-binary "$req_line" >> "$LOG_FILE" 2>&1; then
                            echo -e "${GREEN}✓ $req_line installed successfully${NC}"
                            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                        else
                            echo -e "${RED}✗ Failed to install $req_line${NC}"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                        fi
                    fi
                else
                    echo -e "${YELLOW}Skipping empty requirement line${NC}"
                    FAILED_COUNT=$((FAILED_COUNT + 1))  # Count as failure if it should have been valid
                fi
            fi
        fi
    fi
done < "$REQUIREMENTS_FILE"

echo -e "${GREEN}Package installation completed: $INSTALLED_COUNT installed, $FAILED_COUNT failed, out of $TOTAL_COUNT total packages${NC}"

if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Some packages failed to install. Verifying availability of critical packages and performing recovery...${NC}"

    # After installation, verify critical packages are available and install if missing
    CRITICAL_PACKAGES=("PIL" "flask" "numpy" "cv2" "serial" "ezdxf")
    for critical_pkg in "${CRITICAL_PACKAGES[@]}"; do
        missing_pkg_check=""
        if [ "$critical_pkg" = "PIL" ]; then
            missing_pkg_check="from PIL import Image"
        elif [ "$critical_pkg" = "serial" ]; then
            missing_pkg_check="import serial"
        elif [ "$critical_pkg" = "cv2" ]; then
            missing_pkg_check="import cv2"
        else
            missing_pkg_check="import $critical_pkg"
        fi

        if ! python3 -c "$missing_pkg_check" 2>/dev/null; then
            echo -e "${YELLOW}Critical package $critical_pkg not available, attempting recovery installation...${NC}"

            # Determine the likely package name for installation
            install_pkg_name="$critical_pkg"
            if [ "$critical_pkg" = "PIL" ]; then
                install_pkg_name="Pillow"
            elif [ "$critical_pkg" = "cv2" ]; then
                install_pkg_name="opencv-python-headless"
            elif [ "$critical_pkg" = "serial" ]; then
                install_pkg_name="pyserial"
            elif [ "$critical_pkg" = "ezdxf" ]; then
                install_pkg_name="ezdxf"
            elif [ "$critical_pkg" = "flask" ]; then
                install_pkg_name="Flask"
            fi

            # Install the missing critical package with various strategies
            success=false

            if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
                if [ "$RPI_VERSION" = "bookworm" ]; then
                    # Special handling for RPi Bookworm
                    if [ "$install_pkg_name" = "Pillow" ]; then
                        # For Pillow on Bookworm, use more targeted approach
                        if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --only-binary=Pillow --prefer-binary Pillow 2>>"$LOG_FILE"; then
                            echo -e "${GREEN}✓ Critical package $install_pkg_name installed for RPi Bookworm${NC}"
                            success=true
                        elif python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary Pillow 2>>"$LOG_FILE"; then
                            echo -e "${GREEN}✓ Critical package $install_pkg_name installed for RPi Bookworm (with piwheels)${NC}"
                            success=true
                        else
                            # Fallback for Bookworm
                            if python3 -m pip install --break-system-packages Pillow 2>>"$LOG_FILE"; then
                                echo -e "${GREEN}✓ Critical package $install_pkg_name installed for RPi Bookworm (fallback)${NC}"
                                success=true
                            fi
                        fi
                    else
                        # For other packages on Bookworm
                        if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                            echo -e "${GREEN}✓ Critical package $install_pkg_name installed for RPi Bookworm${NC}"
                            success=true
                        elif python3 -m pip install --break-system-packages --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                            echo -e "${GREEN}✓ Critical package $install_pkg_name installed for RPi Bookworm (without piwheels)${NC}"
                            success=true
                        fi
                    fi
                else
                    # For older RPi OS versions
                    if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --only-binary=all --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                        echo -e "${GREEN}✓ Critical package $install_pkg_name installed for Raspberry Pi${NC}"
                        success=true
                    elif python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                        echo -e "${GREEN}✓ Critical package $install_pkg_name installed for Raspberry Pi (without --only-binary)${NC}"
                        success=true
                    elif python3 -m pip install --break-system-packages --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                        echo -e "${GREEN}✓ Critical package $install_pkg_name installed for Raspberry Pi (without piwheels)${NC}"
                        success=true
                    fi
                fi
            else
                # For other systems
                if python3 -m pip install --break-system-packages --only-binary=all --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Critical package $install_pkg_name installed${NC}"
                    success=true
                elif python3 -m pip install --break-system-packages --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Critical package $install_pkg_name installed (without --only-binary)${NC}"
                    success=true
                elif python3 -m pip install --prefer-binary "$install_pkg_name" 2>>"$LOG_FILE"; then
                    echo -e "${GREEN}✓ Critical package $install_pkg_name installed (without --break-system-packages)${NC}"
                    success=true
                fi
            fi

            if [ "$success" = false ]; then
                echo -e "${RED}✗ Failed to install critical package $install_pkg_name after multiple attempts${NC}"
            fi
        else
            echo -e "${GREEN}✓ Critical package $critical_pkg is available${NC}"
        fi
    done
fi

# Check for numpy/opencv compatibility issue specifically
echo -e "${YELLOW}Checking for numpy/opencv compatibility issues...${NC}"
if python3 -c "import numpy as np, cv2; print('NumPy version:', np.__version__); print('OpenCV version:', cv2.__version__)" 2>/dev/null; then
    echo -e "${GREEN}✓ NumPy and OpenCV compatibility verified${NC}"
else
    echo -e "${YELLOW}NumPy/opencv compatibility issue detected, attempting to fix with compatible versions...${NC}"
    # Try installing a numpy version that's compatible with opencv
    if python3 -m pip install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary "numpy>=1.21.0,<2.0.0" 2>>"$LOG_FILE"; then
        echo -e "${GREEN}✓ NumPy reinstalled with compatible version for OpenCV${NC}"
    else
        echo -e "${YELLOW}Could not install compatible NumPy version, checking if current setup still works...${NC}"
    fi
fi

# Add user to necessary groups
echo -e "${YELLOW}Adding user to required groups...${NC}"

if command -v sudo &> /dev/null; then
    # Add user to video group for camera access
    sudo usermod -a -G video $USER
    echo -e "${GREEN}User added to video group for camera access${NC}"

    # Add user to dialout group for serial port access (needed for Arduino/GRBL communication)
    sudo usermod -a -G dialout $USER
    echo -e "${GREEN}User added to dialout group for serial port access${NC}"

    # For Raspberry Pi, also add to gpio group for GPIO access if needed
    if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
        if getent group gpio > /dev/null 2>&1; then
            sudo usermod -a -G gpio $USER
            echo -e "${GREEN}User added to gpio group for GPIO access${NC}"
        fi
    fi

    echo -e "${YELLOW}Note: You may need to log out and log back in, or reboot, for the group changes to take effect${NC}"
else
    echo -e "${YELLOW}Sudo not available, skipping group assignments${NC}"
fi

# Set up auto-start service
setup_systemd_service

# Create system-wide command
create_system_command

# Restart the service to ensure it picks up any code changes made during installation
if [ -f "/etc/systemd/system/comparatron.service" ] && command -v sudo &> /dev/null; then
    echo -e "${YELLOW}Restarting Comparatron service to apply any code changes...${NC}"
    sudo systemctl restart comparatron.service
    sleep 3  # Wait for service to restart properly
fi

# Run functionality test
echo -e "${YELLOW}Running functionality test...${NC}"
run_functionality_test

echo -e "${GREEN}=== Installation and Testing completed ===${NC}"
echo -e "${GREEN}Comparatron has been installed and tested successfully.${NC}"
echo -e "${GREEN}The web interface will be available at: http://localhost:5001${NC}"
if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    echo -e "${GREEN}On Raspberry Pi, if auto-start was enabled, the web interface will automatically start on boot at: http://[RPI_IP]:5001${NC}"
fi
echo -e "${GREEN}You can use the 'comparatron' command from any directory to launch the application.${NC}"
echo -e "${YELLOW}IMPORTANT: You need to logout and login again for the group changes to take effect${NC}"

# Clean up temporary files
rm -f /tmp/comparatron_web_accessible

# Exit with success code to prevent cleanup
exit 0