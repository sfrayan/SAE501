#!/bin/bash
# Fix FreeRADIUS clients.conf ${env} references

echo "[*] Fixing FreeRADIUS clients.conf..."

# Backup original
sudo cp /etc/freeradius/3.0/clients.conf /etc/freeradius/3.0/clients.conf.bak

# Remove all lines with ${env} references
sudo sed -i '/\${env}/d' /etc/freeradius/3.0/clients.conf

# Test configuration
echo "[*] Testing FreeRADIUS configuration..."
sudo /usr/sbin/freeradius -C 2>&1 | head -20

if [ $? -eq 0 ]; then
    echo "[+] Configuration is valid!"
    echo "[*] Restarting FreeRADIUS..."
    sudo systemctl restart freeradius
    sleep 2
    
    if sudo systemctl is-active freeradius > /dev/null 2>&1; then
        echo "[+] FreeRADIUS is now running!"
        sudo systemctl status freeradius
    else
        echo "[-] FreeRADIUS failed to start"
        sudo systemctl status freeradius
    fi
else
    echo "[-] Configuration still has errors"
    sudo /usr/sbin/freeradius -C 2>&1 | head -50
fi
