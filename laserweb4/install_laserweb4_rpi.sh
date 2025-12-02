#!/bin/bash

# LaserWeb4 Installation Script for Raspberry Pi
# Based on official LaserWeb4 Raspberry Pi installation guide:
# https://laserweb.yurl.ch/documentation/installation/36-install-raspberry-pi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Installation for Raspberry Pi ===${NC}"

# Check for Node.js v18.x (recommended by official documentation)
echo -e "${YELLOW}Checking Node.js version...${NC}"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    NODE_FULL_VERSION=$(node --version)
    echo -e "${GREEN}Current Node.js: $NODE_FULL_VERSION${NC}"
    
    if [ "$NODE_VERSION" -ne 18 ]; then
        echo -e "${RED}ERROR: LaserWeb4 works best with Node.js v18.x${NC}"
        echo -e "${RED}Current version: $NODE_FULL_VERSION${NC}"
        echo -e "${YELLOW}Please install Node.js v18.x for optimal LaserWeb4 functionality:${NC}"
        echo -e "${YELLOW}  curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
        echo -e "${YELLOW}  sudo apt install -y nodejs${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: Node.js is not installed.${NC}"
    echo -e "${YELLOW}Install Node.js v18.x first:${NC}"
    echo -e "${YELLOW}  curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -${NC}"
    echo -e "${YELLOW}  sudo apt install -y nodejs${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed.${NC}"
    exit 1
fi

echo -e "${GREEN}npm found: $(npm --version)${NC}"

# Install required system dependencies for Raspberry Pi
echo -e "${YELLOW}Installing system dependencies for Raspberry Pi...${NC}"
if command -v sudo &> /dev/null; then
    if command -v apt &> /dev/null; then
        sudo apt update -y
        sudo apt install -y build-essential git python3-dev pkg-config libusb-1.0-0-dev libudev-dev
    else
        echo -e "${RED}Error: APT package manager not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: sudo is required but not available.${NC}"
    exit 1
fi

# Create installation directory
INSTALL_DIR="$HOME/LaserWeb"
echo -e "${YELLOW}Installing LaserWeb4 to: $INSTALL_DIR${NC}"

# Clone LaserWeb4 repository (as per official docs)
git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Initialize and update submodules (as per official docs)
git submodule init
git submodule update --remote

# Install lw.comm-server as per official documentation
echo -e "${YELLOW}Installing lw.comm-server (for communication with GRBL)...${NC}"
npm install lw.comm-server

# Install remaining dependencies
echo -e "${YELLOW}Installing remaining dependencies...${NC}"
npm install

# Create default configuration
echo -e "${YELLOW}Creating default configuration...${NC}"

cat > config.json << EOF
{
  "server": {
    "port": 8000,
    "host": "0.0.0.0",
    "ssl": false,
    "socketIoPath": "/socket.io"
  },
  "app": {
    "title": "LaserWeb4 - CNC Control"
  },
  "defaults": {
    "language": "en",
    "theme": "dark"
  },
  "plugins": [
    "lw.comm",
    "lw.gcode", 
    "lw.grbl",
    "lw.cnc",
    "lw.dsp",
    "lw.laser",
    "lw.camera",
    "lw.spindle",
    "lw.pins",
    "lw.macros",
    "lw.probe"
  ]
}
EOF

# Create a systemd service for lw.comm-server to start on boot
echo -e "${YELLOW}Creating lw.comm-server systemd service for automatic startup...${NC}"

SERVICE_FILE="/etc/systemd/system/lw-comm-server.service"
SERVICE_CONTENT="[Unit]
Description=LaserWeb4 Communication Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/LaserWeb
ExecStart=/usr/bin/npm run start-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable lw-comm-server.service
echo -e "${GREEN}Created and enabled lw-comm-server service${NC}"

# Create a systemd service for LaserWeb4 frontend
echo -e "${YELLOW}Creating LaserWeb4 frontend systemd service for automatic startup...${NC}"

FRONTEND_SERVICE_FILE="/etc/systemd/system/laserweb-frontend.service"
FRONTEND_SERVICE_CONTENT="[Unit]
Description=LaserWeb4 Frontend
After=network.target lw-comm-server.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/LaserWeb
ExecStart=/usr/bin/npm run start-app -- --port 8000 --host 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

echo "$FRONTEND_SERVICE_CONTENT" | sudo tee "$FRONTEND_SERVICE_FILE" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable laserweb-frontend.service
echo -e "${GREEN}Created and enabled LaserWeb4 frontend service${NC}"

# Create main service that coordinates both
echo -e "${YELLOW}Creating main LaserWeb4 service...${NC}"

MAIN_SERVICE_FILE="/etc/systemd/system/laserweb.service"
MAIN_SERVICE_CONTENT="[Unit]
Description=LaserWeb4 CNC Control System
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'cd $HOME/LaserWeb && npm-run-all -p -r start-app start-server'

[Install]
WantedBy=multi-user.target"

echo "$MAIN_SERVICE_CONTENT" | sudo tee "$MAIN_SERVICE_FILE" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable laserweb.service
echo -e "${GREEN}Created and enabled main LaserWeb4 service${NC}"

# Create a start script that follows the official documentation
START_SCRIPT="$HOME/start_laserweb.sh"
cat > "$START_SCRIPT" << 'EOF'
#!/bin/bash
# LaserWeb4 Start Script
# Starts both the frontend and communication server

echo "Starting LaserWeb4..."
echo "Access the interface at: http://localhost:8000"
echo "Access from other devices: http://[YOUR_COMPUTER_IP]:8000"

cd $HOME/LaserWeb
echo "Current directory: $(pwd)"

echo "LaserWeb4 server is starting..."
npm start

echo "LaserWeb4 server stopped."
EOF

chmod +x "$START_SCRIPT"
echo -e "${GREEN}Created start script at: $START_SCRIPT${NC}"

# Add user to dialout group for serial access
if command -v sudo &> /dev/null; then
    sudo usermod -a -G dialout $USER
    echo -e "${GREEN}Added user to dialout group for serial port access${NC}"
fi

echo -e "${GREEN}=== LaserWeb4 Installation completed ===${NC}"
echo -e "${GREEN}To use LaserWeb4:${NC}"
echo -e "${GREEN}1. Run the start script: $START_SCRIPT${NC}"
echo -e "${GREEN}2. Access the interface at: http://localhost:8000${NC}"
echo -e "${GREEN}3. To access from another device: http://[YOUR_COMPUTER_IP]:8000${NC}"
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "${YELLOW}  - LaserWeb4 requires Node.js v18.x for proper serial communication${NC}"
echo -e "${YELLOW}  - The communication server (lw.comm-server) handles GRBL communication${NC}"
echo -e "${YELLOW}  - Both services will start automatically on boot${NC}"
echo -e "${YELLOW}  - You need to logout and login again for group changes to take effect${NC}"
echo -e "${YELLOW}  - LaserWeb4 interface runs on port 8000 by default${NC}"