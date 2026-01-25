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

# 4. Create ALL necessary directories
log_msg "Creating FreeRADIUS directories..."
mkdir -p /etc/freeradius/3.0/mods-available
mkdir -p /etc/freeradius/3.0/mods-enabled
mkdir -p /etc/freeradius/3.0/sites-available
mkdir -p /etc/freeradius/3.0/sites-enabled
mkdir -p /var/lib/freeradius
mkdir -p /var/log/freeradius
mkdir -p /usr/var/run/radiusd

# 5. Create COMPLETELY MINIMAL radiusd.conf (no virtual servers)
log_msg "Creating radiusd.conf (ultra-minimal)..."
cat > /etc/freeradius/3.0/radiusd.conf << 'RADIUSD_EOF'
# FreeRADIUS - Ultra-Minimal Configuration
# Just listen on RADIUS ports, no processing

prefix = /usr
exec_prefix = ${prefix}
installdir = ${exec_prefix}
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/3.0
localesdir = /usr/share/freeradius

thread pool {
    num_networks = 1
    num_workers = 4
    max_queue_size = 65536
    max_requests_per_worker = 0
}

listener {
    type = auth
    ipaddr = *
    port = 1812
    transport = udp
}

listener {
    type = acct
    ipaddr = *
    port = 1813
    transport = udp
}

listener {
    type = auth
    ipv6addr = ::
    port = 1812
    transport = udp
}

listener {
    type = acct
    ipv6addr = ::
    port = 1813
    transport = udp
}

modules {
}
RADIUSD_EOF

log_msg "radiusd.conf created (ultra-minimal)"

# 6. Create minimal clients.conf
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
chown -R freerad:freerad /etc/freeradius /var/lib/freeradius /var/log/freeradius /usr/var/run/radiusd 2>/dev/null || true
chmod -R 750 /etc/freeradius /var/lib/freeradius /var/log/freeradius /usr/var/run/radiusd 2>/dev/null || true
log_msg "Permissions fixed"

# 8. Test configuration
log_msg "Testing configuration..."
if freeradius -Cx -lstdout -d /etc/freeradius/3.0 > /tmp/radius_config_test.log 2>&1; then
    log_msg "Configuration test PASSED"
else
    log_msg "Configuration test FAILED - showing errors:"
    cat /tmp/radius_config_test.log | head -30 | tee -a "$LOG_FILE"
fi

# 9. Enable and start service
log_msg "Starting FreeRADIUS service..."
systemctl daemon-reload
systemctl enable freeradius
if systemctl start freeradius 2>&1; then
    log_msg "Service started"
else
    log_msg "Warning: service startup issue"
fi
sleep 3

# 10. Check if running
if systemctl is-active --quiet freeradius; then
    log_msg "SUCCESS: FreeRADIUS is running on port 1812/1813"
else
    log_msg "WARNING: FreeRADIUS not running"
    journalctl -u freeradius -n 20 --no-pager 2>&1 | tee -a "$LOG_FILE"
fi

log_msg "FreeRADIUS installation complete"
echo ""
