#!/bin/bash
# Fix FreeRADIUS clients.conf - remove env variable references and duplicates

echo "[*] Fixing FreeRADIUS clients.conf..."

# Backup original
sudo cp /etc/freeradius/3.0/clients.conf /etc/freeradius/3.0/clients.conf.bak.$(date +%s)

# Get the original file but only up to line 269 (before the problematic section)
sudo sed -i '270,$d' /etc/freeradius/3.0/clients.conf

# Add clean clients configuration
sudo tee -a /etc/freeradius/3.0/clients.conf > /dev/null << 'EOF'
# SAE501 - RouÚteur TL-MR100 (Salle de sport pilote)
client 192.168.1.1 {
    secret = "SAE501@TLRouter2026!"
    shortname = "TL-MR100-Pilot"
    nas_type = "other"
    response_window = 20
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
}

# Localhost for testing
client 127.0.0.1 {
    secret = "testing123"
    shortname = "localhost"
}

client ::1 {
    secret = "testing123"
    shortname = "localhost"
}
EOF

echo "[*] Testing FreeRADIUS configuration..."
sudo /usr/sbin/freeradius -C 2>&1 | grep -i error | head -10

if sudo /usr/sbin/freeradius -C > /dev/null 2>&1; then
    echo "[+] Configuration is valid!"
    echo "[*] Restarting FreeRADIUS..."
    sudo systemctl stop freeradius 2>/dev/null || true
    sleep 1
    sudo systemctl start freeradius
    sleep 2
    
    if sudo systemctl is-active freeradius > /dev/null 2>&1; then
        echo "[+] FreeRADIUS is now running!"
        sudo systemctl status freeradius
    else
        echo "[-] FreeRADIUS failed to start"
        echo "[*] Logs:"
        sudo journalctl -u freeradius -n 20 --no-pager
    fi
else
    echo "[-] Configuration still has errors"
    sudo /usr/sbin/freeradius -C 2>&1 | head -50
fi
