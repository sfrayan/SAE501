#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS (Simplified & Robust)
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
   echo "Must run as root" >&2
   exit 1
fi

log_msg "Starting FreeRADIUS installation..."

# 1. Install packages
log_msg "Installing FreeRADIUS packages..."
apt-get update > /dev/null 2>&1 || true
apt-get install -y freeradius freeradius-mysql freeradius-utils > /dev/null 2>&1
log_msg "FreeRADIUS installed"

# 2. Stop service
log_msg "Stopping FreeRADIUS service..."
systemctl stop freeradius 2>/dev/null || true
sleep 2

# 3. Create/fix users and groups
log_msg "Creating freerad user/group..."
useradd -r -s /bin/false freerad 2>/dev/null || true

# 4. Create directories
log_msg "Creating directories..."
mkdir -p /var/lib/freeradius
mkdir -p /var/log/freeradius

# 5. Enable modules (create symlinks)
log_msg "Enabling FreeRADIUS modules..."
for mod in sql pap files; do
    ln -sf /etc/freeradius/3.0/mods-available/$mod /etc/freeradius/3.0/mods-enabled/$mod 2>/dev/null || true
done

# 6. Fix clients.conf - SIMPLE AND CLEAN
log_msg "Configuring clients.conf..."
cat > /etc/freeradius/3.0/clients.conf << 'CLIENTS_EOF'
# FreeRADIUS Clients Configuration

client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
CLIENTS_EOF

log_msg "clients.conf configured"

# 7. Fix permissions
log_msg "Fixing permissions..."
chown -R freerad:freerad /etc/freeradius /var/lib/freeradius /var/log/freeradius
chmod -R 750 /etc/freeradius /var/lib/freeradius /var/log/freeradius
log_msg "Permissions fixed"

# 8. Test configuration
log_msg "Testing configuration..."
if freeradius -Cx -lstdout -d /etc/freeradius/3.0 > /tmp/radius_config_test.log 2>&1; then
    log_msg "Configuration test PASSED"
else
    log_msg "Configuration test FAILED - showing errors:"
    cat /tmp/radius_config_test.log | tee -a "$LOG_FILE"
    # Continue anyway - don't fail
fi

# 9. Enable and start service
log_msg "Starting FreeRADIUS service..."
systemctl daemon-reload
systemctl enable freeradius
systemctl start freeradius 2>/dev/null || log_msg "Warning: initial start may have issues"
sleep 3

# 10. Check if running
if systemctl is-active --quiet freeradius; then
    log_msg "SUCCESS: FreeRADIUS is running"
else
    log_msg "WARNING: FreeRADIUS not running - check logs"
    journalctl -u freeradius -n 10 --no-pager || true
fi

log_msg "FreeRADIUS installation complete"
echo ""
