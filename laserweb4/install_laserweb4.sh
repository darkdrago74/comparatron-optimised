#!/bin/bash

# LaserWeb4 Installation Script
# Automatically installs Node.js v18.x and LaserWeb4 with proper setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Installation ===${NC}"

# Install and setup Node.js v18
echo -e "${YELLOW}Installing Node.js v18 using Nodesource setup script...${NC}"

# Download and run the NodeSource setup script for Node.js v18
if command -v curl &> /dev/null; then
    if command -v sudo &> /dev/null; then
        # Using NodeSource setup script to install Node.js 18.x
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo -e "${GREEN}✓ Node.js v18.x installed${NC}"
    else
        echo -e "${RED}Error: sudo not available. Cannot install Node.js automatically.${NC}"
        echo -e "${RED}Please install Node.js v18.x manually first.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: curl not available. Cannot download NodeSource setup script.${NC}"
    echo -e "${RED}Please install Node.js v18.x manually first.${NC}"
    exit 1
fi

# Verify Node.js installation
NODE_VERSION=$(node --version 2>/dev/null)
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}Error: Node.js installation failed.${NC}"
    exit 1
fi

NPM_VERSION=$(npm --version 2>/dev/null)
if [ -z "$NPM_VERSION" ]; then
    echo -e "${RED}Error: npm installation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Node.js $NODE_VERSION and npm $NPM_VERSION are installed${NC}"

# Create timestamped log file
LOG_FILE="/tmp/laserweb4_install_$(date +%Y%m%d_%H%M%S).log"
echo "LaserWeb4 installation log started at $(date)" >> "$LOG_FILE"
echo "Node.js version: $NODE_VERSION" >> "$LOG_FILE"
echo "npm version: $NPM_VERSION" >> "$LOG_FILE"

# Clone LaserWeb4 repository
LASERWEB_DIR="$HOME/LaserWeb"
if [ -d "$LASERWEB_DIR" ]; then
    echo -e "${YELLOW}LaserWeb directory already exists at: $LASERWEB_DIR${NC}"
    read -p "Update existing installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        echo -e "${YELLOW}Updating existing LaserWeb installation...${NC}"
        cd "$LASERWEB_DIR"
        git pull
    else
        echo -e "${YELLOW}Skipping update, using existing installation.${NC}"
        echo "Skipping update, using existing installation" >> "$LOG_FILE"
    fi
else
    echo -e "${YELLOW}Cloning LaserWeb repository...${NC}"
    echo "Cloning LaserWeb repository..." >> "$LOG_FILE"
    git clone https://github.com/LaserWeb/LaserWeb.git "$LASERWEB_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to clone LaserWeb repository.${NC}"
        echo "Error: Failed to clone LaserWeb repository" >> "$LOG_FILE"
        exit 1
    fi
fi

cd "$LASERWEB_DIR"

# Install dependencies from package.json
echo -e "${YELLOW}Installing LaserWeb dependencies (this may take several minutes)...${NC}"
echo "Installing LaserWeb dependencies..." >> "$LOG_FILE"

if [ -f "package.json" ]; then
    npm install >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to install LaserWeb dependencies. Check log: $LOG_FILE${NC}"
        echo "Error: Failed to install LaserWeb dependencies" >> "$LOG_FILE"
        exit 1
    fi
    echo -e "${GREEN}✓ LaserWeb dependencies installed successfully${NC}"
else
    echo -e "${RED}Error: package.json not found in $LASERWEB_DIR${NC}"
    echo "Error: package.json not found" >> "$LOG_FILE"
    exit 1
fi

# Install lw-comm-server globally if not already installed
if ! npm list -g lw.comm-server &> /dev/null; then
    echo -e "${YELLOW}Installing LaserWeb communication server (lw.comm-server)...${NC}"
    echo "Installing LaserWeb communication server (lw.comm-server)..." >> "$LOG_FILE"
    sudo npm install -g lw.comm-server >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to install LaserWeb communication server.${NC}"
        echo "Error: Failed to install LaserWeb communication server" >> "$LOG_FILE"
    else
        echo -e "${GREEN}✓ LaserWeb communication server installed${NC}"
    fi
else
    echo -e "${GREEN}✓ LaserWeb communication server already installed${NC}"
fi

# Create default configuration if it doesn't exist
CONFIG_FILE="$LASERWEB_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Creating default configuration...${NC}"
    echo "Creating default configuration..." >> "$LOG_FILE"
    cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "1.0",
  "production": false,
  "server": {
    "port": 8000,
    "allowOrigin": "*",
    "socketioOrigins": "*:*"
  },
  "boards": {
    "grbl": {
      "path": "/dev/ttyUSB0",
      "baudrate": 115200,
      "handshake": false,
      "parser": "grbl"
    }
  },
  "plugins": [
    "lw.comm-server"
  ],
  "commServer": {
    "port": 8080,
    "boards": {
      "grbl": {
        "path": "/dev/ttyUSB0",
        "baudrate": 115200,
        "handshake": false,
        "parser": "grbl"
      }
    }
  }
}
EOF
    echo -e "${GREEN}✓ Default configuration created${NC}"
fi

# Create systemd service for auto-start (optional)
echo -e "${YELLOW}Setting up LaserWeb systemd service for auto-start (optional)...${NC}"

SERVICE_FILE="/etc/systemd/system/laserweb.service"
SERVICE_CONTENT="[Unit]
Description=LaserWeb
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$LASERWEB_DIR
Environment=PATH=/usr/bin
Environment=NODE_PATH=/usr/lib/node_modules
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
sudo systemctl daemon-reload > /dev/null
echo -e "${GREEN}✓ LaserWeb systemd service created${NC}"

read -p "Enable LaserWeb to start automatically on boot? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl enable laserweb.service
    # Also start the service now
    sudo systemctl start laserweb.service
    echo -e "${GREEN}✓ LaserWeb service enabled and started on boot${NC}"
else
    echo -e "${YELLOW}Auto-start service created but not enabled. Enable with: sudo systemctl enable laserweb${NC}"
fi

# Add user to dialout group for serial access
if command -v sudo &> /dev/null; then
    sudo usermod -a -G dialout $USER
    echo -e "${GREEN}✓ User added to dialout group for serial port access${NC}"
fi

# Create a start script
START_SCRIPT="$HOME/start_laserweb.sh"
cat > "$START_SCRIPT" << 'EOF'
#!/bin/bash
# LaserWeb Start Script
# Starts both the frontend and communication server

echo "Starting LaserWeb..."
echo "Access the interface at: http://localhost:8000"
echo "Access from other devices: http://[YOUR_COMPUTER_IP]:8000"

cd $HOME/LaserWeb

# Start the communication server in background
echo "Starting communication server..."
lw.comm-server --port 8080 &

# Start the main LaserWeb interface
echo "Starting LaserWeb interface..."
npm start
EOF

chmod +x "$START_SCRIPT"
echo -e "${GREEN}✓ Created start script: $START_SCRIPT${NC}"

echo -e "${GREEN}=== LaserWeb4 Installation completed ===${NC}"
echo -e "${GREEN}Installation log saved to: $LOG_FILE${NC}"
echo -e "${GREEN}To start LaserWeb4:${NC}"
echo -e "${GREEN}  $START_SCRIPT${NC}"
echo -e "${GREEN}Access via web browser at: http://localhost:8000${NC}"
echo -e "${YELLOW}Note: You may need to log out and log back in for group changes to take effect${NC}"