#!/bin/bash

# Comparatron Complete Installation Script
# Simplified version with streamlined menu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron and LaserWeb4 Installation Suite ===${NC}"

# Function to show main menu
show_main_menu() {
    echo ""
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1) Install/Manage Comparatron"
    echo "2) Install/Manage LaserWeb4"
    echo "3) Check Installation Status"
    echo "4) Help - Useful Commands and Information"
    echo "5) Exit"
    read -p "Enter your choice (1-5): " choice
    echo ""
}

# Function to manage Comparatron
manage_comparatron() {
    echo -e "${YELLOW}=== Comparatron Management ===${NC}"
    echo "1) Install Comparatron"
    echo "2) Uninstall Comparatron"
    echo "3) Back to main menu"
    read -p "Enter your choice (1-3): " comp_choice
    echo ""
    
    case $comp_choice in
        1)
            echo -e "${YELLOW}Installing Comparatron...${NC}"
            # Run the actual Comparatron installation process
            # This replicates the original installation logic
            echo -e "${YELLOW}Checking prerequisites...${NC}"

            # Check if git is installed
            if ! command -v git &> /dev/null; then
                echo -e "${RED}Git is not installed. Installing...${NC}"
                if command -v sudo &> /dev/null; then
                    if command -v dnf &> /dev/null; then
                        sudo dnf install -y git
                    elif command -v apt-get &> /dev/null; then
                        sudo apt update && sudo apt install -y git
                    else
                        echo -e "${RED}Cannot install git automatically. Please install git manually.${NC}"
                        read -p "Press Enter to continue anyway..."
                        return
                    fi
                else
                    echo -e "${RED}Cannot install git without sudo. Please install git manually.${NC}"
                    read -p "Press Enter to continue anyway..."
                    return
                fi
            else
                echo -e "${GREEN}✓ Git is installed${NC}"
            fi

            # Check if Python 3 is installed
            if ! command -v python3 &> /dev/null; then
                echo -e "${RED}Python 3 is not installed. This is required for Comparatron.${NC}"
                if command -v sudo &> /dev/null; then
                    if command -v dnf &> /dev/null; then
                        sudo dnf install -y python3 python3-pip
                    elif command -v apt-get &> /dev/null; then
                        sudo apt update && sudo apt install -y python3 python3-pip
                    else
                        echo -e "${RED}Cannot install Python automatically. Please install Python 3 manually.${NC}"
                        read -p "Press Enter to continue anyway..."
                        return
                    fi
                else
                    echo -e "${RED}Cannot install Python without sudo. Please install Python 3 manually.${NC}"
                    read -p "Press Enter to continue anyway..."
                    return
                fi
            else
                echo -e "${GREEN}✓ Python 3 is installed${NC}"
            fi

            # Check if pip3 is available
            if ! command -v pip3 &> /dev/null; then
                echo -e "${RED}pip3 is not installed. Installing...${NC}"
                if command -v sudo & > /dev/null; then
                    if command -v dnf &> /dev/null; then
                        sudo dnf install -y python3-pip
                    elif command -v apt-get &> /dev/null; then
                        sudo apt install -y python3-pip
                    else
                        echo -e "${RED}Cannot install pip automatically.${NC}"
                        read -p "Press Enter to continue anyway..."
                        return
                    fi
                fi
            else
                echo -e "${GREEN}✓ pip3 is installed${NC}"
            fi

            # Install required Python packages
            echo -e "${YELLOW}Installing required Python packages...${NC}"
            REQUIRED_PACKAGES="flask numpy opencv-python-headless Pillow pyserial ezdxf"
            for package in $REQUIRED_PACKAGES; do
                if python3 -c "import $(echo $package | sed 's/opencv-python-headless/cv2/' | sed 's/pyserial/serial/')"; then
                    echo -e "${GREEN}✓ $package already installed${NC}"
                else
                    echo -e "${YELLOW}Installing $package...${NC}"
                    if pip3 install --break-system-packages "$package" 2>/dev/null || pip3 install "$package"; then
                        echo -e "${GREEN}✓ $package installed successfully${NC}"
                    else
                        echo -e "${RED}✗ Failed to install $package${NC}"
                    fi
                fi
            done

            # Create system-wide command
            echo -e "${YELLOW}Creating system-wide command...${NC}"
            if command -v sudo &> /dev/null; then
                sudo ln -sf "$(pwd)/comparatron" /usr/local/bin/comparatron 2>/dev/null || \
                sudo cp "$(pwd)/comparatron" /usr/local/bin/comparatron 2>/dev/null || \
                echo -e "${YELLOW}Could not create system-wide command. You can run Comparatron with './comparatron'${NC}"
            else
                echo -e "${YELLOW}Sudo not available, skipping system-wide command creation${NC}"
            fi

            # Set up systemd service for auto-start
            echo -e "${YELLOW}Setting up systemd service for auto-start...${NC}"
            if command -v sudo &> /dev/null; then
                PROJECT_ROOT="$(pwd)"
                SERVICE_FILE="/etc/systemd/system/comparatron.service"
                
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

                echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" 2>/dev/null
                sudo systemctl daemon-reload 2>/dev/null
                echo -e "${GREEN}Comparatron systemd service created${NC}"
                
                # Ask user if they want to enable auto-start
                read -p "Do you want to enable Comparatron to start automatically on boot? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo systemctl enable comparatron.service 2>/dev/null
                    sudo systemctl start comparatron.service 2>/dev/null
                    echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"
                else
                    echo -e "${YELLOW}Auto-start service created but not enabled.${NC}"
                fi
            else
                echo -e "${YELLOW}Sudo not available, skipping systemd service setup${NC}"
            fi

            # Add user to dialout group for serial access
            if command -v sudo &> /dev/null; then
                sudo usermod -a -G dialout $USER 2>/dev/null
                echo -e "${GREEN}User added to dialout group for serial port access${NC}"
            fi

            # Add user to video group for camera access
            if command -v sudo &> /dev/null; then
                sudo usermod -a -G video $USER 2>/dev/null
                echo -e "${GREEN}User added to video group for camera access${NC}"
            fi

            echo -e "${GREEN}=== Comparatron Installation Completed ===${NC}"
            echo -e "${GREEN}To start Comparatron:${NC}"
            echo -e "${GREEN}  - Run: ./comparatron${NC}"
            echo -e "${GREEN}  - Or access the web interface at: http://localhost:5001${NC}"
            echo -e "${YELLOW}Note: Log out and log back in for group changes to take effect${NC}"
            ;;
        2)
            echo -e "${YELLOW}Uninstalling Comparatron...${NC}"
            if [ -f "./dependencies/uninstall.sh" ]; then
                chmod +x ./dependencies/uninstall.sh
                ./dependencies/uninstall.sh
            else
                echo -e "${RED}Comparatron uninstall script not found!${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            ;;
    esac
    read -p "Press Enter to continue..."
}

