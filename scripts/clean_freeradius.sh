#!/bin/bash
# ============================================================================
# SAE501 - Complete FreeRADIUS Cleanup & Reinstall
# ============================================================================

set -euo pipefail

echo "[!] This will completely remove and reinstall FreeRADIUS"
echo "[!] Type 'YES' to continue:"
read -p "> " confirm

if [[ "$confirm" != "YES" ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "[*] Step 1: Stopping services..."
sudo systemctl stop freeradius 2>/dev/null || true
sudo systemctl stop freeradius-server 2>/dev/null || true
sleep 2

echo "[*] Step 2: Removing packages (keeping configs)..."
sudo apt-get remove -y freeradius freeradius-mysql freeradius-utils 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

echo "[*] Step 3: Cleaning up dpkg..."
sudo dpkg --configure -a 2>/dev/null || true

echo "[*] Step 4: Installing fresh FreeRADIUS..."
sudo apt-get update
sudo apt-get install -y freeradius freeradius-mysql freeradius-utils

echo "[*] Step 5: Waiting for installation to complete..."
sleep 3

echo "[*] Step 6: Checking installation..."
if [[ -d /etc/freeradius/3.0 ]]; then
    echo "[✓] FreeRADIUS config directory exists"
else
    echo "[✗] FreeRADIUS config directory MISSING!"
    exit 1
fi

if [[ -f /etc/freeradius/3.0/radiusd.conf ]]; then
    echo "[✓] radiusd.conf exists"
else
    echo "[✗] radiusd.conf MISSING!"
    exit 1
fi

echo ""
echo "[✓] Cleanup and fresh install complete!"
echo "[*] Now run: sudo bash scripts/install_all.sh"
echo ""
