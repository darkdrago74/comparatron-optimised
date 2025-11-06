#!/bin/bash

# Comparatron Flask GUI Startup Script
# Use this script to start the Comparatron Flask GUI manually

# Set the path to your Comparatron directory (parent of rpi3_bookworm)
COMPARATRON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting Comparatron Flask GUI..."
echo "Comparatron directory: $COMPARATRON_DIR"

# Activate virtual environment if it exists
if [ -f "$HOME/comparatron_env/bin/activate" ]; then
    source "$HOME/comparatron_env/bin/activate"
    echo "Virtual environment activated"
else
    echo "Warning: Virtual environment not found. Using system Python."
fi

# Navigate to the Comparatron directory
cd "$COMPARATRON_DIR"

# Function to clean up when script exits
cleanup() {
    echo "Stopping Comparatron Flask GUI..."
    exit 0
}

# Set up signal trap to ensure cleanup
trap cleanup SIGINT SIGTERM

# Start the Flask application in background and get its PID
echo "Starting Flask server on http://localhost:5001..."
python3 main.py &
FLASK_PID=$!

# Wait for the Flask server to start
sleep 3

# Try to open the browser automatically (only if running on a desktop system)
if [ -x "$(command -v xdg-open)" ]; then
    # Try to detect if we're on a desktop system by checking for display
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        echo "Detected desktop environment, opening browser..."
        xdg-open "http://localhost:5001" &
    else
        echo "No desktop environment detected (headless system)."
        echo "Access the interface at: http://$(hostname -I | awk '{print $1}'):5001"
    fi
elif [ -x "$(command -v open)" ] && [[ "$OSTYPE" == "darwin"* ]]; then
    # For macOS
    open "http://localhost:5001" &
else
    echo "Opening browser not supported on this system."
    echo "Access the interface at: http://localhost:5001"
    echo "On network: http://$(hostname -I | awk '{print $1}'):5001"
fi

# Wait for the Flask process and handle interruption
wait $FLASK_PID

echo "Comparatron Flask GUI stopped"