# Function to manage LaserWeb4
manage_laserweb4() {
    echo -e "${YELLOW}=== LaserWeb4 Management ===${NC}"
    echo "1) Install LaserWeb4"
    echo "2) Uninstall LaserWeb4"
    echo "3) Back to main menu"
    read -p "Enter your choice (1-3): " laser_choice
    echo ""
    
    case $laser_choice in
        1)
            echo -e "${YELLOW}Installing LaserWeb4...${NC}"
            echo -e "${YELLOW}Please note: This will run the LaserWeb4 installer which will ask for your Node.js version preference.${NC}"
            if [ -f "./laserweb4/install_laserweb4.sh" ]; then
                chmod +x ./laserweb4/install_laserweb4.sh
                ./laserweb4/install_laserweb4.sh
            else
                echo -e "${RED}LaserWeb4 installation script not found!${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}Uninstalling LaserWeb4...${NC}"
            echo -e "${YELLOW}Please note: This will run the LaserWeb4 uninstaller which may ask for confirmation.${NC}"
            echo -e "${YELLOW}If prompted, please respond to the questions.${NC}"
            if [ -f "./laserweb4/install_laserweb4.sh" ]; then
                chmod +x ./laserweb4/install_laserweb4.sh
                ./laserweb4/install_laserweb4.sh
            else
                echo -e "${RED}LaserWeb4 installation script not found!${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            ;;
    esac
    read -p "Press Enter to continue..."
}

