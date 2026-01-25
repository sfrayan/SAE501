#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS (Automatisée & Stable - FIXED systemd)
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
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y freeradius freeradius-mysql freeradius-utils >/dev/null 2>&1
log_msg "FreeRADIUS installed"

# 2. Stop service if running
log_msg "Stopping FreeRADIUS service..."
systemctl stop freeradius 2>/dev/null || true
sleep 1

# 3. Ensure freerad user/group exists
log_msg "Ensuring freerad user/group exists..."
if ! id freerad >/dev/null 2>&1; then
    useradd -r -s /bin/false freerad || true
fi

# 4. Create directories
log_msg "Creating directories..."
mkdir -p /etc/freeradius/3.0
mkdir -p /var/log/freeradius
mkdir -p /var/run/freeradius

# 5. Deploy radiusd.conf from repo
log_msg "Deploying radiusd.conf from repo..."
if [[ -f /opt/SAE501/radius/radiusd.conf ]]; then
    cp /opt/SAE501/radius/radiusd.conf /etc/freeradius/3.0/radiusd.conf
else
    log_msg "ERROR: /opt/SAE501/radius/radiusd.conf not found"
fi

# 6. Deploy clients.conf from repo
log_msg "Deploying clients.conf from repo..."
if [[ -f /opt/SAE501/radius/clients.conf ]]; then
    cp /opt/SAE501/radius/clients.conf /etc/freeradius/3.0/clients.conf
else
    log_msg "WARNING: /opt/SAE501/radius/clients.conf not found, creating minimal localhost client"
    cat > /etc/freeradius/3.0/clients.conf << 'CLIENTS_EOF'
client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::
    secret = testing123
    shortname = localhost
    nastype = other
}
CLIENTS_EOF
fi

# 7. Permissions
log_msg "Fixing permissions..."
chown -R freerad:freerad /etc/freeradius /var/log/freeradius /var/run/freeradius
chmod -R 755 /etc/freeradius /var/log/freeradius /var/run/freeradius

# 8. Test configuration (exact same way as systemd ExecStartPre)
log_msg "Testing configuration with 'freeradius -Cx -lstdout'..."
if /usr/sbin/freeradius -Cx -lstdout -d /etc/freeradius/3.0 >/tmp/radius_config_test.log 2>&1; then
    log_msg "✓ Configuration test PASSED"
else
    log_msg "✗ Configuration test FAILED, showing first lines:"
    head -40 /tmp/radius_config_test.log | tee -a "$LOG_FILE"
fi

# 9. Deploy systemd override (FIX for Debian 11 daemon mode issue)
log_msg "Deploying systemd override for FreeRADIUS..."
mkdir -p /etc/systemd/system/freeradius.service.d
if [[ -f /opt/SAE501/systemd/freeradius.service.d/override.conf ]]; then
    cp /opt/SAE501/systemd/freeradius.service.d/override.conf /etc/systemd/system/freeradius.service.d/override.conf
    log_msg "✓ Systemd override deployed from repo"
else
    log_msg "WARNING: systemd override not in repo, creating inline..."
    cat > /etc/systemd/system/freeradius.service.d/override.conf << 'OVERRIDE_EOF'
[Service]
ExecStart=
ExecStart=/usr/sbin/freeradius -f -lstdout
OVERRIDE_EOF
fi

# 10. Enable and start service via systemd
log_msg "Enabling and starting FreeRADIUS via systemd..."
systemctl daemon-reload
systemctl enable freeradius >/dev/null 2>&1 || true
systemctl restart freeradius || true
sleep 2

# 11. Check status
if systemctl is-active --quiet freeradius; then
    log_msg "✓ SUCCESS: FreeRADIUS is running via systemd (ports 1812/1813)"
else
    log_msg "✗ FAILED: FreeRADIUS not running via systemd"
    journalctl -u freeradius -n 20 --no-pager | tee -a "$LOG_FILE" || true
fi

log_msg "FreeRADIUS installation complete"
