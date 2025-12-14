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