# Function to check installation status
check_status() {
    echo -e "${YELLOW}=== Installation Status ===${NC}"
    
    # Check Comparatron
    echo -e "${BLUE}Comparatron:${NC}"
    if [ -f "/usr/local/bin/comparatron" ]; then
        echo -e "  ${GREEN}✓ System-wide command available: comparatron${NC}"
    else
        echo -e "  ${RED}✗ System-wide command not installed${NC}"
    fi
    
    if [ -f "/etc/systemd/system/comparatron.service" ]; then
        if systemctl is-enabled comparatron.service >/dev/null 2>&1; then
            status=$(systemctl is-active comparatron.service 2>/dev/null)
            echo -e "  ${GREEN}✓ Service installed and enabled${NC} (Status: $status)"
        else
            echo -e "  ${YELLOW}~ Service installed but not enabled${NC}"
        fi
    else
        echo -e "  ${RED}✗ Service not installed${NC}"
    fi
    
    # Check LaserWeb4
    echo -e "${BLUE}LaserWeb4:${NC}"
    if [ -d "$HOME/LaserWeb4" ]; then
        echo -e "  ${GREEN}✓ LaserWeb4 directory exists${NC}"
    else
        echo -e "  ${RED}✗ LaserWeb4 directory not found${NC}"
    fi
    
    if [ -d "$HOME/lw.comm-server" ]; then
        echo -e "  ${GREEN}✓ lw.comm-server directory exists${NC}"
    else
        echo -e "  ${RED}✗ lw.comm-server directory not found${NC}"
    fi
    
    if [ -f "/etc/systemd/system/laserweb.service" ]; then
        if systemctl is-enabled laserweb.service >/dev/null 2>&1; then
            status=$(systemctl is-active laserweb.service 2>/dev/null)
            echo -e "  ${GREEN}✓ Service installed and enabled${NC} (Status: $status)"
        else
            echo -e "  ${YELLOW}~ Service installed but not enabled${NC}"
        fi
    else
        echo -e "  ${RED}✗ Service not installed${NC}"
    fi
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "${BLUE}Node.js: ${GREEN}$NODE_VERSION${NC}"
    else
        echo -e "${BLUE}Node.js: ${RED}Not installed${NC}"
    fi
    
    # Check if npm-run-all is available
    if command -v npm-run-all &> /dev/null; then
        echo -e "${BLUE}npm-run-all: ${GREEN}Available${NC}"
    else
        echo -e "${BLUE}npm-run-all: ${RED}Not available${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to show help information
show_help() {
    echo -e "${YELLOW}=== Help - Useful Commands and Information ===${NC}"
    
    # Network information
    echo -e "${BLUE}Network Information:${NC}"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    if [ -n "$IP_ADDR" ]; then
        echo "  IP Address: $IP_ADDR"
    else
        echo "  IP Address: Unable to determine"
    fi
    
    # Service commands
    echo -e "${BLUE}Service Management:${NC}"
    echo "  Start Comparatron: sudo systemctl start comparatron"
    echo "  Stop Comparatron: sudo systemctl stop comparatron"
    echo "  Restart Comparatron: sudo systemctl restart comparatron"
    echo "  Enable Comparatron auto-start: sudo systemctl enable comparatron"
    echo "  Disable Comparatron auto-start: sudo systemctl disable comparatron"
    echo "  Comparatron status: sudo systemctl status comparatron"
    
    echo ""
    echo "  Start LaserWeb4: sudo systemctl start laserweb"
    echo "  Stop LaserWeb4: sudo systemctl stop laserweb"
    echo "  Restart LaserWeb4: sudo systemctl restart laserweb"
    echo "  Enable LaserWeb4 auto-start: sudo systemctl enable laserweb"
    echo "  Disable LaserWeb4 auto-start: sudo systemctl disable laserweb"
    echo "  LaserWeb4 status: sudo systemctl status laserweb"
    
    # Web interfaces
    echo -e "${BLUE}Web Interfaces:${NC}"
    if [ -n "$IP_ADDR" ]; then
        echo "  Comparatron: http://$IP_ADDR:5001"
        echo "  LaserWeb4: http://$IP_ADDR:8000"
        echo "  LaserWeb4 (if using nginx): http://$IP_ADDR:8080"
    else
        echo "  Comparatron: http://[YOUR_IP]:5001"
        echo "  LaserWeb4: http://[YOUR_IP]:8000"
        echo "  LaserWeb4 (if using nginx): http://[YOUR_IP]:8080"
    fi
    
    # System commands
    echo -e "${BLUE}System Commands:${NC}"
    echo "  Reboot Raspberry Pi: sudo reboot"
    echo "  Shutdown Raspberry Pi: sudo shutdown now"
    echo "  Check disk space: df -h"
    echo "  Check memory usage: free -h"
    echo "  Check running processes: top"
    
    # Troubleshooting
    echo -e "${BLUE}Troubleshooting:${NC}"
    echo "  Check Comparatron logs: sudo journalctl -u comparatron -f"
    echo "  Check LaserWeb4 logs: sudo journalctl -u laserweb -f"
    echo "  Check system logs: sudo journalctl -xe"
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_main_menu
    case $choice in
        1)
            manage_comparatron
            ;;
        2)
            manage_laserweb4
            ;;
        3)
            check_status
            ;;
        4)
            show_help
            ;;
        5)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice! Please try again.${NC}"
            ;;
    esac
done